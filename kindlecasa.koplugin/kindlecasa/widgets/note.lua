-- Note / quote: static text, or a random line from notes.txt in the Kindle Casa folder
local Base = require("kindlecasa/widgets/base")
local UI = require("kindlecasa/ui")
local U = require("kindlecasa/util")
local T = require("kindlecasa/i18n").t
local F = require("kindlecasa/i18n").f

local Note = Base.define{
    type = "note",
    name = "Note",
    icon = UI.ICON.note,
    interval = 3600,
    defaults = { text = "Hello! This is a note.\nChange the text in the editor.", rotate_file = false },
}

function Note:update()
    if not self.s.rotate_file then return false end
    local s = U.readFile(self.ctx.data_dir .. "/notes.txt")
    if not s then return false end
    local lines = {}
    for l in s:gmatch("[^\n]+") do if U.trim(l) ~= "" then lines[#lines + 1] = U.trim(l) end end
    if #lines == 0 then return false end
    self.line = lines[math.random(1, #lines)]
    return true
end

function Note:text() return self.line or self.s.text or "" end

function Note:drawContent(c, x, y, w, h, p)
    local t = self:text()
    local size = p.cw * p.ch >= 4 and 26 or (U.ulen(t) < 40 and 22 or 17)
    c:icon(UI.ICON.quote, x, y, 16, { color = "gray" })
    c:textbox(t, x, y + 22, w, h - 22, { size = size, font = "serif" })
end

return Note
