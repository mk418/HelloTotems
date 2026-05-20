local ADDON_NAME, ns = ...

ns.Config = {}
local Config = ns.Config

local accountDefaults = {
    barLocked = false,
}

local charDefaults = {}

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                applyDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            applyDefaults(target[k], v)
        end
    end
end

function Config:Init()
    HelloTotemsDB = HelloTotemsDB or {}
    HelloTotemsCharDB = HelloTotemsCharDB or {}
    applyDefaults(HelloTotemsDB, accountDefaults)
    applyDefaults(HelloTotemsCharDB, charDefaults)
end
