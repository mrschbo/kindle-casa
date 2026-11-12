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
local function fmt_date(iso)
    local y,m,d = tostring(iso or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return "—" end
    return d .. "/" .. m .. "/" .. y
end
local function text(c, s, x, y, size, opts)
    opts = opts or {}; c:text(tostring(s or ""), x, y, { size = size, bold = opts.bold, color = opts.color or "black", maxw = opts.maxw, w = opts.w, align = opts.align })
end
local function section(c, x, y, w, title, icon)
    if icon then c:icon(icon, x, y + 1, 25, { color = "black" }) end
    text(c, title, x + (icon and 36 or 0), y, 24, { bold = true })
    c:hline(x, y + 37, w, 2, "black")
end
function Casa:init()
    self.weather = Weather.new({ city = self.s.city, lat = self.s.lat, lon = self.s.lon }, self.ctx)
    self.last_weather_update = 0
end
function Casa:update(now)
    if not self.weather.data or now - (self.last_weather_update or 0) >= 1800 then
        local ok, err = pcall(self.weather.update, self.weather, now)
        self.last_weather_update = now
        if not ok then self.weather.error = tostring(err) end
        self.weather.last_update = now
    end
    return true
end
function Casa:drawTile(c, p, focused)
    local x, y, w, h = p.x + 22, p.y + 12, p.w - 44, p.h - 24
    local gap = 24
    -- Weather + sleeping cat
    local top_h = math.floor(h * 0.205)
    local wx = x
    local cur = self.weather.data and self.weather.data.current or {}
    local temp = type(cur.temperature_2m) == "number" and (math.floor(cur.temperature_2m + 0.5) .. "°") or "—°"
    text(c, temp, wx, y + 10, math.min(100, math.floor(top_h * 0.48)), { bold = true })
    text(c, self.s.city or "Joinville", wx + 4, y + math.floor(top_h * 0.62), 22, { bold = true })
    if self.weather.data then
        local code = cur.weather_code
        local WeatherModule = require("kindlecasa/widgets/weather")
        local desc = WeatherModule.code(code, cur.is_day ~= 0)
        text(c, desc, wx + 4, y + math.floor(top_h * 0.78), 17, { color = "dark" })
    else
        text(c, "Clima", wx + 4, y + math.floor(top_h * 0.78), 17, { color = "dark" })
    end
    local cat_path = self.ctx.data_dir .. "/sleeping-cat.png"
    local cat_w, cat_h = math.floor(w * 0.43), math.floor(top_h * 0.96)
    c:image(cat_path, x + w - cat_w, y, cat_w, cat_h, { fill = false })
    c:hline(x, y + top_h, w, 2, "black")

    -- Cats / consumables
    local cy = y + top_h + gap
    section(c, x, cy, w, "Gatos", 0xF1B0)
    local block_y = cy + 52
    local half = math.floor((w - 28) / 2)
    local function consumable(cx, item, fallback)
        item = item or fallback
        local d = days_until(item.date)
        text(c, item.label or "", cx, block_y, 24, { bold = true })
        text(c, d and (d == 0 and "Hoje" or (math.abs(d) .. (d > 0 and " dias" or " dias"))) or fmt_date(item.date), cx, block_y + 36, 36, { bold = true })
        text(c, d and (d > 0 and "até repor" or "desde a previsão") or "previsão", cx, block_y + 78, 16, { color = "dark" })
        local total = tonumber(item.total_days) or 0
        local pct = total > 0 and clamp(math.floor((d or 0) / total * 100 + 0.5), 0, 100) or 0
        UI.progress(c, cx, block_y + 112, half - 18, 18, pct / 100, { border = 2 })
        text(c, pct .. "% restante", cx, block_y + 140, 17, { bold = true })
    end
    consumable(x, self.s.sand, { label = "Areia", date = "", total_days = 0 })
    c:vline(x + half + 14, block_y - 2, 166, 1, "gray")
    consumable(x + half + 28, self.s.food, { label = "Ração", date = "", total_days = 0 })
    local cats_end = block_y + 178
    c:hline(x, cats_end, w, 2, "black")

    -- Tasks and bills side by side
    local lists_y = cats_end + gap
    local colw = math.floor((w - 30) / 2)
    section(c, x, lists_y, colw, "Tarefas", 0xF046)
    section(c, x + colw + 30, lists_y, colw, "Contas", 0xF155)
    local row_y = lists_y + 52
    local function draw_items(items, xx, width, bills)
        local shown = 0
        for _, it in ipairs(items or {}) do
            if shown >= 5 then break end
            local label = bills and (it.name or it.text or "") or (it.text or it.name or "")
            if label ~= "" then
                local done = bills and (it.paid == true or it.done == true) or it.done == true
                local icon = done and UI.ICON.check or UI.ICON.box
                c:icon(icon, xx, row_y + shown * 48 + 2, 19, { color = "black" })
                local value = bills and (it.value or "") or ""
                local right = value ~= "" and tostring(value) or nil
                text(c, label, xx + 28, row_y + shown * 48, 18, { color = done and "gray" or "black", maxw = width - 36 - (right and 72 or 0) })
                if right then text(c, right, xx + width - 76, row_y + shown * 48, 16, { bold = true, maxw = 76, align = "right" }) end
                if done then c:hline(xx + 28, row_y + shown * 48 + 11, math.min(width - 40, c:measure(label, { size = 18 })), 1, "gray") end
                shown = shown + 1
            end
        end
        if shown == 0 then text(c, bills and "Sem contas anotadas" or "Sem tarefas anotadas", xx, row_y, 16, { color = "gray" }) end
    end
    draw_items(self.s.tasks, x, colw, false)
    c:vline(x + colw + 15, lists_y + 4, 280, 1, "gray")
    draw_items(self.s.bills, x + colw + 30, colw, true)
    local lists_end = lists_y + 52 + 5 * 48 + 8
    c:hline(x, lists_end, w, 2, "black")

    -- Cycles: manually entered dates/notes
    local cy2 = lists_end + gap
    section(c, x, cy2, w, "Ciclos", 0xF043)
    local line_y = cy2 + 52
    local function cycle_line(label, item, yy)
        item = item or {}
        local d = days_until(item.date)
        text(c, label, x + 4, yy, 22, { bold = true })
        text(c, item.note ~= "" and (item.note or "") or (d and (d == 0 and "Hoje" or (d > 0 and (d .. " dias") or ("há " .. math.abs(d) .. " dias"))) or "Sem data"), x + 72, yy, 19, { maxw = w - 210 })
        text(c, fmt_date(item.date), x + w - 132, yy, 17, { bold = true, align = "right", maxw = 132 })
    end
    cycle_line("K.", self.s.cycles and self.s.cycles.K, line_y)
    cycle_line("E.", self.s.cycles and self.s.cycles.E, line_y + 44)
end
function Casa:drawFull(c, W, H)
    self:drawTile(c, { x = 0, y = 0, w = W, h = H, cw = 1, ch = 1 }, false)
end
function Casa:hint() return "Painel da casa" end
return Casa
