local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

ns.eventFrame = CreateFrame("Frame")
ns.eventHandlers = {}

-- Single gate for the whole addon. ADDON_LOADED + PLAYER_LOGIN always
-- fire — they're how we read saved variables and decide whether to
-- enable. After PLAYER_LOGIN any other event is dispatched only when
-- ns.enabled is true (set below for Shaman only). Non-Shamans get the
-- addon as a no-op: no frames, no hooks, no event volume.
ns.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" and not ns.enabled then
        return
    end
    local handlers = ns.eventHandlers[event]
    if not handlers then return end
    for i = 1, #handlers do
        handlers[i](...)
    end
end)

function ns:On(event, fn)
    if not ns.eventHandlers[event] then
        ns.eventHandlers[event] = {}
        ns.eventFrame:RegisterEvent(event)
    end
    table.insert(ns.eventHandlers[event], fn)
end

ns.eventFrame:RegisterEvent("ADDON_LOADED")
ns.eventFrame:RegisterEvent("PLAYER_LOGIN")

ns:On("ADDON_LOADED", function(name)
    if name ~= ADDON_NAME then return end
    ns.Config:Init()
end)

ns:On("PLAYER_LOGIN", function()
    local _, class = UnitClass("player")
    ns.playerClass = class
    if class ~= "SHAMAN" then return end
    ns.enabled = true
    print("|cff80ff80HelloTotems|r loaded")
end)

SLASH_HELLOTOTEMS1 = "/ht"
SLASH_HELLOTOTEMS2 = "/hellototems"
SlashCmdList["HELLOTOTEMS"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if msg == "reset" then
        HelloTotemsDB = nil
        HelloTotemsCharDB = nil
        ReloadUI()
    else
        print("|cff80ff80HelloTotems|r commands: /ht reset")
    end
end
