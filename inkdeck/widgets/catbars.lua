local G_reader_share = require("G_reader_share")
local UIManager = require("ui/uimanager")
local Net = require("net")
local ljson = require("serializers/ljson")

local CatBars = {}

function CatBars:new(o)
    o = o or {}
    setmetatable(self, { __index = CatBars })
    self.title = o.title or "Bars"
    self.url = o.url or ""
    self.key = o.key or "sand"
    self.days = o.days or 5
    return self
end

function CatBars:fetch()
    if not self.url or self.url == "" then return nil end
    local ok, resp = pcall(function()
        return Net.getUrl(self.url)
    end)
    if not ok or not resp then return nil end
    local ok2, data = pcall(ljson.decode, resp)
    if not ok2 then return nil end
    return data
end

function CatBars:paint(bb, x, y, w, h)
    local data = self:fetch()
    if not data or not data[self.key] then
        bb:fillText(x, y + 10, w, 20, {text = self.title .. " (sem dados)", align = "left"})
        return
    end

    local entries = data[self.key]
    -- pega últimos N dias
    local recent = {}
    for i = math.max(1, #entries - self.days + 1), #entries do
        table.insert(recent, entries[i])
    end
    if #recent == 0 then
        bb:fillText(x, y + 10, w, 20, {text = self.title, align = "left"})
        return
    end

    -- título
    bb:fillText(x, y, w, 16, {text = self.title, align = "left", size = 12})

    -- barras
    local top = y + 20
    local bottom = y + h - 16
    local bar_area_h = bottom - top
    local n = #recent
    local gap = 4
    local bar_w = math.floor((w - (n - 1) * gap) / n)
    local max_val = 1
    for _, e in ipairs(recent) do
        if e.grams > max_val then max_val = e.grams end
    end

    for i, e in ipairs(recent) do
        local bx = x + (i - 1) * (bar_w + gap)
        local ratio = e.grams / max_val
        local bh = math.floor(ratio * bar_area_h)
        local by = bottom - bh
        bb:fillRect(bx, by, bar_w, bh, 0) -- 0 = preto
    end

    -- labels (g)
    for i, e in ipairs(recent) do
        local bx = x + (i - 1) * (bar_w + gap)
        bb:fillText(bx, bottom, bar_w, 14, {text = tostring(e.grams), align = "center", size = 9})
    end
end

return CatBars   
