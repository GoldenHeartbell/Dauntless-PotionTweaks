-- PotionTweaks (UE4SS 3.0.1 mod for Dauntless 1.14.7, Dauntless Forever Modded mode) - by GoldenHeartbell
-- Changes potion (tonic) strength / duration / stack size by editing the potion item's default values
--
-- Two parts, one mod folder:
--   dlls\main.dll     the "Potions" tab in the UE4SS window (Ctrl+O in game); it only writes settings.txt
--   Scripts\main.lua  this file: reads settings.txt every 3 s and puts the values into the game
-- Files in the mod folder:
--   settings.txt  your values, one "Potion.Property=value" per line, e.g. "Damage_Block_Potion.NumCharges=5"
--   found.txt     the game's normal values (shown in the tab)
-- No settings.txt (or an empty one) = the normal game. Values that are removed go back to normal.
--
-- 1.14.7 loads the potion classes only when it needs them (your loadout, a hunt); each one is changed within 3 s of
-- being loaded.
-- IMPORTANT: in a hunt the buff is applied by the hunt server (also on your PC in solo). Turn on "servers" on the
-- launcher's Mods page, or only your tooltip changes. Servers read the same settings.txt.
-- Log lines start with "[PotionTweaks]" (ue4ss\UE4SS.log, or the Console tab in Ctrl+O).

local PROPS = { 'BaseAmount', 'BaseMinAmount', 'BaseMaxAmount', 'BaseEnrageAmount', 'BaseDuration', 'MaxStackSize', 'NumCharges', 'Magnitude', 'DefaultHealAmount' }
local INT_PROPS = { MaxStackSize = true, NumCharges = true }
-- 1.14.7 names (in game): Frenzy, Blitz, Insight, Assault, Lifedrain, Aetherdrive, Bulwark, Granny's Heartbreaker, Stamina,
-- Slayer Flask (Healing_Flask_00). Values other than PROPS also work: any number in settings.txt that the item has.
local ALL = { 'Damage_EnrageBonus_Potion', 'Attack_Speed_Potion', 'Expose_Potion', 'Stagger_Potion', 'Lifesteal_AoE_Potion',
              'Lantern_Potion', 'Damage_Block_Potion', '11A_Crit_Potion', 'StaminaPotion_00', 'Healing_Flask_00' }
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

-- Bulwark: each blocked hit is one stack of its gameplay effects, and those stop at StackLimitCount (10 in 1.14.7,
-- also the counter top left). Raise the limit to the hits-blocked value when that is higher; put it back otherwise.
local STACK_EFFECTS = { { 'Damage_Block_Potion', 'NumCharges', '/Game/game/consumables/damage_block_ge' },
                        { 'Damage_Block_Potion', 'NumCharges', '/Game/game/consumables/damage_block_icon_ge' } }
local stack_normal = {}
-- Slayer Flask: the heal (425) is on the flask (DefaultHealAmount; its HealBonuses list holds the Slayer's path upgrades,
-- +10% and +15%) and again on its drink ability ("Heal Amount"). The default objects get your value. A live ability that holds
-- more than its default keeps that extra on top of your value; the game writing a new value there is picked up again.
local LINKS = {
    { key = 'Healing_Flask_00.DefaultHealAmount', prop = 'Heal Amount', class = 'Ability_QuickItem_Healing_Potion_Flask_C',
      path = '/Game/Blueprints/InventoryItems/Abilities/Ability_QuickItem_Healing_Potion_Flask.Default__Ability_QuickItem_Healing_Potion_Flask_C' },
}
local link_orig, link_last, link_extra, link_wrote = {}, {}, {}, {}
local function patch_links(settings)
    for _, l in ipairs(LINKS) do
        local cdo = StaticFindObject(l.path)
        if cdo and cdo:IsValid() then
            if link_orig[l.key] == nil then
                link_orig[l.key] = get(cdo, l.prop)
                if link_orig[l.key] then log(l.class .. ' normal: ' .. l.prop .. '=' .. string.format('%g', link_orig[l.key])) end
            end
            local orig = link_orig[l.key]
            local want = settings[l.key] or orig
            if want and orig then
                -- a live copy starts as a copy of the default as it was before this tick ('have'), so its own extra
                -- (e.g. upgrades) is measured against that, not against 425 (else a copy made after the default was
                -- patched counted the change twice: 1143 became 1861)
                local have = get(cdo, l.prop) or orig
                if math.abs(have - want) > 1e-6 then put(cdo, l.prop, want) end
                local live = FindAllOf(l.class)
                if live then for _, o in ipairs(live) do
                    local fn = o:IsValid() and full_name(o)
                    if fn and not fn:find('Default__', 1, true) then
                        local h = get(o, l.prop)
                        if h then
                            if link_extra[fn] == nil or (link_wrote[fn] and math.abs(h - link_wrote[fn]) > 1e-3) then link_extra[fn] = h - have end
                            local target = want + link_extra[fn]
                            if math.abs(h - target) > 1e-3 then put(o, l.prop, target) end
                            link_wrote[fn] = target
                        end
                    end
                end end
                local text = string.format('%g', want)
                if link_last[l.key] ~= text then link_last[l.key] = text; log('Slayer Flask heal now: ' .. text) end
            end
        end
    end
