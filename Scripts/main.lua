-- PotionTweaks (UE4SS 3.0.1 mod for Dauntless 1.14.7, Dauntless Forever Modded mode) - by GoldenHeartbell
-- Changes potion (tonic) strength / duration / stack size.
--
-- Two parts, one mod folder:
--   dlls\main.dll     the "Potions" tab in the UE4SS window (Ctrl+O in game); it only writes settings.txt
--   Scripts\main.lua  this file: puts the values from settings.txt into each potion the game makes
-- Files in the mod folder:
--   settings.txt  your values, one "Potion.Property=value" per line, e.g. "Damage_Block_Potion.NumCharges=5"
--   found.txt     the game's normal values (shown in the tab)
-- No settings.txt (or an empty one) = the normal game.
--
-- How: no loops and no hooks. settings.txt is read when the game starts and on every map load (Ramsgate, a hunt).
-- The game tells this script about every new potion and Slayer Flask drink ability (NotifyOnNewObject) and the
-- values are set right there, while the object is being made. So a change you save takes effect on the next map
-- load: your next hunt. Objects that already exist are left alone (looking them up while the game loads or frees
-- them crashed the game and its servers), except the tonics your game carries, updated at the start of a map load.
-- IMPORTANT: in a hunt the buff is applied by the hunt server (also on your PC in solo). Turn on "servers" on the
-- launcher's Mods page, or only your tooltip changes. Servers read the same settings.txt.
-- Log lines start with "[PotionTweaks]" (ue4ss\UE4SS.log, or the Console tab in Ctrl+O).

local PROPS = { 'BaseAmount', 'BaseMinAmount', 'BaseMaxAmount', 'BaseEnrageAmount', 'BaseDuration', 'MaxStackSize', 'NumCharges', 'Magnitude', 'DefaultHealAmount' }
local INT_PROPS = { MaxStackSize = true, NumCharges = true }
-- 1.14.7 names (in game): Frenzy, Blitz, Insight, Assault, Lifedrain, Aetherdrive, Bulwark, Granny's Heartbreaker, Stamina,
-- Slayer Flask (Healing_Flask_00). Values other than PROPS also work: any number in settings.txt that the item has.
local ALL = { 'Damage_EnrageBonus_Potion', 'Attack_Speed_Potion', 'Expose_Potion', 'Stagger_Potion', 'Lifesteal_AoE_Potion',
              'Lantern_Potion', 'Damage_Block_Potion', '11A_Crit_Potion', 'StaminaPotion_00', 'Healing_Flask_00' }

-- this mod's folder (...\Mods\PotionTweaks\), from this script's own path
local MOD_DIR = (function()
    local ok, info = pcall(debug.getinfo, 1, 'S')
    local src = ok and info and info.source or ''
    src = src:gsub('^@', ''):gsub('/', '\\')
    local d = src:match('^(.*\\)Scripts\\[^\\]+$')
    return d or 'ue4ss\\Mods\\PotionTweaks\\'
end)()

-- Which process this is: the launcher gives each server its own home folder (...\versions\<v>\srvhome, srvhome1);
-- the game uses ...\home.
local ROLE = (function()
    local h = (os.getenv('LOCALAPPDATA') or '') .. '\\'
    return h:match('\\(srvhome%d*)\\') or 'client'
end)()
local function log(s) print('[PotionTweaks] ' .. s .. '\n') end
local function get(o, k) local ok, v = pcall(function() return o[k] end); if ok and type(v) == 'number' then return v end; return nil end
local function put(o, k, v) return pcall(function() o[k] = v end) end

local SETTINGS = MOD_DIR .. 'settings.txt'
local FOUND = MOD_DIR .. 'found.txt'

local function write_file(file, lines)
    local tmp = file .. '.tmp'
    local f = io.open(tmp, 'w'); if not f then return end
    f:write(table.concat(lines, '\n') .. '\n'); f:close()
    os.remove(file); os.rename(tmp, file)
end

local function read_values(file)
    local v = {}
    local f = io.open(file, 'r'); if not f then return v end
    for line in f:lines() do
        local k, val = line:match('^%s*([%w_]+%.[%w_]+)%s*=%s*([%-%d%.eE]+)%s*$')
        if k and tonumber(val) then v[k] = tonumber(val) end
    end
    f:close()
    return v
