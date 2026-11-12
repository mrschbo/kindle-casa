-- Read-only sync with the private household-data repository.
-- The token is stored only in the Kindle's local config.json, never in the public repo.
local GitHub = {}
local json = require("kindlecasa/json")

local function trim_base64(value)
    return (tostring(value or ""):gsub("%s", ""))
end

local function decode_base64(value)
    local ok, mime = pcall(require, "mime")
    if not ok or not mime or not mime.unb64 then
        return nil, "LuaSocket mime decoder unavailable"
    end
    local decoded = mime.unb64(trim_base64(value))
    if not decoded then return nil, "Could not decode GitHub response" end
    return decoded
end

function GitHub.getPanel(settings, net)
    settings = settings or {}
    if not settings.token or settings.token == "" then
        return nil, "GitHub token not configured"
    end
    local owner = settings.owner or "mrschbo"
    local repo = settings.repo or "kindle-casa-dados"
    local path = settings.path or "painel.json"
    local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/" .. path
    local headers = {
        ["Authorization"] = "Bearer " .. settings.token,
        ["Accept"] = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "Kindle-Casa-KOReader",
    }
    local response, err = net.getJson(url, headers, 15)
    if not response then return nil, err end
    if type(response) ~= "table" or type(response.content) ~= "string" then
        return nil, "GitHub did not return a file"
    end
    local raw, decode_err = decode_base64(response.content)
    if not raw then return nil, decode_err end
    local panel, json_err = json.decode(raw)
    if type(panel) ~= "table" then return nil, "Invalid painel.json: " .. tostring(json_err) end
    return panel
end

local function expiry_date(opened_at, days)
    local y, m, d = tostring(opened_at or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    days = tonumber(days)
    if not y or not days or days <= 0 then return "" end
    local stamp = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    if not stamp then return "" end
    return os.date("%Y-%m-%d", stamp + days * 86400)
end

function GitHub.toCasaSettings(panel, current)
    current = current or {}
    local cats = panel.cats or {}
    local litter = cats.litter or {}
    local food = cats.food or {}
    local function item(source, label)
        local days = tonumber(source.estimatedDays) or 0
        return {
            label = label,
            date = expiry_date(source.openedAt, days),
            total_days = days,
        }
    end
    return {
        city = current.city or "Joinville",
        lat = current.lat or -26.3044,
        lon = current.lon or -48.8456,
        sand = item(litter, "Areia"),
        food = item(food, "Ração"),
        tasks = type(panel.tasks) == "table" and panel.tasks or {},
        bills = type(panel.bills) == "table" and panel.bills or {},
        cycles = type(panel.cycles) == "table" and panel.cycles or { K = {}, E = {} },
        house = type(panel.house) == "table" and panel.house or {},
        updatedAt = panel.updatedAt,
    }
end

return GitHub
