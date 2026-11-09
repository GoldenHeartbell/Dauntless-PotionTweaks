# Dauntless PotionTweaks

Change tonic strength, duration and stack size, and the Slayer Flask heal, in **Dauntless 1.14.7 and 1.6.2**.

By GoldenHeartbell. Version 1.2. [Download the latest release](https://github.com/GoldenHeartbell/Dauntless-PotionTweaks/releases/latest)

## What it does

Adds a **Potions** tab to the UE4SS window. Pick a tonic, move the sliders, press **Save**.

| Item | What you can change |
| --- | --- |
| Bulwark Tonic | Hits blocked (normal 3), less damage taken (normal 31%; at 100% the blocked hits do no damage), max carried (normal 3) |
| Blitz Tonic | Attack speed, duration (normal 60 s), max carried (normal 5) |
| Stamina Tonic | Less stamina used (normal 33%; stamina regen goes up by the same factor), duration. At 100% no stamina is used at all while the tonic lasts |
| Slayer Flask | Heal amount (normal 425 HP), max carried |
| Frenzy Tonic | Damage bonus, damage vs enraged, duration, max carried |
| Insight, Assault, Aetherdrive Tonic | Strength, duration, max carried |
| Lifedrain Tonic | Lifesteal, duration, max carried |
| Granny's Heartbreaker | Max carried |

Your tonic upgrades (and the flask upgrades from the Slayer's path) still add on top of these values.

## What you need

- Dauntless 1.14.7 or 1.6.2 (the same mod folder works in both)
- UE4SS **v3.0.1** installed in the game. Dauntless Forever "Modded" mode puts it in `Archon\Binaries\Win64\ue4ss`.
  Other UE4SS versions will not load the Potions tab.

## Install

1. Close the game.
2. Copy the whole `PotionTweaks` folder into `<game folder>\Archon\Binaries\Win64\ue4ss\Mods\`,
   so you get `...\Mods\PotionTweaks\dlls\main.dll` and `...\Mods\PotionTweaks\Scripts\main.lua`.
3. That is all: the `enabled.txt` file turns the mod on. (Or add the line `PotionTweaks : 1` to `Mods\mods.txt`,
   above the `Keybinds` line.)

**Updating:** copy the new folder over the old one and overwrite its files. Your `settings.txt` stays.

## Use

1. Start the game and open your loadout (the game only loads the tonics you have equipped).
2. Press **Ctrl+O**, open the **Potions** tab, change values, press **Save**.
3. The game uses the new values within 3 seconds. If the tooltip still shows the old numbers, close and reopen your
   loadout. A tonic you already drank keeps its old values; the next one uses the new ones.

**Back to normal:** "Normal values for all" + Save, or delete `settings.txt` in the mod folder.

## Hunts

In a hunt the buff is applied by the hunt server, not by your game. In the Dauntless Forever launcher, turn on
**Also run mods on my servers** on the Mods page so your hunt server runs this mod too (it reads the same `settings.txt`).

In someone else's hunt their server decides, so your values only count in hunts you host.

## Is it working?

Open the Console tab in the UE4SS window (Ctrl+O), or `ue4ss\UE4SS.log`, and look for lines starting with
`[PotionTweaks]`:

| Log line | Meaning |
| --- | --- |
| `Damage_Block_Potion normal: MaxStackSize=3 NumCharges=3 Magnitude=0.45` | The tonic was found |
| `Damage_Block_Potion now: NumCharges=10` | Your values are in use |
| `not loaded yet (open your loadout or start a hunt): ...` | Put the tonic in your loadout |

> Your game and your hunt server write to the same `UE4SS.log`, so the one started last overwrites it.

## The game crashes sometimes

Close the game, open `<game folder>\Archon\Binaries\Win64\ue4ss\UE4SS-settings.ini` and change

```
bUseUObjectArrayCache = true
```

to

```
bUseUObjectArrayCache = false
```

This UE4SS cache can crash Dauntless when a mod looks up game objects while the game is loading or freeing them.
The crash report then says `EXCEPTION_ACCESS_VIOLATION` with `UE4SS` at the top of the call stack.

## Files the mod writes

These are in the mod folder:

| File | What it holds |
| --- | --- |
| `settings.txt` | Your values, one `Potion.Property=value` per line |
| `found.txt` | The game's normal values, shown in the tab |

## Changes

### 1.2

- Fixed the game crashing now and then, and menus being slow to close: the mod no longer searches all game objects.
- Recommended: `bUseUObjectArrayCache = false` (see "The game crashes sometimes").
- At 100% (Stamina Tonic, Bulwark), the effect starts right away when you drink, also at the start of a hunt.

### 1.1

- Slayer Flask heal amount (Slayer's path upgrades still add on top).
- Bulwark at 100%: no damage while it is active.
- Bulwark hits blocked above 10 now really count.
- Stamina Tonic at 100%: no stamina used.
- Testing tools removed.

### 1.0

- First version.

## Licence

- PotionTweaks: GNU AGPL-3.0, see [LICENSE](LICENSE).
- Dear ImGui and RE-UE4SS (both MIT): see [LICENSES.txt](LICENSES.txt).
- Source and releases: <https://github.com/GoldenHeartbell/Dauntless-PotionTweaks>
