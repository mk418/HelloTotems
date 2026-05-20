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

-- Flyout open/close has to run from a secure execution context to work
-- in combat (Show/Hide on a frame with SecureActionButton children is
-- protected). The chev is a plain Button with SecureHandlerClickTemplate
-- — _onclick on it runs in the restricted env and toggles the flyout.
--
-- Right-click on the main button gets routed through the same snippet
-- via SecureActionButton's type2="click"/clickbutton2 mechanism: when
-- the user right-clicks, the secure cast handler calls chev:Click(),
-- which fires the chev's _onclick. No insecure wrappers in this path,
-- so it stays combat-safe.
local CHEV_ONCLICK_SNIPPET = ([[
    if self:GetAttribute("empty") then return end
    local me = self:GetFrameRef("myflyout")
    if not me then return end
    if me:IsShown() then
        me:Hide()
    else
        for i = 1, %d do
            local f = self:GetFrameRef("flyout"..i)
            if f and f ~= me and f:IsShown() then f:Hide() end
        end
        me:Show()
    end
]]):format(NUM_SLOTS)

-- Each flyout entry is a SecureHandlerClick (not a SecureActionButton).
-- Its _onclick snippet sets spell1 on a shared hidden cast button and
-- fires its click to do the actual cast, then reassigns the main button
-- and hides the flyout. Doing all four through the secure env means the
-- whole chain — cast + reassign + close — works in combat.
local ENTRY_ONCLICK_SNIPPET = [[
    local spell = self:GetAttribute("spell")
    if not spell then return end
    local helper = self:GetFrameRef("castHelper")
    if helper then
        helper:SetAttribute("spell1", spell)
        helper:Click()
    end
    local main = self:GetFrameRef("main")
    if main then
        main:SetAttribute("spell1", spell)
    end
    local me = self:GetFrameRef("myflyout")
    if me then me:Hide() end
]]

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
    -- Insecure path used by the main button's PostClick on left-click —
    -- bail in combat (Hide on a flyout is protected; the chev's secure
    -- snippet handles closing during combat).
    if InCombatLockdown() then return end
    for i = 1, NUM_SLOTS do
        local m = Bar.slots[i]
        if m and m.flyout and m ~= except then m.flyout:Hide() end
    end
end

local function newFlyoutEntry(parent, mainBtn)
    -- SecureHandlerClick (not SecureActionButton): clicking runs the
    -- _onclick snippet, which fires Bar.castHelper to do the cast,
    -- reassigns the main button's spell1, and hides the flyout — all
    -- in the secure env so the whole chain works in combat. PostClick
    -- handles non-protected visual / DB updates.
    local btn = CreateFrame("Button", nil, parent, "SecureHandlerClickTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    styleIconButton(btn)
    btn:RegisterForClicks("LeftButtonUp")

    btn:SetFrameRef("castHelper", Bar.castHelper)
    btn:SetFrameRef("main", mainBtn)
    btn:SetFrameRef("myflyout", mainBtn.flyout)
    btn:SetAttribute("_onclick", ENTRY_ONCLICK_SNIPPET)
    -- "spell" attribute is populated per-entry by setEntrySpell.

    btn:SetScript("PostClick", function(self)
        HelloTotemsDB.slotAssignment = HelloTotemsDB.slotAssignment or {}
        HelloTotemsDB.slotAssignment[mainBtn.slot] = self.spellName
        mainBtn.spellName = self.spellName
        mainBtn.spellID = self.spellID
        mainBtn.icon:SetTexture(self.icon:GetTexture() or "")
        mainBtn.icon:SetDesaturated(false)
        mainBtn.icon:SetVertexColor(1, 1, 1, 1)
        applyUsable(mainBtn)
        updateMainCooldown(mainBtn)
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
    entry:SetAttribute("spell", spellName)
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
        if mainBtn.chev then
            mainBtn.chev:SetAttribute("empty", true)
            mainBtn.chev:Hide()
        end
        return
    end
    mainBtn.empty = false
    if mainBtn.chev then
        mainBtn.chev:SetAttribute("empty", nil)
        -- No need for a picker when there's only one choice.
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
    -- type1=spell casts on left-click; type2=click routes right-click
    -- through the secure cast handler to the chev (clickbutton2, wired
    -- up below), whose _onclick snippet toggles the flyout. This keeps
    -- the whole right-click path in secure-handler land so it works in
    -- combat.
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("type2", "click")
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
    btn:SetScript("PostClick", function(self, button)
        -- Close other flyouts after a cast. Insecure (PostClick runs in
        -- normal Lua), so combat-guarded — the chev's secure snippet
        -- already hides siblings when opening, which covers combat.
        if button == "LeftButton" then closeAllFlyouts() end
    end)

    -- SecureHandlerBaseTemplate marks the flyout as a secure frame so the
    -- chev's _onclick snippet can call Show/Hide on it in combat (a plain
    -- Frame's visibility methods aren't exposed to the restricted env).
    local f = CreateFrame("Frame", nil, btn, "SecureHandlerBaseTemplate")
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
    local chev = CreateFrame("Button", "HelloTotemsSlot" .. slot .. "Chev",
        btn, "SecureHandlerClickTemplate")
    btn.chev = chev
    btn:SetAttribute("clickbutton2", chev)
    chev:SetSize(12, 12)
    chev:SetPoint("BOTTOM", btn, "TOP", 0, 0)
    chev:SetFrameLevel(btn:GetFrameLevel() + 10)

    local chevTex = chev:CreateTexture(nil, "ARTWORK")
    chevTex:SetAllPoints()
    chevTex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    chevTex:SetRotation(math.pi / 2)
    chevTex:SetVertexColor(1, 1, 1, 0.9)

    chev:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- OnClick is the secure _onclick snippet wired up in Bar:Init
    -- (toggles this slot's flyout, hides siblings) — runs in combat.

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

    -- Shared hidden SecureActionButton that flyout-entry snippets click
    -- to fire a cast in the secure env. The entry snippet sets spell1 on
    -- this helper just before Click() — one helper for all entries since
    -- only one entry click happens at a time.
    local castHelper = CreateFrame("Button", "HelloTotemsCastHelper",
        UIParent, "SecureActionButtonTemplate")
    castHelper:Hide()
    castHelper:SetAttribute("type1", "spell")
    self.castHelper = castHelper

    self.slots = {}
    for i = 1, NUM_SLOTS do
        local m = newMainButton(f, i)
        m:SetPoint("LEFT", f, "LEFT", (i - 1) * (BUTTON_SIZE + SLOT_SPACING), 0)
        self.slots[i] = m
    end

    -- Each chev gets refs to its own flyout (toggle target) and to every
    -- flyout (so opening one closes the others), then the secure _onclick
    -- snippet that does the toggle in the restricted env. The main button
    -- routes right-click to the chev via type2="click", so both the chev
    -- click path and the main-button right-click share this same snippet.
    for i = 1, NUM_SLOTS do
        local m = self.slots[i]
        m.chev:SetFrameRef("myflyout", m.flyout)
        for j = 1, NUM_SLOTS do
            m.chev:SetFrameRef("flyout" .. j, self.slots[j].flyout)
        end
        m.chev:SetAttribute("_onclick", CHEV_ONCLICK_SNIPPET)
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
