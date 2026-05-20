local ADDON_NAME, ns = ...

ns.TotemBar = {}
local Bar = ns.TotemBar

local BUTTON_SIZE = 36
local SLOT_SPACING = 6
local FLYOUT_SPACING = 6
local NUM_SLOTS = 6
-- Standard Blizzard action-button: 64x64 gold-border texture framing a
-- 36x36 hitbox, with the border centered y=-1 (matches ActionButton.xml).
local NORMAL_TEXTURE_SIZE = 64
local NORMAL_TEXTURE_Y_OFFSET = -1

local function styleIconButton(btn)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local normal = btn:GetNormalTexture()
    if normal then
        normal:ClearAllPoints()
        normal:SetPoint("CENTER", 0, NORMAL_TEXTURE_Y_OFFSET)
        normal:SetSize(NORMAL_TEXTURE_SIZE, NORMAL_TEXTURE_SIZE)
        normal:SetDrawLayer("OVERLAY")
    end

    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end

-- Blue-tint the icon when the assigned spell can't be cast for lack
-- of mana. Empty / placeholder slots are left alone (applySpell owns
-- their vertex color).
local function applyUsable(btn)
    if not btn.spellName then return end
    local _, noMana = IsUsableSpell(btn.spellName)
    if noMana then
        btn.icon:SetVertexColor(0.5, 0.5, 1.0, 1)
    else
        btn.icon:SetVertexColor(1, 1, 1, 1)
    end
end

local function applySpell(btn, spellName)
    btn.spellName = spellName
    if not spellName then
        -- Empty slot: dim, desaturated icon of a representative spell
        -- for the slot. Looked up by ID so it works regardless of
        -- whether the player has learned that spell yet.
        local id = ns.Totems.placeholderSpellID[btn.slot]
        local placeholderIcon = id and select(3, GetSpellInfo(id))
        btn.icon:SetTexture(placeholderIcon or "")
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(1, 1, 1, 0.35)
        btn.spellID = nil
        btn:SetAttribute("spell1", nil)
        return
    end
    local _, _, icon, _, _, _, spellID = GetSpellInfo(spellName)
    btn.spellID = spellID
    btn.icon:SetTexture(icon or "")
    btn.icon:SetDesaturated(false)
    btn.icon:SetVertexColor(1, 1, 1, 1)
    btn:SetAttribute("spell1", spellName)
    applyUsable(btn)
end

local function updateMainCooldown(btn)
    local slot = btn.slot
    -- Active totem / weapon-imbue / shield duration takes priority over
    -- the assigned spell's GCD.
    if slot and slot >= 1 and slot <= 4 then
        local haveTotem, _, startTime, duration = GetTotemInfo(slot)
        if haveTotem and duration and duration > 0 then
            btn.cooldown:SetReverse(true)
            btn.cooldown:SetCooldown(startTime, duration)
            return
        end
    elseif slot == 5 then
        local hasMH, mhExp = GetWeaponEnchantInfo()
        if hasMH and mhExp and mhExp > 0 then
            -- mhExp is milliseconds remaining; the API doesn't expose
            -- the original duration, so we anchor the swirl at "now"
            -- with whatever's left as the visible duration.
            btn.cooldown:SetReverse(true)
            btn.cooldown:SetCooldown(GetTime(), mhExp / 1000)
            return
        end
    elseif slot == 6 and btn.spellName then
        -- UnitBuff in Classic Era takes an index, not a name. Walk the
        -- player's buffs and match by spell name; also pick up the
        -- stack count for the charge overlay.
        if btn.charges then btn.charges:SetText("") end
        local duration, expirationTime, count
        for i = 1, 40 do
            local name, _, cnt, _, dur, exp = UnitBuff("player", i)
            if not name then break end
            if name == btn.spellName then
                duration, expirationTime, count = dur, exp, cnt
                break
            end
        end
        if duration and duration > 0 and expirationTime then
            btn.cooldown:SetReverse(true)
            btn.cooldown:SetCooldown(expirationTime - duration, duration)
            if btn.charges and count and count > 0 then
                btn.charges:SetText(count)
            end
            return
        end
    end
    btn.cooldown:SetReverse(false)
    if not btn.spellName then btn.cooldown:Clear(); return end
    local start, duration, enabled = GetSpellCooldown(btn.spellName)
    if enabled == 1 and duration and duration > 0 then
        btn.cooldown:SetCooldown(start, duration)
    else
        btn.cooldown:Clear()
    end
end