end
local function patch_stack_limits(settings)   -- settings passed in: the file-level 'settings' is declared further down
    for _, e in ipairs(STACK_EFFECTS) do
        local name, prop, path = e[1], e[2], e[3]
        local cname = path:match('([^/]+)$')
        local cdo = StaticFindObject(path .. '.Default__' .. cname .. '_C')
        if cdo and cdo:IsValid() then
            local have = get(cdo, 'StackLimitCount')
            if have ~= nil then
                if stack_normal[path] == nil then stack_normal[path] = have; log(cname .. ' normal: StackLimitCount=' .. have) end
                local want = stack_normal[path]
                local charges = settings[name .. '.' .. prop]
                if charges and charges > want then want = math.floor(charges + 0.5) end
                if have ~= want and put(cdo, 'StackLimitCount', want) then log(cname .. ' now: StackLimitCount=' .. want) end
            end
        end
    end
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
        log(name .. ' normal: ' .. (#parts > 0 and table.concat(parts, ' ') or '(none of the known values)'))
        write_found()
    end
    -- any other value set for this item in settings.txt: remember its normal value too
    local added = false
    for k in pairs(settings) do
        local n, p = k:match('^([%w_]+)%.([%w_]+)$')
        if n == name and original[name][p] == nil then
            local v = get(cdo, p)
            if v ~= nil then original[name][p] = v; added = true; log(name .. ' normal: ' .. p .. '=' .. string.format('%g', v)) end
        end
    end
    if added then write_found() end
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
    local okl, errl = pcall(patch_links, settings)
    if not okl and last_text['link!'] ~= tostring(errl) then last_text['link!'] = tostring(errl); log('flask heal: error ' .. tostring(errl)) end
    local okp, errp = pcall(patch_stack_limits, settings)
    if not okp and last_text['stack!'] ~= tostring(errp) then last_text['stack!'] = tostring(errp); log('stack limit: error ' .. tostring(errp)) end
    -- after ~30 s, say which potions are not loaded yet (then every 5 minutes); they load with your loadout or a hunt
    if #missing > 0 and (ticks == 10 or ticks % 100 == 0) then log('not loaded yet (open your loadout or start a hunt): ' .. table.concat(missing, ', '))
    elseif #missing == 0 and not reported then reported = true; log('all potions found') end
    return false
end)

-- 100% mode ("100%" in the tab, saved as value 999). The game divides by (1 + value), so it never reaches 0 by itself:
--   Stamina Tonic: stamina use / (1 + BaseAmount)        -> while active: stamina use 0 and stamina kept full
--   Bulwark:       damage taken / (1 + Magnitude)        -> while active: damage-taken multiplier 0 (no damage)
-- "Active" = the value is far below normal (1/1000 then, or already forced to 0); other effects never go this low.
-- Runs in your game and in your hunt server (both have this mod).
local FULL = 999
local full_modes = {
    { key = 'StaminaPotion_00.BaseAmount', name = 'stamina', what = 'no stamina used while the Stamina Tonic is active',
      apply = function(s)
          local use = get(s, 'StaminaConsumption')
          if use ~= nil and use < 0.01 then
              if use ~= 0 then put(s, 'StaminaConsumption', 0) end
              local maxs, cur = get(s, 'MaxStamina'), get(s, 'Stamina')
              if maxs and cur and cur < maxs then put(s, 'Stamina', maxs) end
          end
      end },
    { key = 'Damage_Block_Potion.Magnitude', name = 'bulwark', what = 'no damage taken while the Bulwark is active',
      apply = function(s)
          local m = get(s, 'GlobalSelfPostMigationMultiplier')
          if m ~= nil and m < 0.01 and m ~= 0 then put(s, 'GlobalSelfPostMigationMultiplier', 0) end
      end },
}
local full_on, full_sets, full_scan = {}, {}, 0
LoopAsync(250, function()
    pcall(function()
        local any = false
        for _, fm in ipairs(full_modes) do
            local v = settings[fm.key]
            local on = v ~= nil and v >= FULL
            if on ~= (full_on[fm.name] or false) then full_on[fm.name] = on; log(fm.name .. ': 100% mode ' .. (on and ('on (' .. fm.what .. ')') or 'off')) end
            any = any or on
        end
        if not any then return end
        local now = os.clock()
        if now >= full_scan then   -- the players' health attribute sets, found again every 5 s
            full_scan = now + 5
            full_sets = {}
            local all = FindAllOf('ArchonHealthAttributeSet')
            if all then for _, s in ipairs(all) do
                local fn = full_name(s) or ''
                if s:IsValid() and fn:match('PlayerCharacter') and not fn:match('Default__') then full_sets[#full_sets + 1] = s end
            end end
        end
        for _, s in ipairs(full_sets) do
            if s:IsValid() then
                for _, fm in ipairs(full_modes) do if full_on[fm.name] then pcall(fm.apply, s) end end
            end
        end
    end)
    return false
end)
