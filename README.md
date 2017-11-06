# Satan's Fun Pack
A collection of useful commands for TF2 Servers.  
### Table of Contents
[Core File (satansfunpack.smx)](#corefile)  
[Admin Tools (sfp_admintools.smx)](#admintools)  
[Help Menu (sfp_helpmenu.smx)](#helpmenu)  
[Info Utilities (sfp_infoutils.smx)](#infoutils)  
[Quick Conditions (sfp_quickconditions.smx)](#quickconds)  
[Targeting Filters (sfp_targeting.smx)](#targeting)  
[Toybox (sfp_toybox.smx](#toybox)  
[Mirror Damage (sfp_mirror.smx)](#mirror)  
[Trails (sfp_trails.smx)](#trails)  
[Ban Database (sfp_bans.smx)](#bans)  
[Admin Chat Vision (sfp_chatvision.smx)](#chatvision)  
[Dueling (sfp_duel.smx)](#duel)  
[God Mode (sfp_godmode.smx)](#godmode)  
[Group Manager (sfp_groupmanager.smx)](#groupmanager)  

<br/>

<a name="corefile"/>
## Core File (satansfunpack.smx)
ConVar                      |Description                          |Default
----------------------------|-------------------------------------|---
**satansfunpack_version**   |Plugin Version                       |--
**sm_satansfunpack_update** |Should Satan's Fun Pack Auto-Update  |`1`
**sm_satansfunpack_config** |General Config File                  |`satansfunpack.cfg`
General Config Structure:
```
"SFPCustomSlap"
{
  // Leave blank to disable. Max Length 256
  // Path is relative to tf2/sound/. (Same paths used for sm_play)
  "sound"   ""
  "msg"     ""
}

"SFPTaunts"
{
  // Keys and values are case-sensitive. Taunt names are not.
  "Yeti Punch"
  {
    "class" "ANY" // Also: SCOUT, SOLDIER, PYRO, DEMO, HEAVY, ENGIE, MEDIC, SNIPER, SPY
    "id"    "1182"
  }
}
```

Command               |Description                                        |Syntax
----------------------|---------------------------------------------------|---
**sm_sfpplugincheck** |Get install status of all Satan's Fun Pack plugins |`sm_sfpplugincheck`

<br/>

<a name="admintools"/>
## Admin Tools (sfp_admintools.smx)
ConVar                          |Description                            |Default
--------------------------------|---------------------------------------|---
**sm_admintools_disabledcmds**  |List of commands to completely disable |`""`
**sm_maxtempban**               |Maximum time for sm_tban (minutes)     |`180`

<br/>

Command        |Description                            |Syntax
---------------|---------------------------------------|---
**sm_ccom**    |Force a player to use a command        |`sm_ccom <Target> <Command>`
**sm_tban**    |Ban players, with a limit on duration  |`sm_tban <Target> <Duration [Reason]`
**sm_addcond** |Add a condition to a player          |`sm_addcond [Target] <Condition> <Duration>`
**sm_remcond** |Remove a condition from a player       |`sm_remcond [Target] <Condition>`
**sm_removecond** |*Alias for sm_remcond*              |--
**sm_disarm**  |Strip weapons from a player            |`sm_disarm <Target>`
**sm_switchteam** |Force player to switch teams        |`sm_switchteam <Target> [Red/Blu/Spec]`
**sm_forcespec** |Force player into spectator          |`sm_forcespec <Target>`
**sm_fsay**    |Make a player say something            |`sm_fsay <Target> <Message>`
**sm_fsayteam** |Make a player say something           |`sm_fsayteam <Target> <Message>`
**sm_namelock** |Prevent a player from changing names  |`sm_namelock <Target> <1/0>`
**sm_notarget** |Disable sentry targeting on a player  |`sm_notarget [Target] <1/0>`
**sm_outline**  |Set outline effect on a player        |`sm_outline [Target] <1/0>`
**sm_telelock** |Lock teleporters from other players   |`sm_telelock [Target] <1/0>`
**sm_opentele** |Allow enemies through your teleporter |`sm_opentele [Target] <1/0>`

<br/>

Overrides               |Description
------------------------|---
**sm_addcond_target**   |Client can target others
**sm_remcond_target**   |Client can target others
**sm_notarget_target**  |Client can target others
**sm_outline_target**   |Client can target others
**sm_telelock_target**  |Client can target others
**sm_opentele_target**  |Client can target others

<br/>

<a name="helpmenu"/>
## Help Menu (sfp_helpmenu.smx)
ConVar                          |Description            |Default
--------------------------------|-----------------------|---
**sm_satansfunpack_helpconfig** |Help Menu config file  |`satansfunpack_help.cfg`
Help Config Structure:
```
"Example Section Name"                <--- Displayed on sm_help list
{
  "firstgreet"    "0"                 <--- Is this menu the first-time greeting?  (ONLY 1 PER FILE)
  "welcome"       "0"                 <--- Is this menu the regular welcome menu? (ONLY 1 PER FILE)
  "hidden"        "0"                 <--- Will this section appear on the Help Menu
  "title"         "Section's Title"   <--- Displayed when section is selected
  "filter"        "admin|scout|pyro"  <--- Can use: "admin", any TF2 class or both.

  "items"
  {
    "1"           <--- These are arbitrary, write whatever you like.
    {
      "text"  "Here is some standard, numbered text."
      "flags" ""  <--- "admin", "text", "cmd:<Client Command>", "open:<Section Name>" or TF2 class
    }
  }
}
```

Command      |Description                                           |Syntax
-------------|------------------------------------------------------|---
**sm_help**  |Displays the help menu                                |`sm_help`
**sm_rules** |Display the "Rules" section of the help menu (if any) |`sm_rules`

<br/>

<a name="infoutils"/>
## Info Utilities (sfp_infoutils.smx)
ConVar                              |Description                            |Default
------------------------------------|---------------------------------------|---
**sm_infoutils_disabledcmds**       |List of commands to completely disable |`""`
**sm_infoutils_id_noimmunity**      |Ignore Target Immunity with sm_id      |`0`
**sm_infoutils_profile_noimmunity** |Ignore Target Immunity with sm_profile |`0`
**sm_infoutils_group**              |Title and URL for sm_joingroup         |`"Join Our Group!;https://store.steampowered.com/"`

<br/>

Command               |Description                                    |Syntax
----------------------|-----------------------------------------------|---
**sm_amigagged**      |Checks your own Mute and Gag status            |`sm_amigagged`
**sm_amimuted**       |*Alias for sm_amigagged*                       |--
**sm_canplayerhear**  |Checks whether a player has muted another      |`sm_canplayerhear`
**sm_canhear**        |*Alias for sm_canplayerhear*                   |--
**sm_locateip**       |Get GeoIP Location of a player's IP Address    |`sm_locateip <Target>`
**sm_id**             |Get a player's SteamID in any form             |`sm_id <Target> [Type 1-4]`
**sm_profile**        |Display a player's steam profile               |`sm_profile <Target>`
**sm_getprofile**     |Print out a player's steam profile             |`sm_getprofile <Target>`
**sm_checkforupdate** |Check if the server has received a Restart Request |`sm_checkforupdate`
**sm_joingroup**      |Display the server's group page                |`sm_joingroup`

<br/>

<a name="quickconds"/>
## Quick Conditions (sfp_quickconditions.smx)
ConVar                        |Description                            |Default
------------------------------|---------------------------------------|---
**sm_quickcond_disabledcmds** |List of commands to completely disable |`""`

<br/>

Command             |Description          |Syntax
--------------------|---------------------|---
**sm_boing**        |Toggles Condition 72 |`sm_boing [Target] <1/0>`
**sm_dancemonkey**  |Adds Condition 54    |`sm_dancemonkey <Target> <Duration/0/Stop/End/Off>`

<br/>

<a name="targeting"/>
## Targeting (sfp_targeting.smx)
ConVar                    |Description                                              |Default
--------------------------|---------------------------------------------------------|---
**sm_random_target_bias** |@random Selection Threshold (255 < x > bias = selected)  |`127`

<br/>

Target Filter                 |Description
------------------------------|---
**@admins** and **@!admins**  |All Admins and All Non-Admins
**@mods** and **@!mods**      |All Moderators and All Non-Moderators
**@staff** and **@!staff**    |All Staff and All Non-Staff (Either Mod or Admin)
**@random**     |Random amount of all players
**@random1-31** |Random selecton of a set amount of players (random3 = 3 random players)
**@scouts** and **@!scouts**        |All Scouts and All Non-Scouts
**@soldiers** and **@!soldiers**    |All Soldiers and All Non-Soldiers
**@pyros** and **@!pyros**          |All Pyros and All Non-Pyros
**@demomen** and **@!demomen**      |All Demomen and All Non-Demomen
**@heavies** and **@!heavies**      |All Heavies and All Non-Heavies
**@engineers** and **@!engineers**  |All Engineers and All Non-Engineers
**@medics** and **@!medics**        |All Medics and All Non-Medics
**@snipers** and **@!snipers**      |All Snipers and All Non-Snipers
**@spies** and **@!spies**          |All Spies and All Non-Spies

<br/>

Overrides                 |Description
--------------------------|---
**sm_targetgroup_admin**  |Client is considered admin to `@admins` and `@staff` target filters
**sm_targetgroup_mod**    |Client is considered mod to `@mods` and `@staff` target filters

<br/>

<a name="toybox"/>
## Toy Box (sfp_toybox.smx)
ConVar                        |Description                            |Default
------------------------------|---------------------------------------|---
**sm_toybox_disabledcmds**    |List of commands to completely disable |`""`
**sm_resizeweapon_upper**     |Upper limit of sm_resizeweapon         |`3.0`
**sm_resizeweapon_lower**     |Lower limit of sm_resizeweapon         |`-3.0`
**sm_fov_upper**              |Upper limit of sm_fov                  |`160`
**sm_fov_lower**              |Lower limit of sm_fov                  |`30`
**sm_scream_enable_default**  |Is sm_scream enabled by default        |`1`
**sm_pitch_enable_default**   |Is sm_pitch enabled by default         |`1`
**sm_pitch_upper**            |Upper limit of sm_pitch                |`200`
**sm_pitch_lower**            |Lower limit of sm_pitch                |`50`

<br/>

Command                 |Description                                      |Syntax
------------------------|-------------------------------------------------|---
**sm_toybox_reloadcfg** |Reload the General Config file                   |`sm_toybox_reloadcfg`
**sm_colourweapon**     |Set the colour of a player's weapon              |`sm_colourweapon [Target] <Slot (All/1/2/3)> <Hex/RGB Colour>`
**sm_colorweapon**      |*Alias for sm_colourweapon*                      |--
**sm_cw**               |*Alias for sm_colourweapon*                      |--
**sm_resizeweapon**     |Set the scale of a player's weapon               |`sm_resizeweapon [Target] <Slot> <Scale>`
**sm_rw**               |*Alias for sm_resizeweapon*                      |--
**sm_fov**              |Set a player's Field of View                     |`sm_fov [Target] <1 to 179 or Reset/Default>`
**sm_scream**           |AAAAAAAAAAAAAAAAAAHH                             |`sm_scream [Target]`
**sm_screamtoggle**     |Toggle access to sm_scream                       |`sm_screamtoggle [1/0]`
**sm_pitch**            |Set a player's voiceline pitch                   |`sm_pitch [Target] <1-255 or 100/default/reset>`
**sm_pitchtoggle**      |Toggle access to sm_pitch                        |`sm_pitchtoggle [1/0]`
**sm_taunt**            |Perform any taunt                                |`sm_taunt`
**sm_taunts**           |*Alias for sm_taunt*                             |--
**sm_splay**            |Play a sound to a player without notifying them  |`sm_splay <Target> <File Path>`
**sm_colour**           |Set the colour of a player                       |`sm_colour [Target] <8-Digit Hex/RGBA Colour>`
**sm_color**            |*Alias for sm_colour*                            |--
**sm_friendlysentry**   |Toggle whether a player's sentry can deal damage |`sm_friendlysentry [Target] <1/0>`
**sm_cslap**            |Slap a player, play a sound and print a message  |`sm_cslap <Target>`

<br/>

Overrides                     |Description
------------------------------|---
**sm_colourweapon_target**    |Client can target others
**sm_resizeweapon_target**    |Client can target others
**sm_resizeweapon_nolimit**   |Client is unrestricted by upper/lower limits
**sm_fov_target**             |Client can target others
**sm_fov_nolimit**            |Client is unrestricted by upper/lower limits
**sm_scream_target**          |Client can target others
**sm_scream_nolock**          |Client can use command even if sm_screamtoggle disables it
**sm_pitch_target**           |Client can target others
**sm_pitch_nolock**           |Client can use command even if sm_pitchtoggle disables it
**sm_pitch_nolimit**          |Client is unrestricted by upper/lower limits
**sm_colour_target**          |Client can target others
**sm_friendlysentry_target**  |Client can target others

<br/>

<a name="mirror"/>
## Mirror (sfp_mirror.smx)
**- Not Implemented -**
<a name="trails"/>
## Trails (sfp_trails.smx)
**- Not Implemented -**
<a name="bans"/>
## Bans (sfp_bans.smx)
**- Not Implemented -**
<a name="chatvision"/>
## Chat Vision (sfp_chatvision.smx)
**- Not Implemented -**
<a name="duel"/>
## Duel (sfp_duel.smx)
**- Not Implemented -**
<a name="godmode"/>
## God Mode (sfp_godmode.smx)
**- Not Implemented -**
<a name="groupmanager"/>
## Group Manager (sfp_groupmanager)
**- Not Implemented -**
