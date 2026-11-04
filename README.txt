PotionTweaks 1.1 - change tonic strength, duration and stack size and the Slayer Flask heal in Dauntless 1.14.7
by GoldenHeartbell

WHAT IT DOES
  Adds a "Potions" tab to the UE4SS window. Pick a tonic, move the sliders, press Save.
  You can change, for example:
    Bulwark Tonic   hits blocked (normal 3), less damage taken (normal 31%; at 100% the blocked hits do no damage),
                    max carried (normal 3)
    Blitz Tonic     attack speed, duration (normal 60 s), max carried (normal 5)
    Stamina Tonic   less stamina used (normal 33%; stamina regen goes up by the same factor), duration.
                    At 100% no stamina is used at all while the tonic lasts.
    Slayer Flask    heal amount (normal 425 HP), max carried
    Frenzy, Insight, Assault, Lifedrain, Aetherdrive and Granny's Heartbreaker
  Your tonic upgrades (and the flask upgrades from the Slayer's path) still add on top of these values.

WHAT YOU NEED
  - Dauntless 1.14.7
  - UE4SS v3.0.1 installed in the game (Dauntless Forever "Modded" mode puts it in
    Archon\Binaries\Win64\ue4ss). Other UE4SS versions will not load the Potions tab.

INSTALL
  1. Close the game.
  2. Copy this whole PotionTweaks folder into
       <game folder>\Archon\Binaries\Win64\ue4ss\Mods\
     so you get ...\ue4ss\Mods\PotionTweaks\dlls\main.dll and ...\Mods\PotionTweaks\Scripts\main.lua
  3. That is all: the enabled.txt file turns the mod on. (Or add the line "PotionTweaks : 1" to Mods\mods.txt,
     above the Keybinds line.)

USE
  1. Start the game and open your loadout (the game only loads the tonics you have equipped).
  2. Press Ctrl+O, open the "Potions" tab, change values, press Save.
  3. The game uses the new values within 3 seconds. If the tooltip still shows the old numbers, close and reopen
     your loadout. A tonic you already drank keeps its old values, the next one uses the new ones.
  Back to normal: "Normal values for all" + Save, or delete settings.txt in the mod folder.

HUNTS
  In a hunt the buff is applied by the hunt server, not by your game. In the Dauntless Forever launcher, turn on
  "servers" on the Mods page so your hunt server runs this mod too (it reads the same settings.txt). In someone
  else's hunt their server decides, so your values only count in hunts you host.

IS IT WORKING?
  Open the Console tab in the UE4SS window (Ctrl+O), or ue4ss\UE4SS.log, and look for lines starting with
  [PotionTweaks]:
    Damage_Block_Potion normal: MaxStackSize=3 NumCharges=3 Magnitude=0.45     (the tonic was found)
    Damage_Block_Potion now: NumCharges=10                                       (your values are in use)
    not loaded yet (open your loadout or start a hunt): ...                      (put the tonic in your loadout)
  Note: your game and your hunt server write to the same UE4SS.log, so the one started last overwrites it.

FILES THE MOD WRITES (in this folder)
  settings.txt  your values ("Potion.Property=value" per line)
  found.txt     the game's normal values, shown in the tab

CHANGES
  1.1  Slayer Flask heal amount (Slayer's path upgrades still add on top). Bulwark at 100%: no damage while it is
       active. Hits blocked above 10 now really count. Stamina Tonic at 100%: no stamina used. Testing tools removed.
  1.0  First version.

LICENCES
  PotionTweaks: GNU AGPL-3.0, see LICENSE.
  See LICENSES.txt for Dear ImGui and RE-UE4SS (both MIT).
  Source and releases: https://github.com/GoldenHeartbell/PotionTweaks
