# Kindle Casa — Wake daemon (experimental)

This directory is intentionally separate from the working dashboard plugin.

## Goal

Wake the Kindle around 06:00, fetch the private household JSON over HTTPS, update the local dashboard cache, and return the device to its normal sleep state. The existing manual refresh remains available.

## Safety boundary

The first milestone is **diagnostics only**. Do not schedule or write to an RTC alarm until the exact device/firmware behavior has been inspected.

- Do not change the InkDeck plugin.
- Do not change the current dashboard view, GitHub sync, or editor.
- Do not enable Dropbear's "Keep reachable while Kindle sleeps" as a workaround.
- Never put the GitHub token in this public repository.
- Never expose SSH to the public internet.
- Preserve the current local panel cache if network access or GitHub sync fails.

## Milestones

1. **Probe:** collect kernel, RTC, wakealarm, and power-management capabilities without modifying them.
2. **Wake test:** only after reviewing the probe output, implement a short, user-controlled RTC test with a harmless log marker. It must save and restore any pre-existing alarm and include a cancellation path.
3. **Network test:** determine how this firmware brings Wi-Fi up after a timed wake; test without touching dashboard data.
4. **Sync worker:** reuse the existing GitHub HTTPS reader and local cache, with bounded retries and clear logs.
5. **Sleep handoff:** return to the Kindle's normal power-management path; do not force power-off or suspend commands until verified on this model.

## Device under test

- Kindle G092 AP05
- Firmware 5.19.2.0.1
- KOReader + Kindle Casa plugin
- Expected local data directory: `/mnt/us/kindle-casa`

## First test

Copy `probe.sh` to the Kindle and run it from SSH or a KOReader terminal:

```sh
sh /mnt/us/kindle-casa/daemon/probe.sh
```

If copied to another location, adjust the path. The script prints diagnostics to the terminal and writes a report to:

```
/mnt/us/kindle-casa/daemon-probe.txt
```

Send the report back for review. It does not set an RTC alarm, change Wi-Fi, or change power state.

## Design note

A timer inside a running KOReader process is not a reliable deep-sleep wake mechanism. The wake mechanism, network bring-up, sync worker, and sleep handoff must be validated independently before they are connected.
