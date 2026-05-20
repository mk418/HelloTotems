local ADDON_NAME, ns = ...

ns.Config = {}
local Config = ns.Config

local accountDefaults = {
    barLocked = false,
    scale = 1.0,
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

function Config:CreatePanel()
    local panel = CreateFrame("Frame")
    panel.name = "HelloTotems"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HelloTotems")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Totem manager for Classic Era Shamans.")

    local lock = CreateFrame("CheckButton", "HelloTotemsLockCheck", panel, "UICheckButtonTemplate")
    lock:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
    _G[lock:GetName() .. "Text"]:SetText("Lock bar position")
    lock:SetScript("OnShow", function(self)
        self:SetChecked(HelloTotemsDB and HelloTotemsDB.barLocked or false)
    end)
    lock:SetScript("OnClick", function(self)
        if ns.TotemBar then ns.TotemBar:SetLocked(self:GetChecked()) end
    end)

    -- Scale slider. SetScale on a frame with protected children is
    -- combat-blocked, so Bar:ApplyScale no-ops in lockdown.
    local scaleSlider = CreateFrame("Slider", "HelloTotemsScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 4, -28)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(0.6, 1.6)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    if scaleSlider.Low  then scaleSlider.Low:SetText("0.6") end
    if scaleSlider.High then scaleSlider.High:SetText("1.6") end
    if scaleSlider.Text then scaleSlider.Text:SetText("Bar scale") end

    local valueLabel = scaleSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("LEFT", scaleSlider, "RIGHT", 12, 0)

    scaleSlider:SetScript("OnShow", function(self)
        local s = (HelloTotemsDB and HelloTotemsDB.scale) or 1.0
        self:SetValue(s)
        valueLabel:SetText(("%.2f"):format(s))
    end)
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        valueLabel:SetText(("%.2f"):format(value))
        HelloTotemsDB = HelloTotemsDB or {}
        if HelloTotemsDB.scale == value then return end
        HelloTotemsDB.scale = value
        if ns.TotemBar and ns.TotemBar.ApplyScale then ns.TotemBar:ApplyScale() end
    end)

    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -4, -28)
    help:SetJustifyH("LEFT")
    help:SetText(
        "Slash commands:\n" ..
        "  /ht lock - lock the bar position\n" ..
        "  /ht unlock - unlock the bar (drag to move)\n" ..
        "  /ht config - open this panel\n" ..
        "  /ht reset - reset all saved variables and reload\n\n" ..
        "Key bindings: Esc -> Key Bindings -> HelloTotems"
    )

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.category = category
    end

    self.panel = panel
end

function Config:OpenPanel()
    if Settings and Settings.OpenToCategory and self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
