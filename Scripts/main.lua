-- PotionTweaks (UE4SS 3.0.1 mod for Dauntless 1.14.7, Dauntless Forever Modded mode)
-- Changes potion (tonic) strength / duration / stack size by editing the potion item's default values
-- (/Game/Blueprints/InventoryItems/QuickItems/QuickItem_*, names checked against the 1.14.7 pak index). The game reads
-- these when you drink a potion, so the buff, its timer and the tooltip follow.
--
-- Two parts, one mod folder:
--   dlls\main.dll     the "Potions" tab in the UE4SS window (Ctrl+O in game); it only writes settings.txt
--   Scripts\main.lua  this file: reads settings.txt every 3 s and puts the values into the game
-- Files in the mod folder:
--   settings.txt  your values, one "Potion.Property=value" per line, e.g. "Damage_Block_Potion.NumCharges=5"
--   found.txt     the game's normal values (shown in the tab)
--   props.txt     every number on each potion, as the game has it (to find out what a 1.14.7 potion can change)
-- No settings.txt (or an empty one) = the normal game. Values that are removed go back to normal.
--
-- 1.14.7 loads the potion classes only when it needs them (your loadout, a hunt); each one is changed within 3 s of
-- being loaded.
-- IMPORTANT: in a hunt the buff is applied by the hunt server (also on your PC in solo). Turn on "servers" on the
-- launcher's Mods page, or only your tooltip changes. Servers read the same settings.txt.
-- Log lines start with "[PotionTweaks]" (ue4ss\UE4SS.log, or the Console tab in Ctrl+O).

local PROPS = { 'BaseAmount', 'BaseMinAmount', 'BaseMaxAmount', 'BaseEnrageAmount', 'BaseDuration', 'MaxStackSize', 'NumCharges', 'Magnitude' }
local INT_PROPS = { MaxStackSize = true, NumCharges = true }
-- 1.14.7 names (in game): Frenzy, Blitz, Insight, Assault, Lifedrain, Aetherdrive, Bulwark, Granny's Heartbreaker, Stamina
local ALL = { 'Damage_EnrageBonus_Potion', 'Attack_Speed_Potion', 'Expose_Potion', 'Stagger_Potion', 'Lifesteal_AoE_Potion',
              'Lantern_Potion', 'Damage_Block_Potion', '11A_Crit_Potion', 'StaminaPotion_00' }
local DIR = '/Game/Blueprints/InventoryItems/QuickItems/'

local function log(s) print('[PotionTweaks] ' .. s .. '\n') end
local function get(o, k) local ok, v = pcall(function() return o[k] end); if ok and type(v) == 'number' then return v end; return nil end
local function put(o, k, v) return pcall(function() o[k] = v end) end
local function str(x) local ok, s = pcall(function() return x:ToString() end); return ok and s or '?' end

-- this mod's folder (...\Mods\PotionTweaks\), from this script's own path
local MOD_DIR = (function()
    local ok, info = pcall(debug.getinfo, 1, 'S')
    local src = ok and info and info.source or ''
    src = src:gsub('^@', ''):gsub('/', '\\')
    local d = src:match('^(.*\\)Scripts\\[^\\]+$')
    return d or 'ue4ss\\Mods\\PotionTweaks\\'
end)()
local SETTINGS = MOD_DIR .. 'settings.txt'
local FOUND = MOD_DIR .. 'found.txt'
local PROPS_FILE = MOD_DIR .. 'props.txt'

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

