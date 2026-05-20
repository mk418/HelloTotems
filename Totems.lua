local ADDON_NAME, ns = ...

ns.Totems = {}
local T = ns.Totems

-- Slots 1-4 mirror Blizzard's GetTotemInfo / TotemFrame. Slot 5 is our
-- own column for weapon imbues — not a real totem slot, just another
-- secure-cast button that fits the same flyout model.
T.SLOT_FIRE   = 1
T.SLOT_EARTH  = 2
T.SLOT_WATER  = 3
T.SLOT_AIR    = 4
T.SLOT_WEAPON = 5
T.SLOT_SHIELD = 6

T.NUM_SLOTS = 6

T.slotLabel = {
    [T.SLOT_FIRE]   = "Fire",
    [T.SLOT_EARTH]  = "Earth",
    [T.SLOT_WATER]  = "Water",
    [T.SLOT_AIR]    = "Air",
    [T.SLOT_WEAPON] = "Weapon",
    [T.SLOT_SHIELD] = "Shield",
}

-- Placeholder spell IDs used to fetch an icon for empty slots. Looked up
-- by ID (not name) so GetSpellInfo returns data even for spells the
-- player hasn't learned yet.
T.placeholderSpellID = {
    [T.SLOT_FIRE]   = 3599,  -- Searing Totem (rank 1)
    [T.SLOT_EARTH]  = 8071,  -- Stoneskin Totem (rank 1)
    [T.SLOT_WATER]  = 5394,  -- Healing Stream Totem (rank 1)
    [T.SLOT_AIR]    = 8512,  -- Windfury Totem (rank 1)
    [T.SLOT_WEAPON] = 8232,  -- Windfury Weapon (rank 1)
    [T.SLOT_SHIELD] = 324,   -- Lightning Shield (rank 1)
}

-- Default top-down order per column. Names are base spell names; the secure
-- button casts the highest known rank automatically.
T.defaultOrder = {
    [T.SLOT_FIRE] = {
        "Searing Totem",
        "Magma Totem",
        "Fire Nova Totem",
        "Flametongue Totem",
        "Frost Resistance Totem",
    },
    [T.SLOT_EARTH] = {
        "Tremor Totem",
        "Stoneskin Totem",
        "Strength of Earth Totem",
        "Stoneclaw Totem",
        "Earthbind Totem",
        "Earth Elemental Totem",
    },
    [T.SLOT_WATER] = {
        "Mana Spring Totem",
        "Healing Stream Totem",
        "Mana Tide Totem",
        "Poison Cleansing Totem",
        "Disease Cleansing Totem",
        "Fire Resistance Totem",
    },
    [T.SLOT_AIR] = {
        "Windfury Totem",
        "Grace of Air Totem",
        "Grounding Totem",
        "Wrath of Air Totem",
        "Tranquil Air Totem",
        "Windwall Totem",
        "Nature Resistance Totem",
        "Sentry Totem",
    },
    [T.SLOT_WEAPON] = {
        "Windfury Weapon",
        "Flametongue Weapon",
        "Frostbrand Weapon",
        "Rockbiter Weapon",
    },
    [T.SLOT_SHIELD] = {
        "Lightning Shield",
    },
}

T.nameToSlot = {}
for slot, list in pairs(T.defaultOrder) do
    for _, name in ipairs(list) do
        T.nameToSlot[name] = slot
    end
end

local function knownTotemNames()
    local set = {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        if offset and numSpells then
            for i = offset + 1, offset + numSpells do
                local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                if name and T.nameToSlot[name] then
                    set[name] = true
                end
            end
        end
    end
    return set
end

-- Returns { [slot] = { spellName, ... } } limited to known totems, in
-- configured order. Unknown totems (not learned) are skipped.
function T:ScanKnown()
    local order = (HelloTotemsDB and HelloTotemsDB.totemOrder) or T.defaultOrder
    local known = knownTotemNames()
    local result = {}
    for slot = 1, T.NUM_SLOTS do
        result[slot] = {}
        local list = order[slot] or {}
        for _, name in ipairs(list) do
            if known[name] then
                table.insert(result[slot], name)
            end
        end
    end
    return result
end