local function showTooltip(self)
    if not self.spellName then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellID then
        GameTooltip:SetSpellByID(self.spellID)
    else
        GameTooltip:SetText(self.spellName)
    end
    GameTooltip:Show()
end

local function closeAllFlyouts(except)
    for i = 1, NUM_SLOTS do
        local m = Bar.slots[i]
        if m and m.flyout and m ~= except then m.flyout:Hide() end
    end
end

local function newFlyoutEntry(parent, mainBtn)
    -- Pure SecureActionButton: clicking fires the cast via the same
    -- secure path the main button uses. The "reassign the main button"
    -- side-effect lives in PostClick — applied immediately out of combat,
    -- and deferred to PLAYER_REGEN_ENABLED in combat (SetAttribute on a
    -- protected frame isn't allowed mid-combat from insecure code, and
    -- every restricted-env workaround I tried also broke the cast).
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    styleIconButton(btn)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetAttribute("type1", "spell")
    -- spell1 attribute is populated per-entry by setEntrySpell.

    btn:SetScript("PostClick", function(self)
        -- Non-protected updates: safe in or out of combat.
        HelloTotemsDB.slotAssignment = HelloTotemsDB.slotAssignment or {}
        HelloTotemsDB.slotAssignment[mainBtn.slot] = self.spellName
        mainBtn.spellName = self.spellName
        mainBtn.spellID = self.spellID
        mainBtn.icon:SetTexture(self.icon:GetTexture() or "")
        updateMainCooldown(mainBtn)
        mainBtn.flyout:Hide()
        -- Protected attribute: write now if we can, otherwise let
        -- Bar:Refresh re-apply from saved vars when combat ends.
        if InCombatLockdown() then
            Bar.needsRefresh = true
        else
            mainBtn:SetAttribute("spell1", self.spellName)
        end
    end)

    btn:SetScript("OnEnter", showTooltip)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    return btn
end

local function setEntrySpell(entry, spellName)
    entry.spellName = spellName
    local _, _, icon, _, _, _, spellID = GetSpellInfo(spellName)
    entry.spellID = spellID
    entry.icon:SetTexture(icon or "")
    entry:SetAttribute("spell1", spellName)
end

local function populateFlyout(mainBtn, knownList)
    local f = mainBtn.flyout
    for _, e in ipairs(f.entries) do
        e:Hide()
        e:ClearAllPoints()
    end
    if #knownList == 0 then
        f:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        mainBtn.empty = true
        if mainBtn.chev then mainBtn.chev:Hide() end
        return
    end
    mainBtn.empty = false
    -- No need for a picker when there's only one choice.
    if mainBtn.chev then
        if #knownList == 1 then mainBtn.chev:Hide() else mainBtn.chev:Show() end
    end
    for i, name in ipairs(knownList) do
        local entry = f.entries[i]
        if not entry then
            entry = newFlyoutEntry(f, mainBtn)
            f.entries[i] = entry
        end
        setEntrySpell(entry, name)
        entry:SetPoint("BOTTOM", f, "BOTTOM", 0, (i - 1) * (BUTTON_SIZE + FLYOUT_SPACING))
        entry:Show()
    end
    local h = #knownList * (BUTTON_SIZE + FLYOUT_SPACING) - FLYOUT_SPACING
    f:SetSize(BUTTON_SIZE, h)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", mainBtn, "TOP", 0, FLYOUT_SPACING)
end

local function newMainButton(parent, slot)
    local btn = CreateFrame("Button", "HelloTotemsSlot" .. slot, parent,
        "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- type1 only: left-click casts via the secure code path. Right-click
    -- has no secure type, so the insecure OnClick hook below is free to
    -- repurpose it for opening the flyout.
    btn:SetAttribute("type1", "spell")
    btn.slot = slot

    styleIconButton(btn)

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints()
    btn.cooldown = cd

    -- Charge count overlay for slots that track a stack-based buff
    -- (currently only Lightning Shield). Parented to the cooldown frame
    -- so it renders above the swirl. Populated by updateMainCooldown.
    if slot == 6 then
        local charges = cd:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        charges:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -2)
        btn.charges = charges
    end

    btn:SetScript("OnEnter", showTooltip)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:HookScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.empty then return end
            if self.flyout:IsShown() then
                self.flyout:Hide()
            else
                closeAllFlyouts(self)
                self.flyout:Show()
            end
        else
            closeAllFlyouts()
        end
    end)

    local f = CreateFrame("Frame", nil, btn)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    f.entries = {}
    btn.flyout = f

    -- Dedicated flyout-open sub-button. Sits over the main button's bottom
    -- edge with a higher FrameLevel so clicks on this area route here, not
    -- to the secure cast button below. This keeps the main button as a
    -- pure secure cast — no insecure right-click trickery.
    -- Arrow sits just above the button to signal that the flyout opens
    -- upward from here. ChatFrameExpandArrow points down by default;
    -- TexCoord flip turns it into an upward arrow.
    local chev = CreateFrame("Button", nil, btn)
    btn.chev = chev
    chev:SetSize(12, 12)
    chev:SetPoint("BOTTOM", btn, "TOP", 0, 0)
    chev:SetFrameLevel(btn:GetFrameLevel() + 10)

    local chevTex = chev:CreateTexture(nil, "ARTWORK")
    chevTex:SetAllPoints()
    chevTex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    chevTex:SetRotation(math.pi / 2)
    chevTex:SetVertexColor(1, 1, 1, 0.9)

    chev:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    chev:SetScript("OnClick", function()
        if btn.empty then return end
        if btn.flyout:IsShown() then
            btn.flyout:Hide()
        else
            closeAllFlyouts(btn)
            btn.flyout:Show()
        end
    end)

    return btn
