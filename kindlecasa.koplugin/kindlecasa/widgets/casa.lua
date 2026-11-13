-- Casa: household dashboard designed for a portrait e-ink screen.
local Base = require("kindlecasa/widgets/base")
local UI = require("kindlecasa/ui")
local U = require("kindlecasa/util")
local Weather = require("kindlecasa/widgets/weather")

local Casa = Base.define{
    type = "casa", name = "Casa", icon = UI.ICON.home, interval = 1800,
    defaults = {
        city = "Joinville", lat = -26.3044, lon = -48.8456,
        sand = { label = "Areia", date = "2026-11-15", total_days = 45 },
        food = { label = "Ração", date = "2026-12-07", total_days = 45 },
        tasks = {}, bills = {},
        cycles = { K = { date = "", note = "" }, E = { date = "", note = "" } },
    },
}

local function days_until(iso)
    local target = U.parseIsoLocal(iso or "")
    if not target then return nil end
    return math.floor((U.dayStart(target) - U.dayStart(U.now())) / 86400 + 0.5), target
end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function day_word(n) return math.abs(n) == 1 and "dia" or "dias" end
local function event_stamp(value, all_day)
    value = tostring(value or "")
    local y, m, d, hh, mm = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)")
    if not y then y, m, d = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)") end
    if not y then return value end
    local date = d .. "/" .. m
    if all_day or not hh then return date end
    return date .. " " .. hh .. ":" .. mm
