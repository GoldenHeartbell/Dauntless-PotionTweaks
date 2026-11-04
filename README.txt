PotionTweaks 1.0 - change tonic strength, duration and stack size in Dauntless 1.14.7
by GoldenHeartbell

WHAT IT DOES
  Adds a "Potions" tab to the UE4SS window. Pick a tonic, move the sliders, press Save.
  You can change, for example:
    Bulwark Tonic   hits blocked (normal 3), damage blocked (normal 45%), max carried (normal 3)
    Blitz Tonic     attack speed, duration (normal 60 s), max carried (normal 5)
    Frenzy, Insight, Assault, Lifedrain, Aetherdrive, Stamina Tonic and Granny's Heartbreaker
  Your tonic upgrades still add on top of these values.

WHAT YOU NEED
  - Dauntless 1.14.7 (for example through the Dauntless Forever launcher)
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
     your loadout. A tonic you already drank keeps its old values; the next one uses the new ones.
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
  props.txt     every number the game has on each tonic (for the curious / for bug reports)

LICENCES
  See LICENSES.txt (Dear ImGui and RE-UE4SS, both MIT).
