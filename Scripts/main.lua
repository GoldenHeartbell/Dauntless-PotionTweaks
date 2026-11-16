-- PotionTweaks (UE4SS 4.0.0 mod for Dauntless 1.14.7, Dauntless Forever Modded mode) - by GoldenHeartbell
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

-- Which process this is. 1.14.7 or 1.6.2.
local ROLE = (function()
    local h = (os.getenv('LOCALAPPDATA') or '') .. '\\'
    local home = h:match('\\(srvhome%d*)\\')
    if home then return home end
    if os.getenv('GAMESERVER_BINARY_PATH') then return 'server162' end
    return 'client'
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
-- also the counter top left). Raised to the hits-blocked value when that is higher. These are default objects of
-- effect classes the Bulwark potion uses, found by name, which is only safe the first time the class is loaded:
-- once the game has unloaded it (Ramsgate after its players left, your game on every map switch), a lookup can find
-- the half-freed old one, and that crashed the Ramsgate server when a player came back from a hunt. So only a hunt
-- server does it (that is where hits are counted, and it runs one hunt), once, when the first Bulwark is made.
local STACK_EFFECTS = { '/Game/game/consumables/damage_block_ge', '/Game/game/consumables/damage_block_icon_ge' }
local HUNT_SERVER = ROLE ~= 'client' and ROLE ~= 'srvhome'   -- srvhome = the Ramsgate server, srvhome1 = the hunt
local CITY_ROLE = ROLE == 'srvhome'
local in_city = ROLE ~= 'client'
local function note_map(world)
    local n = (full_name(world) or ''):lower()
    local city
    if n:find('/maps/ramsgate/', 1, true) or n:find('/maps/islands/dojo/', 1, true) then city = true
    elseif n:find('/maps/islands/', 1, true) then city = false
    else return end   -- not a map (editor/preview worlds) or a part of a map from elsewhere: no change
    if city ~= in_city then
        in_city = city
        log((n:match('([^/%.]+)$') or n) .. ': ' .. (city and 'Ramsgate/Training Grounds, the mod does nothing here' or 'hunt, values are applied'))
    end
end

local stack_done = false
local function set_stack_limits()
    if not HUNT_SERVER or stack_done or in_city then return end
    stack_done = true
    local charges = settings['Damage_Block_Potion.NumCharges']
    if not charges then return end
    for _, path in ipairs(STACK_EFFECTS) do
        local cname = path:match('([^/]+)$')
        local cdo = StaticFindObject(path .. '.Default__' .. cname .. '_C')
        if cdo and cdo:IsValid() then
            local have = get(cdo, 'StackLimitCount')
            local want = math.floor(charges + 0.5)
            if have ~= nil and want > have then put(cdo, 'StackLimitCount', want) end
        else
            log(cname .. ': not loaded when the Bulwark was made, hits blocked count up to 10')
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
-- made.
local carried = {}      -- carried[path] = potion name (client only)
local function keep_carried(o, name)
    if ROLE ~= 'client' then return end
    local p = (full_name(o) or ''):match('^%S+%s+(.+)$')
    if p then carried[p] = name end
end
local function update_carried()
    -- UE4SS 4: new-object callbacks run on the game thread too, so nothing adds to 'carried' during this loop
    local now = {}
    for p, name in pairs(carried) do
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

if CITY_ROLE then
    log('loaded (' .. ROLE .. '): Ramsgate server, the mod does nothing here')
    return
end

local ITEM_CLASSES = {}
for _, n in ipairs(ALL) do ITEM_CLASSES['QuickItem_' .. n .. '_C'] = n end
watch({ '/Script/Archon.ArchonInventoryItem_QuickItem' }, function(item)
    if in_city then return end
    local name = ITEM_CLASSES[class_name(item) or '']
    if name and not is_default(item) then set_new_item(item, name); keep_carried(item, name) end
end)
watch({ '/Script/Archon.ArchonQuickItem' }, function(ability)
    if in_city then return end
    if class_name(ability) == FLASK_CLASS and not is_default(ability) then set_new_ability(ability) end
end)
-- Map loads: only through UE4SS's LoadMap hook.
--  - pre-hook: before the new map makes anything. settings.txt is read again.
--  - post-hook: the map has fully loaded and the old one is cleaned up. Servers note which map it is (Ramsgate/Training
--    Grounds or a hunt), your game updates the tonics it carries. Players join a hunt after its map has loaded, so the
--    hunt's potions are made after this. Until the first post-hook a server counts as "in town" and changes nothing.
local UE4SS_DIR = MOD_DIR:gsub('[^\\]+\\[^\\]+\\$', '')   -- ...\ue4ss\ (MOD_DIR is ...\ue4ss\Mods\PotionTweaks\)
local function dauntless_vtable_layout()
    local f = io.open(UE4SS_DIR .. 'VTableLayout.ini', 'r'); if not f then return false end
    local text = f:read('*a') or ''; f:close()
    return text:find('DauntlessExtraVirtual', 1, true) ~= nil
end

local carried_dirty = false    -- settings changed in the pre-hook: update the tonics you carry in the post-hook

local function on_map_start()
    local ok, changed = pcall(load_settings, 'map load')
    if ok and changed then carried_dirty = true end
end

local function on_map_loaded(world)
    if ROLE ~= 'client' then
        local ok, w = pcall(function() return world:get() end)
        if ok and w and w:IsValid() then pcall(note_map, w) end
    end
    if carried_dirty then
        carried_dirty = false
        local ok, err = pcall(update_carried)
        if not ok then log('tonics you carry: error ' .. tostring(err)) end
    end
end

if EngineTickAvailable == nil then
    log('map loads: not seen (needs UE4SS 4; this is UE4SS 3.0.1). Settings are read at game start only' .. (ROLE ~= 'client' and ', and this server changes nothing' or ''))
elseif not dauntless_vtable_layout() then
    log('map loads: not seen (ue4ss\\VTableLayout.ini from Dauntless Forever is missing). Settings are read at game start only' .. (ROLE ~= 'client' and ', and this server changes nothing' or ''))
else
    local pre_ok, pre_err = pcall(RegisterLoadMapPreHook, function() on_map_start() end)
    local post_ok, post_err = pcall(RegisterLoadMapPostHook, function(engine, world) on_map_loaded(world) end)
    if pre_ok and post_ok then log('map loads: LoadMap hook')
    else log('map loads: LoadMap hook could not be added (' .. tostring(pre_err or post_err) .. ')') end
end

log('loaded (' .. ROLE .. '), settings file: ' .. SETTINGS)