end
local function fmt_date(iso)
    local y,m,d = tostring(iso or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return "—" end
    return d .. "/" .. m .. "/" .. y
end
local function text(c, s, x, y, size, opts)
    opts = opts or {}; c:text(tostring(s or ""), x, y, { size = size, bold = opts.bold, color = opts.color or "black", maxw = opts.maxw, w = opts.w, align = opts.align })
end
local function section(c, x, y, w, title, icon)
    if icon then c:icon(icon, x, y + 1, 28, { color = "black" }) end
    text(c, title, x + (icon and 36 or 0), y, 32, { bold = true })
    c:hline(x, y + 37, w, 2, "black")
end
function Casa:init()
    self.weather = Weather.new({ city = self.s.city, lat = self.s.lat, lon = self.s.lon }, self.ctx)
    self.last_weather_update = 0
    self.last_panel_sync = 0
    self.panel_cache_path = self.ctx.cache_dir .. "/painel.json"
    local cached = U.loadJson(self.panel_cache_path)
    if type(cached) == "table" then
        self:applyPanel(cached)
    end
end

function Casa:applyPanel(panel)
    local GitHub = require("kindlecasa/github")
    local mapped = GitHub.toCasaSettings(panel, self.s)
    self.s.sand, self.s.food = mapped.sand, mapped.food
    self.s.tasks, self.s.bills = mapped.tasks, mapped.bills
    self.s.cycles = mapped.cycles
    self.s.house = mapped.house
    self.s.calendar = mapped.calendar
    self.s.layout = mapped.layout or {}
    self.panel_updated_at = mapped.updatedAt
end

function Casa:syncPanel(now)
    if not self.ctx.fetchCasaData then return end
    local interval = tonumber(self.ctx.config.github and self.ctx.config.github.refresh_minutes) or 15
    interval = math.max(5, interval) * 60
    if now - (self.last_panel_sync or 0) < interval then return end
    self.last_panel_sync = now
    local ok, panel, err = pcall(self.ctx.fetchCasaData)
    if ok and type(panel) == "table" then
        self:applyPanel(panel)
        pcall(U.saveJson, self.panel_cache_path, panel)
        self.panel_sync_error = nil
    else
        self.panel_sync_error = ok and tostring(err or "Falha ao buscar painel") or tostring(panel)
    end
end

function Casa:update(now)
    self:syncPanel(now)
    if not self.weather.data or now - (self.last_weather_update or 0) >= 1800 then
        local ok, err = pcall(self.weather.update, self.weather, now)
        self.last_weather_update = now
        if not ok then self.weather.error = tostring(err) end
        self.weather.last_update = now
    end
    return true
end
function Casa:drawTile(c, p, focused)
    local x, y, w, h = p.x + 18, p.y + 10, p.w - 36, p.h - 20
    local gap = 14
    local half = math.floor((w - gap) / 2)
    local layout = self.s.layout or {}
    local blocks = {
        { id = "weather", size = layout.weather or "wide" },
        { id = "cats", size = layout.cats or "wide" },
        { id = "tasks", size = layout.tasks or "compact" },
        { id = "bills", size = layout.bills or "compact" },
        { id = "cycles", size = layout.cycles or "compact" },
        { id = "agenda", size = layout.agenda or "wide" },
    }
    if self.s.house and tostring(self.s.house.note or "") ~= "" then
        blocks[#blocks + 1] = { id = "note", size = layout.note or "compact" }
    end

    -- Two-column packing, matching the editor's compact / wide / tall controls.
    local occupied, placements, row_count = {}, {}, 0
    local function cell_free(col, row, cw, rh)
        for rr = row, row + rh - 1 do
            occupied[rr] = occupied[rr] or {}
            for cc = col, col + cw - 1 do
                if cc > 2 or occupied[rr][cc] then return false end
            end
        end
        return true
    end
    for _, block in ipairs(blocks) do
        local size = block.size
        if size ~= "compact" and size ~= "wide" and size ~= "tall" then size = "wide" end
        local cw, rh = size == "wide" and 2 or 1, size == "tall" and 2 or 1
        local placed = false
        for row = 1, 30 do
            for col = 1, 2 do
                if cell_free(col, row, cw, rh) then
                    for rr = row, row + rh - 1 do
                        occupied[rr] = occupied[rr] or {}
                        for cc = col, col + cw - 1 do occupied[rr][cc] = true end
                    end
                    placements[#placements + 1] = { id = block.id, col = col, row = row, cw = cw, rh = rh }
                    row_count = math.max(row_count, row + rh - 1)
                    placed = true
                    break
                end
            end
            if placed then break end
        end
    end
    row_count = math.max(1, row_count)
    local row_h = math.floor((h - gap * (row_count - 1)) / row_count)

    local function rect(item)
        local xx = x + (item.col == 2 and (half + gap) or 0)
        local yy = y + (item.row - 1) * (row_h + gap)
        local ww = item.cw == 2 and w or half
        local hh = item.rh * row_h + (item.rh - 1) * gap
        return xx, yy, ww, hh
    end
    local function heading(xx, yy, ww, title, icon)
        if icon then c:icon(icon, xx, yy + 1, 25, { color = "black" }) end
        text(c, title, xx + (icon and 32 or 0), yy, 28, { bold = true })
        c:hline(xx, yy + 34, ww, 2, "black")
        return yy + 46
    end
    local function draw_consumable(xx, yy, ww, hh, item, fallback)
        item = item or fallback
        local d = days_until(item.date)
        text(c, item.label or "", xx, yy, 25, { bold = true, maxw = ww })
        local value = d and (d == 0 and "Hoje" or (d < 0 and ("há " .. math.abs(d) .. " " .. day_word(d)) or (d .. " " .. day_word(d)))) or fmt_date(item.date)
        text(c, value, xx, yy + 31, 33, { bold = true, maxw = ww })
        local state = d and (d > 0 and "até repor" or (d < 0 and "estimativa ultrapassada" or "repor hoje")) or "previsão"
        text(c, state, xx, yy + 66, 19, { color = "dark", maxw = ww })
        local total = tonumber(item.total_days) or 0
        local pct = total > 0 and clamp(math.floor((d or 0) / total * 100 + 0.5), 0, 100) or 0
        if hh >= 150 then
            UI.progress(c, xx, yy + 94, ww, 14, pct / 100, { border = 1 })
            text(c, pct .. "% restante", xx, yy + 114, 19, { bold = true })
        end
    end

    for _, item in ipairs(placements) do
        local xx, yy, ww, hh = rect(item)
        local body_y = heading(xx, yy, ww, ({
            weather = "Clima", cats = "Gatos", tasks = "Tarefas",
            bills = "Contas", cycles = "Ciclos", agenda = "Agenda", note = "Anotação",
        })[item.id], ({
            weather = 0xF1A1, cats = 0xF1B0, tasks = 0xF046,
            bills = 0xF155, cycles = 0xF043, agenda = 0xF073, note = nil,
        })[item.id])

        if item.id == "weather" then
            local cur = self.weather.data and self.weather.data.current or {}
            local temp = type(cur.temperature_2m) == "number" and (math.floor(cur.temperature_2m + 0.5) .. "°") or "—°"
            text(c, temp, xx, body_y + 2, math.min(82, math.floor(hh * 0.34)), { bold = true })
            text(c, self.s.city or "Joinville", xx + 3, body_y + math.min(72, math.floor(hh * 0.38)), 23, { bold = true })
            local desc = "Clima"
            if self.weather.data then
                local WeatherModule = require("kindlecasa/widgets/weather")
                desc = WeatherModule.code(cur.weather_code, cur.is_day ~= 0)
            end
            text(c, desc, xx + 3, body_y + math.min(101, math.floor(hh * 0.53)), 19, { color = "dark", maxw = ww * 0.58 })
            if item.cw == 2 then
                local cat_path = self.ctx.data_dir .. "/sleeping-cat.png"
                local cat_w, cat_h = math.floor(ww * 0.34), math.min(120, hh - 58)
                if cat_h > 45 then c:image(cat_path, xx + ww - cat_w, body_y + 2, cat_w, cat_h, { fill = false }) end
            end

        elseif item.id == "cats" then
            local sand = self.s.sand or { label = "Areia", date = "", total_days = 0 }
            local food = self.s.food or { label = "Ração", date = "", total_days = 0 }
            if item.cw == 2 then
                local col = math.floor((ww - 24) / 2)
                draw_consumable(xx, body_y, col, hh - 50, sand, { label = "Areia", date = "", total_days = 0 })
                c:vline(xx + col + 12, body_y, math.max(30, hh - 58), 1, "gray")
                draw_consumable(xx + col + 24, body_y, col, hh - 50, food, { label = "Ração", date = "", total_days = 0 })
            else
                local each = math.max(72, math.floor((hh - 54) / 2))
                draw_consumable(xx, body_y, ww, each, sand, { label = "Areia", date = "", total_days = 0 })
                draw_consumable(xx, body_y + each, ww, each, food, { label = "Ração", date = "", total_days = 0 })
            end

        elseif item.id == "tasks" or item.id == "bills" then
            local is_bill = item.id == "bills"
            local list = is_bill and (self.s.bills or {}) or (self.s.tasks or {})
            local row_hh = hh >= 300 and 37 or 32
            local shown, limit = 0, math.min(5, math.max(1, math.floor((hh - 54) / row_hh)))
            for _, it in ipairs(list) do
                if shown >= limit then break end
                local label = is_bill and (it.name or it.text or "") or (it.text or it.name or "")
                if label ~= "" then
                    local done = is_bill and (it.paid == true or it.done == true) or it.done == true
                    c:icon(done and UI.ICON.check or UI.ICON.box, xx, body_y + shown * row_hh + 2, 18, { color = "black" })
                    local value = is_bill and (it.value or "") or ""
                    local right = value ~= "" and tostring(value) or nil
                    text(c, label, xx + 25, body_y + shown * row_hh, 22, { color = done and "gray" or "black", maxw = ww - 34 - (right and 64 or 0) })
                    if right then text(c, right, xx + ww - 65, body_y + shown * row_hh, 19, { bold = true, maxw = 65, align = "right" }) end
                    if done then c:hline(xx + 25, body_y + shown * row_hh + 10, math.min(ww - 32, c:measure(label, { size = 22 })), 1, "gray") end
                    shown = shown + 1
                end
            end
            if shown == 0 then text(c, is_bill and "Sem contas anotadas" or "Sem tarefas anotadas", xx, body_y, 19, { color = "gray", maxw = ww }) end

        elseif item.id == "cycles" then
            local cycles = self.s.cycles or {}
            local function cycle_line(label, cycle, offset)
                cycle = cycle or {}
                local d = days_until(cycle.date)
                local value = cycle.note ~= "" and (cycle.note or "") or (d and (d == 0 and "Hoje" or (d > 0 and (d .. " " .. day_word(d)) or ("há " .. math.abs(d) .. " " .. day_word(d)))) or "Sem data")
                text(c, label, xx + 2, body_y + offset, 22, { bold = true })
                text(c, value, xx + 48, body_y + offset, 20, { maxw = ww - 55 })
                if item.cw == 2 then text(c, fmt_date(cycle.date), xx + ww - 100, body_y + offset, 18, { align = "right", maxw = 100 }) end
            end
            cycle_line("K.", cycles.K, 2)
            cycle_line("E.", cycles.E, 43)

        elseif item.id == "agenda" then
            local agenda = self.s.calendar or {}
            local events = type(agenda.events) == "table" and agenda.events or {}
            if #events == 0 then
                text(c, agenda.syncedAt and "Sem eventos nos próximos dias" or "Agenda ainda não sincronizada", xx + 3, body_y + 4, 20, { color = "gray", maxw = ww - 6 })
            else
                local count = math.min(#events, hh < 235 and 3 or 4)
                local event_h = hh < 235 and 35 or 40
                for i = 1, count do
                    local ev = events[i]
                    local stamp = event_stamp(ev.start, ev.allDay)
                    text(c, stamp, xx + 3, body_y + (i - 1) * event_h, 19, { bold = true, maxw = 116 })
                    text(c, ev.summary or "(Sem título)", xx + 126, body_y + (i - 1) * event_h, 21, { maxw = ww - 132 })
                end
            end

        elseif item.id == "note" then
            local note = tostring((self.s.house and self.s.house.note) or "")
            text(c, note, xx + 2, body_y + 2, 22, { maxw = ww - 4 })
        end
    end
end

function Casa:drawFull(c, W, H)
    self:drawTile(c, { x = 0, y = 0, w = W, h = H, cw = 1, ch = 1 }, false)
end
function Casa:hint() return "Painel da casa" end
return Casa
