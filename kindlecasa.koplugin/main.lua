--[[--
InkDeck – a home dashboard for e-ink devices, running inside KOReader.

Menu: Tools → InkDeck. Configuration lives in the "kindle-casa" folder
(on a Kindle: the USB drive root, i.e. /mnt/us/kindle-casa/config.json).

@module koplugin.InkDeck
--]]

local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local I18N = require("kindlecasa/i18n")
local T = I18N.t
local Screen = Device.screen

local Core = require("kindlecasa/core")
local U = require("kindlecasa/util")
local GitHub = require("kindlecasa/github")

-- pick the language before any text is created
local function applyLanguage(cfg)
    local lang = cfg and cfg.language or "auto"
    if lang == "auto" or not lang then
        lang = G_reader_settings and G_reader_settings:readSetting("language") or "en"
    end
    I18N.set(lang)
end
applyLanguage(nil)
local json = require("kindlecasa/json")

local InkDeck = WidgetContainer:extend{
    name = "kindlecasa",
    is_doc_only = false,
}

local autostart_done = false

function InkDeck:init()
    Dispatcher:registerAction("kindlecasa_show", {
        category = "none", event = "ShowInkDeck", title = T("Open InkDeck"), general = true,
    })
    self.ui.menu:registerToMainMenu(self)
    if not autostart_done and G_reader_settings:isTrue("kindlecasa_autostart") and not self.ui.document then
        autostart_done = true
        UIManager:nextTick(function() self:show() end)
    end
end

function InkDeck:dataDir()
    if Device:isKindle() then return "/mnt/us/kindle-casa" end
    if Device:isKobo() then return "/mnt/onboard/kindle-casa" end
    return DataStorage:getDataDir() .. "/kindle-casa"
end

function InkDeck:configPath() return self:dataDir() .. "/config.json" end

function InkDeck:loadConfig()
    local dir = self:dataDir()
    U.mkdir(dir)
    U.mkdir(dir .. "/photos")
    U.mkdir(dir .. "/cache")
    -- bundled dashboard illustration; copy once to the plugin data folder
    local source = debug.getinfo(1, "S").source:gsub("^@", "")
    local plugin_dir = source:match("^(.*)/[^/]+$") or "."
    local asset = plugin_dir .. "/assets/sleeping-cat.png"
    if U.fileExists(asset) and not U.fileExists(dir .. "/sleeping-cat.png") then
        local bytes = U.readFile(asset)
        if bytes then U.writeFile(dir .. "/sleeping-cat.png", bytes) end
    end
    local path = self:configPath()
    if not U.fileExists(path) then
        local cfg = Core.defaultConfig()
        U.saveJson(path, cfg)
        return cfg
    end
    local cfg, err = U.loadJson(path)
    if type(cfg) ~= "table" then
        UIManager:show(InfoMessage:new{
            text = T("InkDeck: config.json is invalid and was ignored.") .. "\n\n" .. tostring(err),
        })
        return Core.defaultConfig()
    end
    -- fill in missing top-level defaults
    local def = Core.defaultConfig()
    for k, v in pairs(def) do
        if cfg[k] == nil then cfg[k] = v end
    end
    return cfg
end

function InkDeck:saveConfig(cfg)
    local ok, err = pcall(U.saveJson, self:configPath(), cfg)
    if not ok then logger.warn("InkDeck: could not save config", err) end
end

