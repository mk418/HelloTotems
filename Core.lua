local ADDON_NAME, ns = ...
ns.ADDON_NAME = ADDON_NAME

-- Display names for the key bindings registered in Bindings.xml.
-- Bindings use the engine's "CLICK <Button>:<Button>" form so the
-- keypress dispatches a true hardware click on the secure button —
-- required for CastSpellByName not to trip ADDON_ACTION_FORBIDDEN.
_G.BINDING_HEADER_HELLOTOTEMS = "HelloTotems"
_G["BINDING_NAME_CLICK HelloTotemsSlot1:LeftButton"] = "Cast slot 1 (Fire)"
_G["BINDING_NAME_CLICK HelloTotemsSlot2:LeftButton"] = "Cast slot 2 (Earth)"
_G["BINDING_NAME_CLICK HelloTotemsSlot3:LeftButton"] = "Cast slot 3 (Water)"
_G["BINDING_NAME_CLICK HelloTotemsSlot4:LeftButton"] = "Cast slot 4 (Air)"
_G["BINDING_NAME_CLICK HelloTotemsSlot5:LeftButton"] = "Cast slot 5 (Weapon)"
_G["BINDING_NAME_CLICK HelloTotemsSlot6:LeftButton"] = "Cast slot 6 (Shield)"

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
    ns.TotemBar:Init()
    ns.Config:CreatePanel()
    print("|cff80ff80HelloTotems|r loaded - left-click casts, right-click or chevron opens the picker")
end)

SLASH_HELLOTOTEMS1 = "/ht"
SLASH_HELLOTOTEMS2 = "/hellototems"
SlashCmdList["HELLOTOTEMS"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if msg == "reset" then
        HelloTotemsDB = nil
        HelloTotemsCharDB = nil
        ReloadUI()
    elseif msg == "lock" then
        if not ns.enabled then return end
        ns.TotemBar:SetLocked(true)
        print("|cff80ff80HelloTotems|r frames locked")
    elseif msg == "unlock" then
        if not ns.enabled then return end
        ns.TotemBar:SetLocked(false)
        print("|cff80ff80HelloTotems|r frames unlocked - drag to move")
    elseif msg == "config" then
        if not ns.enabled then return end
        ns.Config:OpenPanel()
    elseif msg:match("^scale ") then
        if not ns.enabled then return end
        if InCombatLockdown() then
            print("|cff80ff80HelloTotems|r can't change scale in combat")
            return
        end
        local v = tonumber(msg:match("^scale%s+([%d.]+)$"))
        if not v or v < 0.5 or v > 2.0 then
            print("|cff80ff80HelloTotems|r usage: /ht scale <0.5-2.0>")
            return
        end
        HelloTotemsDB.scale = v
        ns.TotemBar:ApplyScale()
        print(("|cff80ff80HelloTotems|r scale set to %.2f"):format(v))
    else
        print("|cff80ff80HelloTotems|r commands: /ht lock | /ht unlock | /ht config | /ht scale <v> | /ht reset")
    end
end