end

function Bar:Init()
    local f = CreateFrame("Frame", "HelloTotemsBar", UIParent)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not HelloTotemsDB.barLocked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        HelloTotemsDB.barPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    local totalWidth = NUM_SLOTS * BUTTON_SIZE + (NUM_SLOTS - 1) * SLOT_SPACING
    f:SetSize(totalWidth, BUTTON_SIZE)

    local pos = HelloTotemsDB.barPos
    if pos then
        f:ClearAllPoints()
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -230)
    end

    self.frame = f
    self.slots = {}
    for i = 1, NUM_SLOTS do
        local m = newMainButton(f, i)
        m:SetPoint("LEFT", f, "LEFT", (i - 1) * (BUTTON_SIZE + SLOT_SPACING), 0)
        self.slots[i] = m
    end

    self:Refresh()
    self:ApplyScale()

    ns:On("SPELL_UPDATE_COOLDOWN", function()
        for i = 1, NUM_SLOTS do updateMainCooldown(Bar.slots[i]) end
    end)
    ns:On("SPELL_UPDATE_USABLE", function()
        for i = 1, NUM_SLOTS do
            if Bar.slots[i] then applyUsable(Bar.slots[i]) end
        end
    end)
    ns:On("PLAYER_TOTEM_UPDATE", function()
        for i = 1, NUM_SLOTS do updateMainCooldown(Bar.slots[i]) end
    end)
    ns:On("PLAYER_ENTERING_WORLD", function()
        for i = 1, NUM_SLOTS do updateMainCooldown(Bar.slots[i]) end
    end)
    ns:On("UNIT_INVENTORY_CHANGED", function()
        if Bar.slots[5] then updateMainCooldown(Bar.slots[5]) end
    end)
    ns:On("UNIT_AURA", function(unit)
        if unit ~= "player" then return end
        if Bar.slots[6] then updateMainCooldown(Bar.slots[6]) end
    end)
    ns:On("SPELLS_CHANGED", function()
        if InCombatLockdown() then
            Bar.needsRefresh = true
        else
            Bar:Refresh()
        end
    end)
    ns:On("PLAYER_REGEN_ENABLED", function()
        if Bar.needsRefresh then
            Bar:Refresh()
            Bar.needsRefresh = false
        end
    end)
end

function Bar:Refresh()
    if InCombatLockdown() then
        self.needsRefresh = true
        return
    end
    local known = ns.Totems:ScanKnown()
    HelloTotemsDB.slotAssignment = HelloTotemsDB.slotAssignment or {}
    local assignments = HelloTotemsDB.slotAssignment

    for slot = 1, NUM_SLOTS do
        local list = known[slot]
        local mainBtn = self.slots[slot]
        populateFlyout(mainBtn, list)

        local pick
        local current = assignments[slot]
        for _, n in ipairs(list) do
            if n == current then pick = current; break end
        end
        if not pick then pick = list[1] end
        assignments[slot] = pick
        applySpell(mainBtn, pick)
        updateMainCooldown(mainBtn)
    end
end

function Bar:SetLocked(locked)
    HelloTotemsDB.barLocked = locked and true or false
end

-- SetScale on a frame with protected children is combat-restricted, so
-- this no-ops in lockdown — callers (slash, slider) are themselves
-- gated out-of-combat.
function Bar:ApplyScale()
    if InCombatLockdown() then return end
    if not self.frame then return end
    self.frame:SetScale(HelloTotemsDB.scale or 1.0)
end
