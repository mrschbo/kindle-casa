-- Tiny translation layer for the Kindle Casa dashboard.
-- Usage:  local T = require("kindlecasa/i18n").t   T("Back: close")
--         local F = require("kindlecasa/i18n").f   F("%d open", n)
local I = { lang = "en" }

local NAMES = {
    en = {
        DAYS = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" },
        DAYS_SHORT = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" },
        MONTHS = { "January", "February", "March", "April", "May", "June", "July",
            "August", "September", "October", "November", "December" },
        MONTHS_SHORT = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
    },
    pt = {
        DAYS = { "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado", "domingo" },
        DAYS_SHORT = { "seg", "ter", "qua", "qui", "sex", "sáb", "dom" },
        MONTHS = { "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro" },
        MONTHS_SHORT = { "jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez" },
    },
}

local TRANSLATIONS = {
    pt = {
        ["Open Painel da Casa"] = "Abrir painel", ["Open when KOReader starts"] = "Abrir ao iniciar o KOReader",
        ["About & folders"] = "Sobre e pastas", ["Landscape"] = "Paisagem", ["Portrait"] = "Retrato",
        ["Refresh everything"] = "Atualizar tudo", ["Reload configuration"] = "Recarregar configuração",
        ["Hide selection frame"] = "Ocultar seleção", ["Show selection frame"] = "Mostrar seleção",
        ["Exit Painel da Casa"] = "Sair do painel", ["Cancel"] = "Cancelar", ["Save"] = "Salvar",
        ["Widget error:"] = "Erro no widget:", ["Loading weather …"] = "Carregando clima …",
        ["Controles: toque no menu para sair; o painel não abre widgets em tela cheia."] = "Controles: toque no menu para sair; o painel não abre widgets em tela cheia.",
        ["Weather unavailable"] = "Clima indisponível", ["Date missing (YYYY-MM-DD)"] = "Data ausente (AAAA-MM-DD)",
        ["Back: close"] = "Voltar: fechar", ["Configuration:"] = "Configuração:", ["Photos:"] = "Fotos:",
        ["Empty"] = "Vazio", ["Page %d"] = "Página %d", ["%d open"] = "%d em aberto",
    },

}

I.available = { "en", "pt" }

-- Accepts "pt", "pt_BR", "en_US", "C", …
function I.set(lang)
    lang = tostring(lang or "en"):lower():match("^(%a%a)") or "en"
    I.lang = (TRANSLATIONS[lang] or lang == "en") and lang or "en"
end

function I.t(s)
    local tr = TRANSLATIONS[I.lang]
    return tr and tr[s] or s
end

function I.f(s, ...)
    return string.format(I.t(s), ...)
end

function I.names()
    return NAMES[I.lang] or NAMES.en
end

-- for tests: keys missing in a language
function I.missing(lang, keys)
    local out = {}
    for _, k in ipairs(keys) do
        if not (TRANSLATIONS[lang] or {})[k] then out[#out + 1] = k end
    end
    return out
end

return I