end

-- the game's normal values, for the tab: keep what found.txt already has, add what new potions show
local original = {}   -- original[name][prop]
for k, v in pairs(read_values(FOUND)) do
    local n, p = k:match('^([%w_]+)%.([%w_]+)$')
    if n then original[n] = original[n] or {}; original[n][p] = v end
end
local function write_found()
    local lines = { '# PotionTweaks: the game\'s normal potion values (written by Scripts\\main.lua, read by the Potions tab)' }
    for _, name in ipairs(ALL) do
        if original[name] then
            local keys = {}
            for k in pairs(original[name]) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do lines[#lines + 1] = name .. '.' .. k .. '=' .. string.format('%g', original[name][k]) end
        end
    end
    write_file(FOUND, lines)
end

local function full_name(o) local ok, s = pcall(function() return o:GetFullName() end); return ok and s or nil end
local function class_name(o) local ok, s = pcall(function() return o:GetClass():GetFName():ToString() end); return ok and s or nil end
local function is_default(o) local ok, s = pcall(function() return o:GetFName():ToString() end); return not ok or s:find('^Default__') ~= nil end
-- the default object of a brand-new object's class (loaded and in use, so safe to read and write right now)
local function cdo_of(o) local ok, c = pcall(function() return o:GetClass():GetCDO() end); if ok and c and c:IsValid() then return c end; return nil end

-- settings: read at start and on each map load. Never changed in place, only replaced (read_values makes a new table).
local settings, settings_text = {}, nil
local function load_settings(why)
    local s = read_values(SETTINGS)
    local keys = {}
    for k, v in pairs(s) do keys[#keys + 1] = k .. '=' .. string.format('%g', v) end
    table.sort(keys)
    local text = table.concat(keys, ' ')
    settings = s
    if text == settings_text then return false end
    settings_text = text
    log('settings (' .. why .. '): ' .. (#keys > 0 and text or 'none, normal game'))
    return true
end
load_settings('game start')

-- Bulwark: each blocked hit is one stack of its gameplay effects, and those stop at StackLimitCount (10 in 1.14.7,
-- also the counter top left). Raised to the hits-blocked value when that is higher, put back otherwise. These are
-- default objects of effect classes the Bulwark potion uses, so they are set when a Bulwark potion is made.
local STACK_EFFECTS = { '/Game/game/consumables/damage_block_ge', '/Game/game/consumables/damage_block_icon_ge' }
local stack_normal = {}
local function set_stack_limits()
    for _, path in ipairs(STACK_EFFECTS) do
        local cname = path:match('([^/]+)$')
        local cdo = StaticFindObject(path .. '.Default__' .. cname .. '_C')
        if cdo and cdo:IsValid() then
            local have = get(cdo, 'StackLimitCount')
            if have ~= nil then
                if stack_normal[path] == nil then stack_normal[path] = have end
                local want = stack_normal[path]
                local charges = settings['Damage_Block_Potion.NumCharges']
                if charges and charges > want then want = math.floor(charges + 0.5) end
                if have ~= want then put(cdo, 'StackLimitCount', want) end
            end
        else
            log(cname .. ': not loaded when the Bulwark was made, hits blocked stay at most ' .. (stack_normal[path] or 10))
        end
    end
end

-- A new potion (QuickItem_<name>_C): first note its normal values (it was just copied from the untouched default
-- object), then give it yours. Only the new object is written; the default objects keep the normal values.
local last_text = {}
local function set_new_item(o, name)
    local orig = original[name]
    if not orig then orig = {}; original[name] = orig end
    local added = false
    local function note(p)
        -- only a value not known yet: a potion reported a second time already has yours
        local v = get(o, p)
        if v ~= nil and orig[p] == nil then orig[p] = v; added = true end
        return v
    end
    for _, p in ipairs(PROPS) do note(p) end
    local parts = {}
    for k, v in pairs(settings) do
        local n, p = k:match('^([%w_]+)%.([%w_]+)$')
        if n == name then
            local have = note(p)
            if INT_PROPS[p] then v = math.floor(v + 0.5) end
            if have == nil then parts[#parts + 1] = p .. ' (the game has no such value)'
            else
                if math.abs(have - v) > 1e-6 and not put(o, p, v) then log(name .. ': could not set ' .. p) end
                parts[#parts + 1] = p .. '=' .. string.format('%g', v)
            end
        end
    end
    if added then write_found() end
    table.sort(parts)
    local text = #parts > 0 and table.concat(parts, ' ') or 'normal'
    if last_text[name] ~= text then last_text[name] = text; log(name .. ': ' .. text) end
    if name == 'Damage_Block_Potion' then set_stack_limits() end
end

-- Slayer Flask: the heal (425) is on the flask (DefaultHealAmount, set above) and again on its drink ability
-- ("Heal Amount"). A new ability gets your value plus whatever it holds above its class default (Slayer path upgrades).
local FLASK_KEY, FLASK_PROP, FLASK_CLASS = 'Healing_Flask_00.DefaultHealAmount', 'Heal Amount', 'Ability_QuickItem_Healing_Potion_Flask_C'
local function set_new_ability(o)
    local want = settings[FLASK_KEY]
    if not want then return end
    local h = get(o, FLASK_PROP)
    if not h then return end
    local cdo = cdo_of(o)
    local normal = cdo and get(cdo, FLASK_PROP) or h
    local target = want + math.max(h - normal, 0)
    if math.abs(h - target) > 1e-3 then put(o, FLASK_PROP, target) end
end

local function watch(paths, filter)
    local any = false
    for _, p in ipairs(paths) do
        local c = StaticFindObject(p)
        if c and c:IsValid() then NotifyOnNewObject(p, function(o) pcall(filter, o) end); any = true end
    end
    if not any then log('game class not found (' .. table.concat(paths, ', ') .. '): these values are not applied') end
end

-- Your game (not the servers) makes its tonics once, when your loadout loads, and keeps them across Ramsgate and every
-- hunt; only the hunt server makes new ones per hunt. So the inventory text kept the values of the moment they were
-- made. Your game keeps their path names (never the objects) and updates them when a map loads: the new World is made
-- right after the game has cleaned up the old map (a full clean-up: freed objects are gone from the lookup) and before
-- the new map makes anything, so a lookup then finds only tonics that still exist.
local carried = {}      -- carried[path] = potion name (client only)
local function keep_carried(o, name)
    if ROLE ~= 'client' then return end
    local p = (full_name(o) or ''):match('^%S+%s+(.+)$')
    if p then carried[p] = name end
end
local function update_carried()
    local now = {}
    -- a copy of the names first: a tonic made meanwhile (another thread) adds to 'carried' and would break pairs
    local list = {}
    for p, name in pairs(carried) do list[#list + 1] = { p, name } end
    for _, e in ipairs(list) do
        local p, name = e[1], e[2]
        local o = StaticFindObject(p)
        if o and o:IsValid() then
            now[p] = name
            local orig = original[name] or {}
            -- your value, or the normal one for a value you removed
            for k, normal in pairs(orig) do
                local v = settings[name .. '.' .. k] or normal
                if INT_PROPS[k] then v = math.floor(v + 0.5) end
                local have = get(o, k)
                if have ~= nil and math.abs(have - v) > 1e-6 then put(o, k, v) end
            end
        end
    end
    carried = now
end

local ITEM_CLASSES = {}
for _, n in ipairs(ALL) do ITEM_CLASSES['QuickItem_' .. n .. '_C'] = n end
-- Both classes, because it is not known which one the tonics are made from; a potion reported twice is set twice
-- (harmless: the second time nothing changes).
watch({ '/Script/Archon.ArchonQuickItem', '/Script/Archon.ArchonInventoryItem_QuickItem' }, function(item)
    local name = ITEM_CLASSES[class_name(item) or '']
    if name and not is_default(item) then set_new_item(item, name); keep_carried(item, name) end
end)
watch({ '/Script/GameplayAbilities.GameplayAbility' }, function(ability)
    if class_name(ability) == FLASK_CLASS and not is_default(ability) then set_new_ability(ability) end
end)
-- A map load (a new World): read settings.txt again, before the map makes your potions; update the tonics you carry.
watch({ '/Script/Engine.World' }, function()
    -- only when you saved a change since the last map: else your tonics already have these values
    if not load_settings('map load') then return end
    local ok, err = pcall(update_carried)
    if not ok then log('tonics you carry: error ' .. tostring(err)) end
end)

log('loaded, settings file: ' .. SETTINGS)
