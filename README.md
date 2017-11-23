# Satan's Fun Pack
A collection of useful commands and features for TF2 Servers.  
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
[God Mode (sfp_godmode.smx)](#godmode)  
[Name Colour Manager (sfp_namecolour.smx)](#namecolour)  
[Miscellaneous Tweaks (sfp_misctweaks.smx)](#misctweaks)  

<br/>

<a name="corefile"/>

## Core File (satansfunpack.smx)

| ConVar                      | Description                         | Default |
| --------------------------- |------------------------------------ | --- |
| **satansfunpack_version**   | Plugin Version                      | -- |
| **sm_satansfunpack_update** | Should satansfunpack.smx Auto-Update | `1` |

<br/>

| Command               | Description                                        | Syntax |
| --------------------- | -------------------------------------------------- | --- |
| **sm_sfpplugincheck** | Get install status of all Satan's Fun Pack plugins | `sm_sfpplugincheck` |

<br/>

<a name="admintools"/>

## Admin Tools (sfp_admintools.smx)

| ConVar                         | Description                            | Default |
| ------------------------------ | -------------------------------------- | --- |
| **sm_sfp_admintools_update**   | Should sfp_admintools.smx Auto-Update  | `1` |
| **sm_admintools_disabledcmds** | List of commands to completely disable | `""` |
| **sm_maxtempban**              | Maximum time for sm_tban (minutes)     | `180` |

<br/>

| Command        | Description                            | Syntax |
| -------------- | -------------------------------------- | --- |
| **sm_ccom**    | Force a player to use a command        | `sm_ccom <Target> <Command>` |
| **sm_tban**    | Ban players, with a limit on duration  | `sm_tban <Target> <Duration [Reason]`
| **sm_addcond** | Add a condition to a player            | `sm_addcond [Target] <Condition> <Duration>` |
| **sm_remcond** | Remove a condition from a player       | `sm_remcond [Target] <Condition>` |
| **sm_removecond** | *Alias for sm_remcond*              | --|
| **sm_disarm**  | Strip weapons from a player            | `sm_disarm <Target>` |
| **sm_switchteam** | Force player to switch teams        | `sm_switchteam <Target> [Red/Blu/Spec]` |
| **sm_forcespec** | Force player into spectator          | `sm_forcespec <Target>` |
| **sm_fsay**    | Make a player say something            | `sm_fsay <Target> <Message>` |
| **sm_fsayteam** | Make a player say something           | `sm_fsayteam <Target> <Message>` |
| **sm_namelock** | Prevent a player from changing names  | `sm_namelock <Target> <1/0>` |
| **sm_notarget** | Disable sentry targeting on a player  | `sm_notarget [Target] <1/0>` |
| **sm_outline**  | Set outline effect on a player        | `sm_outline [Target] <1/0>` |
| **sm_telelock** | Lock teleporters from other players   | `sm_telelock [Target] <1/0>` |
| **sm_opentele** | Allow enemies through your teleporter | `sm_opentele [Target] <1/0>` |
| **sm_forceclass** | Force player to a certain class     | `sm_forceclass <Target> <Class> [Lock 1/0]` |
| **sm_unlockclass** | Unlock players from `sm_forceclass` lock | `sm_unlockclass <Target>` |
| **sm_hp**       | Set a Player's Health                 | `sm_hp [Target] <Amount>` |
| **sm_respawn**  | Respawn a Player                      | `sm_respawn [Target]` |

<br/>

| Overrides               | Description |
| ----------------------- | --- |
| **sm_addcond_target**   | Client can target others |
| **sm_remcond_target**   | Client can target others |
| **sm_notarget_target**  | Client can target others |
| **sm_outline_target**   | Client can target others |
| **sm_telelock_target**  | Client can target others |
| **sm_opentele_target**  | Client can target others |
| **sm_forceclass_canlock** | Can lock a player into a class with `sm_forceclass` |
| **sm_sethealth_target** | Client can target others |
| **sm_respawn_target**   | Client can target others |

**Important Note:** sm_forceclass lock will *very* likely cause a crash if used with a class-limit.  

**Not as important Note:** Disabling sm_forceclass will also disable sm_unlockclass.  

<br/>

<a name="helpmenu"/>

## Help Menu (sfp_helpmenu.smx)

| ConVar                          | Description            | Default                  |
| ------------------------------- | ---------------------- | ------------------------ |
| **sm_sfp_help_update**          | Should sfp_helpmenu.smx Auto-Update | `1` |
| **sm_satansfunpack_helpconfig** | Help Menu config file  | `satansfunpack_help.cfg` |

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
      "flags" ""  <---  Flags, separated by '|':
                        "admin"
                        "text"
                        "cmd:<Client Command>"
                        "open:<Section Name>"
                        "msg:<Text>"
                        "scout", "soldier", "pyro", "demo", "engie", "heavy", "medic", "sniper", "spy"
    }
  }
}
```

| Command      | Description                                           | Syntax     |
| ------------ | ----------------------------------------------------- | ---------- |
| **sm_help**  | Displays the help menu                                | `sm_help`  |
| **sm_rules** | Display the "Rules" section of the help menu (if any) | `sm_rules` |

<br/>

| Overrides               | Description |
| ----------------------- | --- |
| **sm_helpmenu_admin**   | Client can see anything flagged as admin-only on the help menu |

**Note:** Recompile with `_ALT_HELPCMD` uncommented to change `sm_help` to `sm_helpmenu`.  
`sm_help` will clash with the default sourcemod plugin `adminhelp.smx`.  

<br/>

<a name="infoutils"/>

## Info Utilities (sfp_infoutils.smx)

| ConVar                              | Description                            | Default |
| ----------------------------------- | -------------------------------------- | --- |
| **sm_sfp_infoutils_update**          | Should sfp_infoutils.smx Auto-Update  | `1` |
| **sm_infoutils_disabledcmds**       | List of commands to completely disable | `""` |
| **sm_infoutils_id_noimmunity**      | Ignore Target Immunity with sm_id      | `0` |
| **sm_infoutils_profile_noimmunity** | Ignore Target Immunity with sm_profile | `0` |
| **sm_infoutils_group**              | Title and URL for sm_joingroup         | `"Join Our Group!;https://store.steampowered.com/"` |

<br/>

| Command               | Description                                    | Syntax
| ----------------------| ---------------------------------------------- | ---
| **sm_amigagged**      | Checks your own Mute and Gag status            | `sm_amigagged` |
| **sm_amimuted**       | *Alias for sm_amigagged*                       | -- |
| **sm_canplayerhear**  | Checks whether a player has muted another      | `sm_canplayerhear` |
| **sm_canhear**        | *Alias for sm_canplayerhear*                   | -- |
| **sm_locateip**       | Get GeoIP Location of a player's IP Address    | `sm_locateip <Target>` |
| **sm_id**             | Get a player's SteamID in any form             | `sm_id <Target> [Type 1-4]` |
| **sm_profile**        | Display a player's steam profile               | `sm_profile <Target>` |
| **sm_getprofile**     | Print out a player's steam profile             | `sm_getprofile <Target>` |
| **sm_checkforupdate** | Check if the server has received a Restart Request | `sm_checkforupdate` |
| **sm_joingroup**      | Display the server's group page                | `sm_joingroup` |

<br/>

<a name="quickconds"/>

## Quick Conditions (sfp_quickconditions.smx)

| ConVar                        | Description                            | Default |
| ----------------------------- | -------------------------------------- | --- |
| **sm_sfp_quickconditions_update** | Should sfp_quickconditions.smx Auto-Update  | `1` |
| **sm_quickcond_disabledcmds** | List of commands to completely disable | `""` |

<br/>

| Command             | Description          | Syntax |
| ------------------- | -------------------- | --- |
| **sm_boing**        | Toggles Condition 72 | `sm_boing [Target] <1/0>` |
| **sm_dancemonkey**  | Adds Condition 54    | `sm_dancemonkey <Target> <Duration/0/Stop/End/Off>` |

<br/>

<a name="targeting"/>

## Targeting (sfp_targeting.smx)

| ConVar                    | Description                                             | Default |
| ------------------------- | ------------------------------------------------------- | --- |
| **sm_sfp_targeting_update** | Should sfp_targeting.smx Auto-Update                  | `1` |
| **sm_random_target_bias** | @random Selection Threshold (255 < x > bias = selected) | `127` |
| **sm_unicodefilter_enabled** | Is Unicode Name Filtering Enabled | `1` |
| **sm_unicodefilter_notify** | Should the Unicode Name Filter notify the client about name changes | `1` |
| **sm_unicodefilter_interval** | Interval (in seconds) to filter every client's name | `20.0` |
| **sm_unicodefilter_mode** | Minimum Amount of ASCII characters required in a row for a name to not be filtered. 0 = Filter if any Unicode is in name. | `4` |

<br/>

| Target Filter                 | Description |
| ----------------------------- | --- |
| **@admins** and **@!admins**  | All Admins and All Non-Admins |
| **@mods** and **@!mods**      | All Moderators and All Non-Moderators |
| **@staff** and **@!staff**    | All Staff and All Non-Staff (Either Mod or Admin) |
| **@random**     | Random amount of all players |
| **@random1-31** | Random selecton of a set amount of players (random3 = 3 random players) |
| **@scouts** and **@!scouts**        | All Scouts and All Non-Scouts |
| **@soldiers** and **@!soldiers**    | All Soldiers and All Non-Soldiers |
| **@pyros** and **@!pyros**          | All Pyros and All Non-Pyros |
| **@demomen** and **@!demomen**      | All Demomen and All Non-Demomen |
| **@heavies** and **@!heavies**      | All Heavies and All Non-Heavies |
| **@engineers** and **@!engineers**  | All Engineers and All Non-Engineers |
| **@medics** and **@!medics**        | All Medics and All Non-Medics |
| **@snipers** and **@!snipers**      | All Snipers and All Non-Snipers |
| **@spies** and **@!spies**          | All Spies and All Non-Spies |

<br/>

| Overrides                 | Description |
| ------------------------- | --- |
| **sm_targetgroup_admin** | Client is considered admin to `@admins` and `@staff` target filters |
| **sm_targetgroup_mod**    | Client is considered mod to `@mods` and `@staff` target filters |
| **sm_unicodefilter_ignore** | Client's name will never be filtered by the Unicode Filter |

**Note:** This plugin will cancel any late-loads because of a bug that treats previously-filtered names as unfiltered. With a `sm_unicodefilter_mode` setting higher than the size of the player's User ID length, the name will be prefixed twice.  
You can just change the map to reload it which works fine.

<br/>

<a name="toybox"/>

## Toy Box (sfp_toybox.smx)

| ConVar                          | Description                            | Default |
| ------------------------------- | -------------------------------------- | --- |
| **sm_sfp_toybox_update**        | Should sfp_toybox.smx Auto-Update      | `1` |
| **sm_toybox_disabledcmds**      | List of commands to completely disable | `""` |
| **sm_resizeweapon_upper**       | Upper limit of sm_resizeweapon         | `3.0` |
| **sm_resizeweapon_lower**       | Lower limit of sm_resizeweapon         | `-3.0` |
| **sm_fov_upper**                | Upper limit of sm_fov                  | `160` |
| **sm_fov_lower**                | Lower limit of sm_fov                  | `30` |
| **sm_scream_enable_default**    | Is sm_scream enabled by default        | `1` |
| **sm_pitch_enable_default**     | Is sm_pitch enabled by default         | `1` |
| **sm_pitch_upper**              | Upper limit of sm_pitch                | `200` |
| **sm_pitch_lower**              | Lower limit of sm_pitch                | `50` |
| **sm_satansfunpack_toyconfig**  | Toy Box Config File             | `satansfunpack_toybox.cfg` |

Toy Box Config Structure:
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

| Command                 | Description                                      | Syntax |
| ----------------------- | ------------------------------------------------ | --- |
| **sm_toybox_reloadcfg** | Reload the General Config file                   | `sm_toybox_reloadcfg` |
| **sm_colourweapon**     | Set the colour of a player's weapon              | `sm_colourweapon [Target] <Slot (All/1/2/3)> <Hex/RGB Colour>` |
| **sm_colorweapon**      | *Alias for sm_colourweapon*                      | -- |
| **sm_cw**               | *Alias for sm_colourweapon*                      | -- |
| **sm_resizeweapon**     | Set the scale of a player's weapon               | `sm_resizeweapon [Target] <Slot> <Scale>` |
| **sm_rw**               | *Alias for sm_resizeweapon*                      | -- |
| **sm_fov**              | Set a player's Field of View                     | `sm_fov [Target] <1 to 179 or Reset/Default>` |
| **sm_scream**           | AAAAAAAAAAAAAAAAAAHH                             | `sm_scream [Target]` |
| **sm_screamtoggle**     | Toggle access to sm_scream                       | `sm_screamtoggle [1/0]` |
| **sm_pitch**            | Set a player's voiceline pitch                   | `sm_pitch [Target] <1-255 or 100/default/reset>` |
| **sm_pitchtoggle**      | Toggle access to sm_pitch                        | `sm_pitchtoggle [1/0]` |
| **sm_taunt**            | Perform any taunt                                | `sm_taunt` |
| **sm_tauntid**          | Perform any taunt by item index                  | `sm_tauntid [Target] <Taunt Item Index>` |
| **sm_taunts**           | *Alias for sm_taunt*                             | -- |
| **sm_splay**            | Play a sound to a player without notifying them  | `sm_splay <Target> <File Path>` |
| **sm_colour**           | Set the colour of a player                       | `sm_colour [Target] <8-Digit Hex/RGBA Colour>` |
| **sm_color**            | *Alias for sm_colour*                            | -- |
| **sm_friendlysentry**   | Toggle whether a player's sentry can deal damage | `sm_friendlysentry [Target] <1/0>` |
| **sm_cslap**            | Slap a player, play a sound and print a message  | `sm_cslap <Target>` |

<br/>

| Overrides                     | Description              |
| ----------------------------- | ------------------------ |
| **sm_colourweapon_target**    | Client can target others |
| **sm_resizeweapon_target**    | Client can target others |
| **sm_resizeweapon_nolimit**   | Client is unrestricted by upper/lower limits |
| **sm_fov_target**             | Client can target others |
| **sm_fov_nolimit**            | Client is unrestricted by upper/lower limits |
| **sm_scream_target**          | Client can target others |
| **sm_scream_nolock**          | Client can use command even if sm_screamtoggle disables it |
| **sm_pitch_target**           | Client can target others |
| **sm_pitch_nolock**           | Client can use command even if sm_pitchtoggle disables it |
| **sm_pitch_nolimit**          | Client is unrestricted by upper/lower limits |
| **sm_colour_target**          | Client can target others |
| **sm_friendlysentry_target**  | Client can target others |
| **sm_tauntid_target**         | Client can target others |

<br/>

<a name="mirror"/>

## Mirror (sfp_mirror.smx)

| ConVar                          | Description                            | Default |
| ------------------------------- | -------------------------------------- | --- |
| **sm_sfp_mirror_update**        | Should sfp_mirror.smx Auto-Update      | `1` |

<br/>

| Command       | Description                            | Syntax                     |
| ------------- | -------------------------------------- | -------------------------- |
| **sm_mirror** | Redirect a player's damage to themself | `sm_mirror <Target> <1/0>` |

<br/>

<a name="chatvision"/>

## Chat Vision (sfp_chatvision.smx)

**Passive** Echos all teamchat messages to Chat-Admins (players with access to `sm_chatvision_access`)  

| ConVar                    | Description                                          | Default |
| ------------------------- | ---------------------------------------------------- | --- |
| **sm_sfp_chatvision_update**        | Should sfp_chatvision.smx Auto-Update      | `1` |
| **sm_chatvision_enabled** | Toggle Chat Vision Output (it will still run everything else) | `1` |

<br/>

| Command                   | Description                                              | Syntax |
| ------------------------- | -------------------------------------------------------- | --- |
| **sm_chatvision_reload**  | Reloads the list of Chat-Admins (who can see enemy chat) | `sm_chatvision_reload` |
| **sm_ischatadmin**        | Check if a player is a Chat-Admin | `sm_ischatadmin <Target>` |

<br/>

| Overrides                 | Description                                         |
| ------------------------- | --------------------------------------------------- |
| **sm_chatvision_access**  | Client is considered admin and will see enemy chat  |

<br/>

<a name="godmode"/>

## God Mode (sfp_godmode.smx)

| ConVar                    | Description                        | Default |
| ------------------------- | ---------------------------------- | --- |
| **sm_sfp_godmode_update** | Should sfp_godmode.smx Auto-Update | `1` |

<br/>

| Command        | Description                                              | Syntax |
| -------------- | -------------------------------------------------------- | --- |
| **sm_god**  | Grant a player immunity to damage | `sm_god <[Target] [1/0]>` |
| **sm_buddha**  | Grant a player immunity to damage, but not damage forces | `sm_buddha <[Target] [1/0]>` |
| **sm_mortal**  | Revoke Buddha or God Mode from a player | `sm_mortal [Target]` |
| **sm_buildinggod** | Grant a player's buildings immunity from damage | `sm_buildinggod <[Target] [1/0]>` |
| **sm_bgod** | *Alias for sm_buildinggod* | -- |

<br/>

| Overrides                     | Description               |
| ----------------------------- | ------------------------- |
| **sm_godmode_target**         | Client can target others  |
| **sm_mortal_target**          | Client can target others  |
| **sm_buildinggod_target**     | Client can target others  |

**Note:** With sm_buddha, sm_buildinggod and sm_god, the targeting arguments are optional. However if used, both must be present.  
This is to prevent chaotic flip-flopping of players that already had the mode on.  

<br/>

<a name="namecolour"/>

## Name Colour Manager (sfp_namecolour.smx)

| ConVar                       | Description                            | Default |
| ---------------------------- | -------------------------------------- | --- |
| **sm_sfp_namecolour_update** | Should sfp_namecolour.smx Auto-Update  | `1` |
| **sm_satansfunpack_colourconfig** | Colour List Config File | `satansfunpack_colours.cfg` |

Colour Config Structure:
```
"SatansFunColours"
{
  "1"
  {
    "name"  "Alice Blue"
    "hex"   "F0F8FF"
  }
  ...
}
```

| Command        | Description                                              | Syntax |
| -------------- | -------------------------------------------------------- | --- |
| **sm_namecolour**     | Set Tag, Tag Colour, and Name Colour | `sm_namecolour` |
| **sm_namecolor**      | *Alias for sm_namecolour*     | -- |
| **sm_tagcolour**      | *Alias for sm_namecolour*     | -- |
| **sm_tagcolor**       | *Alias for sm_namecolour*     | -- |
| **sm_setnamecolour**  | Set Name Colour Directly      | `sm_setnamecolour <6-Digit Hex Colour>` |
| **sm_setnamecolor**   | *Alias for sm_setnamecolour*  | -- |
| **sm_settagcolour**   | Set Tag Colour Directly       | `sm_settagcolour <6-Digit Hex Colour>` |
| **sm_settagcolor**    | *Alias for sm_settagcolour*   | -- |
| **sm_settag**         | Set Tag Text Directly         | `sm_settag <Text>` |
| **sm_namecolour_reloadcfg** | Reload Colour Config    | `sm_namecolour_reloadcfg` |

<br/>

| Overrides                 | Description                                               |
| ------------------------- | --------------------------------------------------------- |
| **sm_setnamecolour**      | Access will automatically enable `Name Colour` Menu Item  |
| **sm_settagcolour**       | Access will automatically enable `Tag Colour` Menu Item   |
| **sm_settag**             | Access will automatically enable `Set Tag Text` Menu Item |
| **sm_resetcolour_access** | Client can use Reset All on `sm_namecolour` Menu          |

<br/>

<a name="misctweaks"/>

## Miscellaneous Tweaks (sfp_misctweaks.smx)

| ConVar                       | Description                            | Default |
| ---------------------------- | -------------------------------------- | --- |
| **sm_sfp_misctweaks_update** | Should sfp_misctweaks.smx Auto-Update  | `1` |
| **sm_sfp_misctweaks_shield** | Allow The Medigun Shield               | `1` |
| **sm_sfp_misctweaks_shield_stock** | Only Allow Stock Mediguns + Variants to create Shields | `1` |
| **sm_sfp_misctweaks_shield_dmg** | Damage Amount Shields should deal to Players | `1.0` |

<br/>

| Command             | Description                         | Syntax                  |
| ------------------- | ----------------------------------- | ---                     |
| **sm_forceshield**  | Force Your Medigun Shield to Spawn  | `sm_forceshield`        |
| **sm_filluber**     | Set a player's ubercharge to 100%   | `sm_filluber [Target]`  |

<br/>

| Overrides                 | Description               |
| ------------------------- | ------------------------- |
| **sm_filluber_target**    | Client can target others  |

**Notes:**  
Shields are created by using +attack3 with a full ubercharge.  
MvM Uses a Shield Damage value of 1.0  
`sm_sfp_misctweaks_shield` values can be  
 - -1 = Disabled
 - 0  = Only `sm_forceshield` is allowed
 - 1  = Enabled

<br/>

<a name="bans"/>

## Bans (sfp_bans.smx)

**- Not Implemented -**
