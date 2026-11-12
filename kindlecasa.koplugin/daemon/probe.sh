#!/bin/sh
# Kindle Casa wake diagnostics — READ ONLY.
# Does not set RTC alarms, change Wi-Fi, or alter power state.

OUT_DIR="/mnt/us/kindle-casa"
OUT="$OUT_DIR/daemon-probe.txt"

mkdir -p "$OUT_DIR" 2>/dev/null

{
    echo "Kindle Casa — wake capability probe"
    echo "Generated: $(date 2>&1)"
    echo

    echo "== Device / kernel =="
    echo "uname: $(uname -a 2>&1)"
    echo "model: $(cat /proc/device-tree/model 2>/dev/null || echo unavailable)"
    echo "cmdline: $(cat /proc/cmdline 2>/dev/null)"
    echo

    echo "== RTC devices =="
    if [ -d /sys/class/rtc ]; then
        for rtc in /sys/class/rtc/rtc*; do
            [ -d "$rtc" ] || continue
            echo "-- $rtc"
            for attr in name date time since_epoch hctosys max_user_freq; do
                if [ -r "$rtc/$attr" ]; then
                    printf '%s: ' "$attr"
                    cat "$rtc/$attr" 2>&1
                fi
            done
            if [ -e "$rtc/wakealarm" ]; then
                echo "wakealarm: present"
                if [ -r "$rtc/wakealarm" ]; then
                    printf 'wakealarm current value: '
                    cat "$rtc/wakealarm" 2>&1
                else
                    echo "wakealarm current value: not readable"
                fi
                if [ -w "$rtc/wakealarm" ]; then
                    echo "wakealarm writable: yes (not tested)"
                else
                    echo "wakealarm writable: no"
                fi
            else
                echo "wakealarm: absent"
            fi
        done
    else
        echo "/sys/class/rtc unavailable"
    fi
    echo

    echo "== Kernel RTC report =="
    if [ -r /proc/driver/rtc ]; then
        cat /proc/driver/rtc
    else
        echo "/proc/driver/rtc unavailable"
    fi
    echo

    echo "== Power management interfaces =="
    for f in /sys/power/state /sys/power/wakeup_count /sys/power/mem_sleep; do
        if [ -r "$f" ]; then
            echo "-- $f"
            cat "$f" 2>&1
        else
            echo "-- $f: unavailable"
        fi
    done
    echo

    echo "== Relevant commands =="
    for cmd in rtcwake hwclock lipc-set-prop lipc-get-prop; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "$cmd: $(command -v "$cmd")"
        else
            echo "$cmd: unavailable"
        fi
    done
    echo

    echo "== Power daemon properties (read only) =="
    if command -v lipc-get-prop >/dev/null 2>&1; then
        lipc-get-prop com.lab126.powerd status 2>&1
        lipc-get-prop com.lab126.powerd battLevel 2>&1
    else
        echo "lipc-get-prop unavailable"
    fi
    echo

    echo "== Network snapshot (read only) =="
    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>&1
    elif command -v ip >/dev/null 2>&1; then
        ip addr 2>&1
    else
        echo "ifconfig/ip unavailable"
    fi
    echo

    echo "== End of report =="
    echo "No RTC alarm was written. No power or network state was changed."
} > "$OUT" 2>&1

cat "$OUT"
echo
echo "Report saved to: $OUT"