local original = {}   -- original[name][prop] = the game's normal value (read once from the untouched default object)
local function write_found()
    local lines = { '# PotionTweaks: the game\'s normal potion values (written by Scripts\\main.lua, read by the Potions tab)' }
    for _, name in ipairs(ALL) do
        if original[name] then for _, k in ipairs(PROPS) do
            if original[name][k] then lines[#lines + 1] = name .. '.' .. k .. '=' .. string.format('%g', original[name][k]) end
        end end
    end
    write_file(FOUND, lines)
end

-- every number property on the potion and its parent classes, so we can see what 1.14.7 really has
local props_lines = { '# PotionTweaks: all number values on each potion as the game has them (Potion.Property=value  [type, class])' }
local function dump_props(cdo, name)
    pcall(function()
        local cls, depth = cdo:GetClass(), 0
        while cls and cls:IsValid() and depth < 10 do
            local cname = str(cls:GetFName())
            if cname == 'Object' then break end
            cls:ForEachProperty(function(p)
                local pname, ptype = str(p:GetFName()), str(p:GetClass():GetFName())
                local v = get(cdo, pname)
                if v ~= nil then props_lines[#props_lines + 1] = string.format('%s.%s=%g  [%s, %s]', name, pname, v, ptype, cname)
                else props_lines[#props_lines + 1] = string.format('# %s.%s  [%s, %s]', name, pname, ptype, cname) end
            end)
            cls, depth = cls:GetSuperStruct(), depth + 1
        end
    end)
    write_file(PROPS_FILE, props_lines)
end

local settings, last_text = {}, {}
local function target(name, k)
    local v = settings[name .. '.' .. k]
    if v == nil then v = original[name][k] end
    if v ~= nil and INT_PROPS[k] then v = math.floor(v + 0.5) end
    return v
end

local function apply(o, name)
    for k in pairs(original[name]) do
        local want, have = target(name, k), get(o, k)
        if want ~= nil and have ~= nil and math.abs(have - want) > 1e-6 then
            if not put(o, k, want) then log(name .. ': could not set ' .. k) end
        end
    end
end

local function find_cdo(name)
    local cdo = StaticFindObject(DIR .. 'QuickItem_' .. name .. '.Default__QuickItem_' .. name .. '_C')
    if cdo and cdo:IsValid() then return cdo end
    return nil
end

local function patch(name)
    local cdo = find_cdo(name)
    if not cdo then return false end
    if not original[name] then
        original[name] = {}
        local parts = {}
        for _, k in ipairs(PROPS) do local v = get(cdo, k); if v then original[name][k] = v; parts[#parts + 1] = k .. '=' .. string.format('%g', v) end end
        log(name .. ' normal: ' .. (#parts > 0 and table.concat(parts, ' ') or '(none of the known values, see props.txt)'))
        write_found()
        dump_props(cdo, name)
    end
    apply(cdo, name)
    local live = FindAllOf('QuickItem_' .. name .. '_C')
    if live then for _, o in ipairs(live) do if o:IsValid() then apply(o, name) end end end
    -- log what is in use whenever it changes
    local parts = {}
    for k, s in pairs(settings) do
        local n, p = k:match('^([%w_]+)%.([%w_]+)$')
        if n == name then parts[#parts + 1] = p .. '=' .. string.format('%g', s) .. (original[name][p] and '' or ' (the game has no such value)') end
    end
    table.sort(parts)
    local text = #parts > 0 and table.concat(parts, ' ') or 'normal'
    if last_text[name] ~= text then last_text[name] = text; log(name .. ' now: ' .. text) end
    return true
end

log('loaded, settings file: ' .. SETTINGS)
local ticks, reported = 0, false
-- Check every few seconds; cheap and idempotent (the classes can also be reloaded per map). This runs right here in
-- the LoopAsync thread on purpose: ExecuteInGameThread needs UE4SS's ProcessEvent hook, which UE4SS 3.0.1 does not
-- find in Dauntless 1.14.7, so its callbacks never run (that is why the first version never changed anything).
-- Writing a number into a potion's default object is safe from here.
LoopAsync(3000, function()
    settings = read_values(SETTINGS)
    ticks = ticks + 1
    local missing = {}
    for _, name in ipairs(ALL) do
        local ok, done = pcall(patch, name)
        if not ok and last_text[name .. '!'] ~= tostring(done) then last_text[name .. '!'] = tostring(done); log(name .. ': error ' .. tostring(done)) end
        if not (ok and done) then missing[#missing + 1] = name end
    end
    -- after ~30 s, say which potions are not loaded yet (then every 5 minutes); they load with your loadout or a hunt
    if #missing > 0 and (ticks == 10 or ticks % 100 == 0) then log('not loaded yet (open your loadout or start a hunt): ' .. table.concat(missing, ', '))
    elseif #missing == 0 and not reported then reported = true; log('all potions found') end
    return false
end)