function InkDeck:makeContext(cfg)
    local NetworkMgr = require("ui/network/manager")
    local online = true
    local ctx = {
        net = require("kindlecasa/net"),
        data_dir = self:dataDir(),
        cache_dir = self:dataDir() .. "/cache",
        config = cfg,
    }
    ctx.fetchCasaData = function() return GitHub.getPanel(cfg.github, ctx.net) end
    ctx.battery = function()
        local ok, v = pcall(function() return Device:getPowerDevice():getCapacity() end)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    ctx.refreshOnline = function()
        local ok, v = pcall(NetworkMgr.isConnected, NetworkMgr)
        online = not ok or v
    end
    ctx.offline = function() return not online end
    ctx.input = function(title, default, callback)
        local InputDialog = require("ui/widget/inputdialog")
        local dialog
        dialog = InputDialog:new{
            title = title,
            input = default or "",
            buttons = { {
                { text = T("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                {
                    text = T("Save"),
                    is_enter_default = true,
                    callback = function()
                        local text = dialog:getInputText()
                        UIManager:close(dialog)
                        callback(text)
                        if self.view then self.view:repaint("partial") end
                    end,
                },
            } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end
    return ctx
end

function InkDeck:keepAwake(on)
    if self.config and self.config.keep_awake == false then return end
    local PluginShare = require("pluginshare")
    PluginShare.pause_auto_suspend = on
    if Device:isKindle() then
        os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver " .. (on and "1" or "0") .. " 2>/dev/null")
    end
end

function InkDeck:show()
    if self.view and not self.view.closed then return end
    local cfg = self:loadConfig()
    self.config = cfg
    applyLanguage(cfg)
    U.timezone = cfg.timezone or "system"
    U.clock12 = cfg.clock_12h == true
    math.randomseed(os.time())
    -- orientation
    self.prev_rotation = Screen:getRotationMode()
    local want = cfg.orientation == "landscape" and Screen.DEVICE_ROTATED_CLOCKWISE or Screen.DEVICE_ROTATED_UPRIGHT
    if Screen:getRotationMode() ~= want then
        local Event = require("ui/event")
        UIManager:broadcastEvent(Event:new("SetRotationMode", want))
        if Screen:getRotationMode() ~= want then Screen:setRotationMode(want) end
    end
    local View = require("kindlecasa/view")
    self.view = View:new{ plugin = self, config = cfg, ctx = self:makeContext(cfg) }
    self:keepAwake(true)
    UIManager:show(self.view, "full")
    -- make sure Wi-Fi is on; refresh everything once we are online
    local NetworkMgr = require("ui/network/manager")
    pcall(NetworkMgr.runWhenOnline, NetworkMgr, function()
        if self.view and not self.view.closed then
            for _, e in ipairs(self.view.dash:allInstances()) do e.inst.last_update = 0 end
            self.view:scheduleTick(0.5)
        end
    end)
end

function InkDeck:reload(view)
    view:close()
    UIManager:nextTick(function() self:show() end)
end

function InkDeck:onViewClosed(view)
    if self.view == view then self.view = nil end
    self:keepAwake(false)
    if self.prev_rotation and Screen:getRotationMode() ~= self.prev_rotation then
        local Event = require("ui/event")
        UIManager:broadcastEvent(Event:new("SetRotationMode", self.prev_rotation))
    end
end

function InkDeck:onShowInkDeck()
    self:show()
    return true
end

function InkDeck:addToMainMenu(menu_items)
    menu_items.kindle_casa = {
        text = T("Painel da Casa"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = T("Abrir painel"),
                callback = function() self:show() end,
            },
            {
                text = T("Abrir ao iniciar o KOReader"),
                checked_func = function() return G_reader_settings:isTrue("kindlecasa_autostart") end,
                callback = function() G_reader_settings:flipNilOrFalse("kindlecasa_autostart") end,
            },
            {
                text = "Conectar dados do GitHub",
                keep_menu_open = true,
                callback = function()
                    local InputDialog = require("ui/widget/inputdialog")
                    local dialog
                    local gh = self.config.github or { owner = "mrschbo", repo = "kindle-casa-dados", path = "painel.json", refresh_minutes = 15 }
                    dialog = InputDialog:new{
                        title = "Token GitHub (somente leitura)",
                        input = gh.token or "",
                        text_type = "password",
                        buttons = { {
                            { text = T("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                            { text = T("Save"), is_enter_default = true, callback = function()
                                gh.token = dialog:getInputText()
                                gh.owner, gh.repo, gh.path = "mrschbo", "kindle-casa-dados", "painel.json"
                                gh.refresh_minutes = tonumber(gh.refresh_minutes) or 15
                                self.config.github = gh
                                self:saveConfig(self.config)
                                if self.view and self.view.dash then
                                    for _, entry in ipairs(self.view.dash:allInstances()) do
                                        if entry.inst.syncPanel then entry.inst.last_panel_sync = 0 end
                                        entry.inst.last_update = 0
                                    end
                                    self.view:scheduleTick(0.5)
                                end
                                UIManager:close(dialog)
                                UIManager:show(InfoMessage:new{ text = gh.token ~= "" and "Token salvo. O painel buscará os dados na próxima atualização." or "Token removido. O painel usará os dados locais." })
                            end },
                        } },
                    }
                    UIManager:show(dialog)
                    dialog:onShowKeyboard()
                end,
            },
            {
                text = T("Sobre e pastas"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = "Painel da Casa " .. Core.VERSION .. "\n\n" .. T("Configuration:") .. "\n" .. self:configPath()
                            .. "\n\n" .. T("Photos:") .. "\n" .. self:dataDir() .. "/photos"
                            .. "\n\n" .. T("Controles: toque no menu para sair; o painel não abre widgets em tela cheia."),
                    })
                end,
            },
        },
    }
end

return InkDeck
