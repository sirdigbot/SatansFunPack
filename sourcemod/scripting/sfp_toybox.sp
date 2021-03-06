/***********************************************************************
 * This Source Code Form is subject to the terms of the Mozilla Public *
 * License, v. 2.0. If a copy of the MPL was not distributed with this *
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.            *
 *                                                                     *
 * Copyright (C) 2018 SirDigbot                                        *
 ***********************************************************************/

#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#tryinclude <tf2items>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>
#include <sfh_chatlib>


//=================================
// Constants
#define PLUGIN_VERSION  "1.1.1"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/toybox_update.txt"
#define PITCH_DEFAULT   100
#define MAX_TAUNTS      64
#define MAX_TAUNTID_INT 10000000 // Arbitrary cap


// Set Which Commands to Compile
#define _INCLUDE_COLOURWEP
#define _INCLUDE_RESIZEWEP
#define _INCLUDE_FOV
#define _INCLUDE_SCREAM
#define _INCLUDE_PITCH
#define _INCLUDE_TAUNTS
#define _INCLUDE_SPLAY
#define _INCLUDE_COLOUR
#define _INCLUDE_FRIENDLYSENTRY
#define _INCLUDE_CUSTOMSLAP

// List of commands that can be disabled.
// Set by CVar, updated in ProcessDisabledCmds, Checked in Command.
enum CommandNames {
  ComCOLOURWEAPON = 0,
  ComRESIZEWEAPON,
  ComFOV,
  ComSCREAM,
  ComSCREAMTOGGLE,
  ComPITCH,
  ComPITCHTOGGLE,
  ComTAUNTMENU,
  ComTAUNTID,
  ComSPLAY,
  ComCOLOUR,
  ComFRIENDLYSENTRY,
  ComCSLAP,
  ComTOTAL
};


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
Handle  h_szConfig = null;
char    g_szConfig[CONFIG_SIZE];
Handle  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];


#if defined _INCLUDE_RESIZEWEP
Handle  h_flResizeUpper = null;
float   g_flResizeUpper;
Handle  h_flResizeLower = null;
float   g_flResizeLower;
#endif

#if defined _INCLUDE_FOV
Handle  h_iFOVUpper = null;
int     g_iFOVUpper;
Handle  h_iFOVLower = null;
int     g_iFOVLower;
int     g_iFOVDesired[MAXPLAYERS + 1]; // Don't reset on disconnect, set OnClientPutInServer.
#endif

#if defined _INCLUDE_SCREAM
Handle  h_bScreamDefault = null; // Default state for g_bScreamEnabled
bool    g_bScreamEnabled;
#endif

#if defined _INCLUDE_PITCH
Handle  h_bPitchDefault = null;  // Default state for g_bPitchEnabled
bool    g_bPitchEnabled;
Handle  h_iPitchUpper   = null;
int     g_iPitchUpper;
Handle  h_iPitchLower   = null;
int     g_iPitchLower;
int     g_iPitch[MAXPLAYERS + 1] = {PITCH_DEFAULT, ...}; // Value is a percentage, 100 default
#endif

#if defined _INCLUDE_TAUNTS
Handle  h_SDKPlayTauntScene = null;
char    g_szTauntName[MAX_TAUNTS][32];
int     g_iTauntId[MAX_TAUNTS];
enum TFClasses // Need an addittional All-Class option so dont use TFClassType
{
  TFInvalid = TFClass_Unknown,
  TFScout = TFClass_Scout,
  TFSniper = TFClass_Sniper,
  TFSoldier = TFClass_Soldier,
  TFDemoman = TFClass_DemoMan,
  TFMedic = TFClass_Medic,
  TFHeavy = TFClass_Heavy,
  TFPyro = TFClass_Pyro,
  TFSpy = TFClass_Spy,
  TFEngie = TFClass_Engineer,
  TFAllClass
};
TFClasses g_TauntClass[MAX_TAUNTS];
int     g_iTauntCount;
#endif

#if defined _INCLUDE_FRIENDLYSENTRY
bool    g_bFriendlySentry[MAXPLAYERS + 1];
#endif

#if defined _INCLUDE_CUSTOMSLAP
Handle  h_szSlapSound = null;
Handle  h_szSlapMsg   = null;
char    g_szSlapSound[PLATFORM_MAX_PATH];
char    g_szSlapMsg[PLATFORM_MAX_PATH];
bool    g_bSlapUseSound;
bool    g_bSlapUseMsg;
#endif


/**
 * Known Bugs:
 * - TODO sm_colour should have a non-admin alpha limiting cvar
 * - ResetColour, ResetWeaponColour and ResetWeaponSize should be added.
 * - FriendlySentry should indicate the sentry is different.
 * - TODO Add sm_tauntidlist to show all valid taunt ids.
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Toy Box",
  author =      "SirDigby",
  description = "What's a Fun Pack Without Toys?",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};


//=================================
// Forwards/Events
public APLRes AskPluginLoad2(Handle self, bool late, char[] err, int err_max)
{
  g_bLateLoad = late;
  EngineVersion engine = GetEngineVersion();
  if(engine != Engine_TF2)
  {
    Format(err, err_max, "Satan's Fun Pack is only compatible with Team Fortress 2.");
    return APLRes_Failure;
  }
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  LoadTranslations("sfp.toybox.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");


  // SDKTools Hooks
  // Thank you to FlaminSarge for the sdktools code.
  #if defined _INCLUDE_TAUNTS
  Handle gameData = LoadGameConfigFile("tf2.satansfunpack_toybox");
  if(gameData == INVALID_HANDLE)
  {
    SetFailState("%T", "SFP_NoGameData", LANG_SERVER, "tf2.satansfunpack_toybox");
    return;
  }
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
  h_SDKPlayTauntScene = EndPrepSDKCall();
  if(h_SDKPlayTauntScene == INVALID_HANDLE)
  {
    delete gameData;
    SetFailState("%T", "SM_TAUNTMENU_BadGameData", LANG_SERVER);
    return;
  }
  delete gameData;
  #endif


  // Cvars
  h_bUpdate = CreateConVar("sm_sfp_toybox_update", "1", "Update Satan's Fun Pack - Toy Box Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_szConfig = CreateConVar("sm_satansfunpack_toyconfig", "satansfunpack_toybox.cfg", "Config File used for Satan's Fun Pack Toy Box (Relative to Sourcemod/Configs)\n(Default: satansfunpack_toybox.cfg)", FCVAR_SPONLY);

  char cvarBuffer[PLATFORM_MAX_PATH], pathBuffer[CONFIG_SIZE];
  GetConVarString(h_szConfig, cvarBuffer, sizeof(cvarBuffer));
  Format(pathBuffer, sizeof(pathBuffer), "configs/%s", cvarBuffer);
  BuildPath(Path_SM, g_szConfig, sizeof(g_szConfig), pathBuffer);
  LoadConfig();
  HookConVarChange(h_szConfig, UpdateCvars);


  h_bDisabledCmds = CreateConVar("sm_toybox_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- ColourWeapon\n- ResizeWeapon\n- FOV\n- ScreamCmd\n- ScreamToggle\n- PitchCmd\n- PitchToggle\n- TauntMenu\n- TauntID\n- SPlay\n- ColourSelf\n- FriendlySentry\n- CSlap", FCVAR_SPONLY|FCVAR_REPLICATED);
  ProcessDisabledCmds();
  HookConVarChange(h_bDisabledCmds, UpdateCvars);



  #if defined _INCLUDE_RESIZEWEP
  h_flResizeUpper = CreateConVar("sm_resizeweapon_upper", "3.0", "Upper Limits of Weapon Resize\n(Default: 3.0)", FCVAR_NONE);
  g_flResizeUpper = GetConVarFloat(h_flResizeUpper);
  HookConVarChange(h_flResizeUpper, UpdateCvars);

  h_flResizeLower = CreateConVar("sm_resizeweapon_lower", "-3.0", "Lower Limits of Weapon Resize\n(Default: -3.0)", FCVAR_NONE);
  g_flResizeLower = GetConVarFloat(h_flResizeLower);
  HookConVarChange(h_flResizeLower, UpdateCvars);
  #endif

  #if defined _INCLUDE_FOV
  h_iFOVUpper = CreateConVar("sm_fov_upper", "160", "Upper Limits of FOV\n(Default: 160)", FCVAR_NONE, true, 1.0, true, 179.0);
  g_iFOVUpper = GetConVarInt(h_iFOVUpper);
  HookConVarChange(h_iFOVUpper, UpdateCvars);

  h_iFOVLower = CreateConVar("sm_fov_lower", "30", "Lower Limits of FOV\n(Default: 30)", FCVAR_NONE, true, 1.0, true, 179.0);
  g_iFOVLower = GetConVarInt(h_iFOVLower);
  HookConVarChange(h_iFOVLower, UpdateCvars);
  #endif

  #if defined _INCLUDE_SCREAM
  h_bScreamDefault = CreateConVar("sm_scream_enable_default", "1", "Is sm_scream Enabled by Default (1/0)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bScreamEnabled = GetConVarBool(h_bScreamDefault);
  HookConVarChange(h_bScreamDefault, UpdateCvars);
  #endif

  #if defined _INCLUDE_PITCH
  h_bPitchDefault = CreateConVar("sm_pitch_enable_default", "1", "Is sm_pitch Enabled by Default (1/0)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bPitchEnabled = GetConVarBool(h_bPitchDefault);
  HookConVarChange(h_bPitchDefault, UpdateCvars);

  h_iPitchUpper = CreateConVar("sm_pitch_upper", "200", "Upper Limits of Voice Pitch\n(Default: 200)", FCVAR_NONE, true, 1.0, true, 255.0);
  g_iPitchUpper = GetConVarInt(h_iPitchUpper);
  HookConVarChange(h_iPitchUpper, UpdateCvars);

  h_iPitchLower = CreateConVar("sm_pitch_lower", "50", "Lower Limits of Voice Pitch\n(Default: 50)", FCVAR_NONE, true, 1.0, true, 255.0);
  g_iPitchLower = GetConVarInt(h_iPitchLower);
  HookConVarChange(h_iPitchLower, UpdateCvars);
  #endif
  
  #if defined _INCLUDE_CUSTOMSLAP
  h_szSlapMsg   = CreateConVar("sm_cslap_message", "", "Message to display with sm_cslap. Empty will disable.\n(Default: \"\")", FCVAR_NONE);
  h_szSlapSound = CreateConVar("sm_cslap_sound", "", "Sound file to play with sm_cslap. Relative to 'tf2/sound/' (Same paths used for sm_play). Empty will disable.\n(Default: \"\")", FCVAR_NONE);
  GetConVarString(h_szSlapMsg, g_szSlapMsg, sizeof(g_szSlapMsg));
  GetConVarString(h_szSlapSound, g_szSlapSound, sizeof(g_szSlapSound));
  g_bSlapUseMsg   = !StrEqual(g_szSlapMsg, "", true); // Disable if empty
  g_bSlapUseSound = !StrEqual(g_szSlapSound, "", true);
  HookConVarChange(h_szSlapMsg, UpdateCvars);
  HookConVarChange(h_szSlapSound, UpdateCvars);
  #endif


  RegAdminCmd("sm_toybox_reloadcfg", CMD_ConfigReload, ADMFLAG_ROOT, "Reload Config for Satan's Fun Pack - Toybox");

  #if defined _INCLUDE_COLOURWEP
  RegAdminCmd("sm_colourweapon",    CMD_ColourWeapon, ADMFLAG_GENERIC, "Colour Your Weapons");
  RegAdminCmd("sm_colorweapon",     CMD_ColourWeapon, ADMFLAG_GENERIC, "Color Your Guns");
  RegAdminCmd("sm_cw",              CMD_ColourWeapon, ADMFLAG_GENERIC, "Colour Your Weapons");
  #endif
  #if defined _INCLUDE_RESIZEWEP
  RegAdminCmd("sm_resizeweapon",    CMD_ResizeWeapon, ADMFLAG_GENERIC, "Resize Your Weapons");
  RegAdminCmd("sm_rw",              CMD_ResizeWeapon, ADMFLAG_GENERIC, "Resize Your Weapons");
  #endif
  #if defined _INCLUDE_FOV
  RegAdminCmd("sm_fov",             CMD_FieldOfView, ADMFLAG_GENERIC, "Set your Field of View");
  #endif
  #if defined _INCLUDE_SCREAM
  RegAdminCmd("sm_scream",          CMD_Scream, ADMFLAG_GENERIC, "Do it for the ice cream");
  RegAdminCmd("sm_screamtoggle",    CMD_ScreamToggle, ADMFLAG_GENERIC, "Toggle the sm_scream Command");
  #endif
  #if defined _INCLUDE_PITCH
  RegAdminCmd("sm_pitch",           CMD_Pitch, ADMFLAG_GENERIC, "Make the Big Burly Men Sound Like Mice");
  RegAdminCmd("sm_pitchtoggle",     CMD_PitchToggle, ADMFLAG_GENERIC, "Toggle the sm_pitch Command");
  #endif
  #if defined _INCLUDE_TAUNTS
  // To Appease Lord GabeN, keep these as console cmds
  RegConsoleCmd("sm_taunt",         CMD_TauntMenu, "Perform Any Taunt");
  RegConsoleCmd("sm_taunts",        CMD_TauntMenu, "Perform Any Taunt");
  RegConsoleCmd("sm_tauntid",       CMD_TauntById, "Perform Any Taunt by Item Index");
  #endif
  #if defined _INCLUDE_SPLAY
  RegAdminCmd("sm_splay",           CMD_StealthPlay, ADMFLAG_GENERIC, "Play Sounds Stealthily");
  #endif
  #if defined _INCLUDE_COLOUR
  RegAdminCmd("sm_colour",          CMD_ColourPlayer, ADMFLAG_GENERIC, "Slap on Some Cheap Paint");
  RegAdminCmd("sm_color",           CMD_ColourPlayer, ADMFLAG_GENERIC, "Slap on Some Cheap, Patriotic Paint");
  #endif
  #if defined _INCLUDE_FRIENDLYSENTRY
  RegAdminCmd("sm_friendlysentry",  CMD_FriendlySentry, ADMFLAG_GENERIC, "Load Your Sentry Full of Friendliness Pellets");
  #endif
  #if defined _INCLUDE_CUSTOMSLAP
  RegAdminCmd("sm_cslap",           CMD_CustomSlap, ADMFLAG_GENERIC, "A Customisable Slap");
  #endif

  /**
   * Overrides
   * sm_colourweapon_target
   * sm_resizeweapon_target
   * sm_resizeweapon_nolimit
   * sm_fov_target
   * sm_fov_nolimit
   * sm_scream_target
   * sm_scream_nolock   - Player ignores sm_scream being disabled
   * sm_pitch_target
   * sm_pitch_nolock    - Player ignores sm_pitch being disabled
   * sm_pitch_nolimit
   * sm_colour_target
   * sm_friendlysentry_target
   * sm_tauntid_target
   */

  AddNormalSoundHook(view_as<NormalSHook>(Hook_NormalSound)); // Sourcemod, why?

  /*** Handle Late Loads ***/
  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; ++i)
    {
      if(IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
      {
        #if defined _INCLUDE_FOV
        QueryClientConVar(i, "fov_desired", OnGetDesiredFOV);
        #endif
        #if defined _INCLUDE_FRIENDLYSENTRY
        SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        #endif
      }
    }
  }

  PrintToServer("%T", "SFP_ToyBoxLoaded", LANG_SERVER);
}


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_szConfig)
  {
    char pathBuffer[CONFIG_SIZE];
    Format(pathBuffer, sizeof(pathBuffer), "configs/%s", newValue);
    BuildPath(Path_SM, g_szConfig, sizeof(g_szConfig), pathBuffer);
    LoadConfig();
  }
  else if(cvar == h_bDisabledCmds)
    ProcessDisabledCmds();
  #if defined _INCLUDE_RESIZEWEP
  else if(cvar == h_flResizeUpper)
    g_flResizeUpper = StringToFloat(newValue);
  else if(cvar == h_flResizeLower)
    g_flResizeLower = StringToFloat(newValue);
  #endif

  #if defined _INCLUDE_FOV
  else if(cvar == h_iFOVUpper)
    g_iFOVUpper = StringToInt(newValue);
  else if(cvar == h_iFOVLower)
    g_iFOVLower = StringToInt(newValue);
  #endif

  #if defined _INCLUDE_SCREAM
  else if(cvar == h_bScreamDefault)
    g_bScreamEnabled = GetConVarBool(h_bScreamDefault);
  #endif

  #if defined _INCLUDE_PITCH
  else if(cvar == h_bPitchDefault)
    g_bPitchEnabled = GetConVarBool(h_bPitchDefault);
  else if(cvar == h_iPitchUpper)
    g_iPitchUpper = StringToInt(newValue);
  else if(cvar == h_iPitchLower)
    g_iPitchLower = StringToInt(newValue);
  #endif
  
  #if defined _INCLUDE_CUSTOMSLAP
  else if(cvar == h_szSlapMsg)
  {
    GetConVarString(h_szSlapMsg, g_szSlapMsg, sizeof(g_szSlapMsg));
    g_bSlapUseMsg = !StrEqual(g_szSlapMsg, "", true); // Disable if empty
  }
  else if(cvar == h_szSlapSound)
  {
    GetConVarString(h_szSlapSound, g_szSlapSound, sizeof(g_szSlapSound));
    g_bSlapUseSound = !StrEqual(g_szSlapSound, "", true);
  }
  #endif
  return;
}

/**
 * Set Enable/Disable state for every command from CVar
 */
void ProcessDisabledCmds()
{
  for(int i = 0; i < view_as<int>(ComTOTAL); ++i)
    g_bDisabledCmds[i] = false;

  char buffer[256];
  GetConVarString(h_bDisabledCmds, buffer, sizeof(buffer));
  if(StrContains(buffer, "ColourWeapon", true) != -1)
    g_bDisabledCmds[ComCOLOURWEAPON] = true;

  if(StrContains(buffer, "ResizeWeapon", true) != -1)
    g_bDisabledCmds[ComRESIZEWEAPON] = true;

  if(StrContains(buffer, "FOV", true) != -1)
    g_bDisabledCmds[ComFOV] = true;

  if(StrContains(buffer, "ScreamCmd", true) != -1)
    g_bDisabledCmds[ComSCREAM] = true;

  if(StrContains(buffer, "ScreamToggle", true) != -1)
    g_bDisabledCmds[ComSCREAMTOGGLE] = true;

  if(StrContains(buffer, "PitchCmd", true) != -1)
    g_bDisabledCmds[ComPITCH] = true;

  if(StrContains(buffer, "PitchToggle", true) != -1)
    g_bDisabledCmds[ComPITCHTOGGLE] = true;

  if(StrContains(buffer, "TauntMenu", true) != -1)
    g_bDisabledCmds[ComTAUNTMENU] = true;

  if(StrContains(buffer, "TauntID", true) != -1)
    g_bDisabledCmds[ComTAUNTID] = true;

  if(StrContains(buffer, "SPlay", true) != -1)
    g_bDisabledCmds[ComSPLAY] = true;

  if(StrContains(buffer, "ColourSelf", true) != -1)
    g_bDisabledCmds[ComCOLOUR] = true;

  if(StrContains(buffer, "FriendlySentry", true) != -1)
    g_bDisabledCmds[ComFRIENDLYSENTRY] = true;

  if(StrContains(buffer, "CSlap", true) != -1)
    g_bDisabledCmds[ComCSLAP] = true;
  return;
}


public void OnClientPutInServer(int client)
{
  if(!IsClientReplay(client) && !IsClientSourceTV(client))
  {
    #if defined _INCLUDE_FOV
    QueryClientConVar(client, "fov_desired", OnGetDesiredFOV);
    #endif
    #if defined _INCLUDE_FRIENDLYSENTRY
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    #endif
  }
  return;
}

public void OnClientDisconnect_Post(int client)
{
  // Do not put g_iFOVDesired here, set on connect
  #if defined _INCLUDE_PITCH
  g_iPitch[client] = PITCH_DEFAULT;
  #endif
  #if defined _INCLUDE_FRIENDLYSENTRY
  g_bFriendlySentry[client] = false;
  #endif
  return;
}


public Action Hook_NormalSound(
  int clients[MAXPLAYERS],
  int &numClients,
  char sample[PLATFORM_MAX_PATH],
  int &entity,
  int &channel,
  float &volume,
  int &level,
  int &pitch,
  int &flags)
{
  // entity = client
  if(channel == SNDCHAN_VOICE && entity >= 1 && entity <= MaxClients)
  {
    #if defined _INCLUDE_PITCH
    if(g_iPitch[entity] != PITCH_DEFAULT)
    {
      pitch = g_iPitch[entity];
      flags |= SND_CHANGEPITCH;
      return Plugin_Changed;
    }
    #endif
  }
  return Plugin_Continue;
}


public Action OnTakeDamage(
  int victim,
  int &attacker,
  int &inflictor,
  float &damage,
  int &damagetype,
  int &weapon,
  float damageForce[3],
  float damagePosition[3])
{
  #if defined _INCLUDE_FRIENDLYSENTRY
  if(!IsValidEntity(inflictor))
    return Plugin_Continue;

  char classname[27];
  GetEdictClassname(inflictor, classname, sizeof(classname));
  if(StrEqual(classname, "obj_sentrygun", true)
  || StrEqual(classname, "tf_projectile_sentryrocket", true))
  {
    if(attacker > 0 && attacker <= MaxClients && g_bFriendlySentry[attacker])
    {
      damage = 0.0;
      return Plugin_Changed;
    }
  }
  #endif
  return Plugin_Continue;
}




//=================================
// Commands

/**
 * Change the colour of a player's weapon
 *
 * sm_colourweapon [Target] <Slot 1/2/3/All> <Hex Colour/RGB Colour>
 * [Target] <Slot> <Hex> or [Target] <Slot> <R> <G> <B> (4 Arg Combos: 2,3,4 & 5)
 *
 * Slot must be mandatory or you can't easily distinguish these 3-arg commands:
 * [Target]+[Slot]+<Hex> vs <R>+<G>+<B>
 * TODO Add alpha support.
 */
#if defined _INCLUDE_COLOURWEP
public Action CMD_ColourWeapon(int client, int args)
{
  if(g_bDisabledCmds[ComCOLOURWEAPON])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2 || args > 5)
  {
    TagReplyUsage(client, "%T", "SM_COLWEAPON_Usage", client);
    return Plugin_Handled;
  }

  // Get first 2 required args
  char arg1[MAX_NAME_LENGTH], arg2[MAX_SLOTSTRING_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));


  // Get Target. Default to client.
  bool bSelfTarget = false;
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if(args == 3 || args == 5) // Either Hex or RGB, but with target specified
  {
    if(!CheckCommandAccess(client, "sm_colourweapon_target", ADMFLAG_BAN, true))
    {
      TagReply(client, "%T", "SFP_NoTargeting", client);
      return Plugin_Handled;
    }

    if ((targ_count = ProcessTargetString(
      arg1,
      client,
      targ_list,
      MAXPLAYERS,
      COMMAND_FILTER_ALIVE,
      targ_name,
      sizeof(targ_name),
      tn_is_ml)) <= 0)
    {
      ReplyToTargetError(client, targ_count);
      return Plugin_Handled;
    }
  }
  else // No target, set to client.
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    targ_count = 1;
    targ_list[0] = client;
    GetClientName(client, targ_name, sizeof(targ_name));
    bSelfTarget = true;
  }


  // Get Slot
  TF_Slot_Index slotIndex = TF_Slot_Invalid;
  if(args == 2 || args == 4)
    slotIndex = GetWeaponSlotIndex(arg1);
  else if(args == 3 || args == 5)
    slotIndex = GetWeaponSlotIndex(arg2);
  if(slotIndex == TF_Slot_Invalid)
  {
    TagReply(client, "%T", "SFP_BadWeaponSlot", client);
    return Plugin_Handled;
  }


  // Get Colour. Check for Hex then RGB.
  int iRed, iGreen, iBlue;
  char arg3[7], arg4[4], arg5[4]; // Arg3 can be 6 or 3-digits, 4 and 5 can only be 3.

  if(args == 2)       // arg1:Slot, arg2:Hex
  {
    if(!HexToRGB(arg2, iRed, iGreen, iBlue))
    {
      TagReply(client, "%T", "SFP_BadHexColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 3)  // arg2:Slot, arg3:Hex
  {
    GetCmdArg(3, arg3, sizeof(arg3));

    if(!HexToRGB(arg3, iRed, iGreen, iBlue))
    {
      TagReply(client, "%T", "SFP_BadHexColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 4)  // arg1:Slot, arg2-4:RGB
  {
    GetCmdArg(3, arg3, sizeof(arg3));
    GetCmdArg(4, arg4, sizeof(arg4));

    iRed    = StringToInt(arg2);
    iGreen  = StringToInt(arg3);
    iBlue   = StringToInt(arg4);
    if(!IsColourRGB(iRed, iGreen, iBlue))
    {
      TagReply(client, "%T", "SFP_BadRGBColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 5)  // arg2:Slot, arg3-5:RGB
  {
    GetCmdArg(3, arg3, sizeof(arg3));
    GetCmdArg(4, arg4, sizeof(arg4));
    GetCmdArg(5, arg5, sizeof(arg5));

    iRed    = StringToInt(arg3);
    iGreen  = StringToInt(arg4);
    iBlue   = StringToInt(arg5);
    if(!IsColourRGB(iRed, iGreen, iBlue))
    {
      TagReply(client, "%T", "SFP_BadRGBColour", client);
      return Plugin_Handled;
    }
  }


  // Target, Colour and Slot ready. Apply.
  for(int i = 0; i < targ_count; ++i)
  {
    if(!IsClientPlaying(targ_list[i]))
      continue;

    int weapon;
    switch(slotIndex)
    {
      case TF_Slot_AllWeapons:
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Primary));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Secondary));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Melee));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);
      }

      default: // Assuming index is only primary, secondary, melee or All.
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(slotIndex));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);
      }
    }
  }

  if(bSelfTarget)
    TagReply(client, "%T", "SM_COLWEAPON_Done", client, iRed, iGreen, iBlue);
  else
    TagActivity2(client, "%T", "SM_COLWEAPON_Done_Server", LANG_SERVER, targ_name, iRed, iGreen, iBlue);
  return Plugin_Handled;
}
#endif


/**
 * Resize a player's weapon
 *
 * sm_resizeweapon [Target] <Slot> <Scale>
 * Slot is required so self-targeting to change a specific slot isn't.
 */
#if defined _INCLUDE_RESIZEWEP
public Action CMD_ResizeWeapon(int client, int args)
{
  if(g_bDisabledCmds[ComRESIZEWEAPON])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_SIZEWEAPON_Usage", client);
    return Plugin_Handled;
  }

  // Get Required Args
  char arg1[MAX_NAME_LENGTH], arg2[8];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));


  // Get Scale
  float flScale;
  if(args == 2)
    flScale = StringToFloat(arg2);
  else
  {
    char arg3[8];
    GetCmdArg(3, arg3, sizeof(arg3));
    flScale = StringToFloat(arg3);
  }
  if((FloatCompare(flScale, g_flResizeLower) == -1
  || FloatCompare(flScale, g_flResizeUpper) == 1
  || FloatCompare(flScale, 0.0) == 0)
  && !CheckCommandAccess(client, "sm_resizeweapon_nolimit", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SM_SIZEWEAPON_Scale", client, g_flResizeLower, g_flResizeUpper);
    return Plugin_Handled;
  }


  // Get Slot
  TF_Slot_Index slotIndex = TF_Slot_Invalid;
  if(args == 2)
    slotIndex = GetWeaponSlotIndex(arg1);
  else // if(args == 3)
    slotIndex = GetWeaponSlotIndex(arg2);
  if(slotIndex == TF_Slot_Invalid)
  {
    TagReply(client, "%T", "SFP_BadWeaponSlot", client);
    return Plugin_Handled;
  }


  // Get Target. Default to client.
  bool bSelfTarget = false;
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;


  if(args == 2) // No target, set to client.
  {
    if(!IsClientPlaying(client)) // TODO: check if this is applied to all targeted cmds
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    targ_count = 1;
    targ_list[0] = client;
    GetClientName(client, targ_name, sizeof(targ_name));
    bSelfTarget = true;
  }
  else // if args == 3
  {
    if(!CheckCommandAccess(client, "sm_resizeweapon_target", ADMFLAG_BAN, true))
    {
      TagReply(client, "%T", "SFP_NoTargeting", client);
      return Plugin_Handled;
    }

    if ((targ_count = ProcessTargetString(
      arg1,
      client,
      targ_list,
      MAXPLAYERS,
      COMMAND_FILTER_ALIVE,
      targ_name,
      sizeof(targ_name),
      tn_is_ml)) <= 0)
    {
      ReplyToTargetError(client, targ_count);
      return Plugin_Handled;
    }
  }



  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(!IsClientPlaying(targ_list[i]))
      continue;

    int weapon;
    switch(slotIndex)
    {
      case TF_Slot_AllWeapons:
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Primary));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Secondary));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Melee));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);
      }

      default: // Assuming index is only primary, secondary, melee or All.
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(slotIndex));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);
      }
    }
  }

  if(bSelfTarget)
    TagReply(client, "%T", "SM_SIZEWEAPON_Done", client, flScale);
  else
    TagActivity2(client, "%T", "SM_SIZEWEAPON_Done_Server", LANG_SERVER, targ_name, flScale);
  return Plugin_Handled;
}
#endif



/**
 * Set a player's Field of View
 *
 * sm_fov [Target] <1 to 179 or Reset/Default>
 * Range is default 30-160
 */
#if defined _INCLUDE_FOV
public Action CMD_FieldOfView(int client, int args)
{
  if(g_bDisabledCmds[ComFOV])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_FOV_Usage", client, g_iFOVLower, g_iFOVUpper);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  int val = 0;

  if(args == 1)
  {
    if(!IsClientPlaying(client, true)) // Allow Spectators to use on self.
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(StrEqual(arg1, "reset", false) || StrEqual(arg1, "default", false))
    {
      SetFOV(client, 0, true);
      TagReply(client, "%T", "SM_FOV_Done_Default", client);
      return Plugin_Handled;
    }

    val = StringToInt(arg1);
    if((val < g_iFOVLower || val > g_iFOVUpper)
    && !CheckCommandAccess(client, "sm_fov_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_FOV_Usage", client, g_iFOVLower, g_iFOVUpper);
      return Plugin_Handled;
    }

    SetFOV(client, val, false);
    TagReply(client, "%T", "SM_FOV_Done", client, val);
    return Plugin_Handled;
  }


  // Get Target
  if(!CheckCommandAccess(client, "sm_fov_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_NO_BOTS,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Get Value
  char arg2[16];
  bool isDefault = false;
  GetCmdArg(2, arg2, sizeof(arg2));

  if(StrEqual(arg2, "reset", false) || StrEqual(arg2, "default", false))
    isDefault = true;
  else
  {
    val = StringToInt(arg2);
    if((val < g_iFOVLower || val > g_iFOVUpper)
    && !CheckCommandAccess(client, "sm_fov_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_FOV_Usage", client, g_iFOVLower, g_iFOVUpper);
      return Plugin_Handled;
    }
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow Spectator, Not Replay/SourceTV
      SetFOV(targ_list[i], val, isDefault);
  }

  if(isDefault)
    TagActivity2(client, "%T", "SM_FOV_Done_Server_Default", LANG_SERVER, targ_name);
  else
    TagActivity2(client, "%T", "SM_FOV_Done_Server", LANG_SERVER, targ_name, val);
  return Plugin_Handled;
}

// TODO Is there a better way to do this?
stock void SetFOV(int iClient, int iVal, bool bDefault)
{
  if(bDefault)
  {
    // Safe to use value immediately, it's set OnClientPutInServer
    SetEntProp(iClient, Prop_Send, "m_iFOV", g_iFOVDesired[iClient]);
    SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", g_iFOVDesired[iClient]);
  }
  else
  {
    QueryClientConVar(iClient, "fov_desired", OnGetDesiredFOV);
    SetEntProp(iClient, Prop_Send, "m_iFOV", iVal);
    SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iVal);
    // TODO What is defaultfov for? Is it used when spawning?
  }
  return;
}

public void OnGetDesiredFOV(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
  g_iFOVDesired[client] = StringToInt(cvarValue);
  return;
}
#endif



/**
 * AAAAAAAAAAAAAAAAAAHH!
 *
 * sm_scream [Target]
 */
#if defined _INCLUDE_SCREAM
public Action CMD_Scream(int client, int args)
{
  if(g_bDisabledCmds[ComSCREAM])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(!g_bScreamEnabled && !CheckCommandAccess(client, "sm_scream_nolock", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SM_SCREAM_Disabled", client);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    if(IsClientPlaying(client))
      PlayerScream(client);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_scream_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  //Get Target
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
      PlayerScream(targ_list[i]);
  }

  return Plugin_Handled;
}

stock void PlayerScream(int client)
{
  SetVariantString("HalloweenLongFall");
  AcceptEntityInput(client, "SpeakResponseConcept", -1, -1, 0);
}



/**
 * Toggle Server-wide Access to sm_scream.
 *
 * sm_screamtoggle [1/0]
 */
public Action CMD_ScreamToggle(int client, int args)
{
  if(g_bDisabledCmds[ComSCREAMTOGGLE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
    g_bScreamEnabled = !g_bScreamEnabled;
  else
  {
    char arg1[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_SCREAMTOGGLE_Usage", client);
      return Plugin_Handled;
    }
    g_bScreamEnabled = view_as<bool>(state);
  }

  if(g_bScreamEnabled)
    TagActivity2(client, "%T", "SM_SCREAMTOGGLE_Enable", LANG_SERVER);
  else
    TagActivity2(client, "%T", "SM_SCREAMTOGGLE_Disable", LANG_SERVER);

  return Plugin_Handled;
}
#endif // _INCLUDE_SCREAM



/**
 * Change the pitch of a player's voicelines
 *
 * sm_pitch [Target] <1-255 or 100/default/reset>
 */
#if defined _INCLUDE_PITCH
public Action CMD_Pitch(int client, int args)
{
  if(g_bDisabledCmds[ComPITCH])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(!g_bPitchEnabled && !CheckCommandAccess(client, "sm_pitch_nolock", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SM_PITCH_Disabled", client);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_PITCH_Usage", client, g_iPitchLower, g_iPitchUpper);
    return Plugin_Handled;
  }

  int val;
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(StrEqual(arg1, "reset", false)
    || StrEqual(arg1, "default", false)
    || StrEqual(arg1, "100", true))
    {
      g_iPitch[client] = PITCH_DEFAULT;
      TagReply(client, "%T", "SM_PITCH_Done_Default", client);
      return Plugin_Handled;
    }

    val = StringToInt(arg1);
    if((val < g_iPitchLower || val > g_iPitchUpper)
    && !CheckCommandAccess(client, "sm_pitch_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_PITCH_Usage", client, g_iPitchLower, g_iPitchUpper);
      return Plugin_Handled;
    }

    if(val < 1 || val > 255)
    {
      TagReply(client, "%T", "SM_PITCH_Limit", client);
      return Plugin_Handled;
    }

    g_iPitch[client] = val;
    TagReply(client, "%T", "SM_PITCH_Done", client, val);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_pitch_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  // Get Value
  bool isDefault = false;
  char arg2[5];
  GetCmdArg(2, arg2, sizeof(arg2));

  if(StrEqual(arg2, "reset", false)
  || StrEqual(arg2, "default", false)
  || StrEqual(arg2, "100", true))
  {
    val = PITCH_DEFAULT;
    isDefault = true;
  }
  else
  {
    val = StringToInt(arg2);
    if((val < g_iPitchLower || val > g_iPitchUpper)
    && !CheckCommandAccess(client, "sm_pitch_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_PITCH_Usage", client, g_iPitchLower, g_iPitchUpper);
      return Plugin_Handled;
    }

    if(val < 1 || val > 255)
    {
      TagReply(client, "%T", "SM_PITCH_Limit", client);
      return Plugin_Handled;
    }
  }

  // Get Target
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Target and Val ready, Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
      g_iPitch[targ_list[i]] = val;
  }

  if(isDefault)
    TagActivity2(client, "%T", "SM_PITCH_Done_Server_Default", LANG_SERVER, targ_name);
  else
    TagActivity2(client, "%T", "SM_PITCH_Done_Server", LANG_SERVER, targ_name, val);


  return Plugin_Handled;
}



/**
 * Toggle Server-wide Access to sm_pitch
 *
 * sm_pitchtoggle [1/0]
 */
public Action CMD_PitchToggle(int client, int args)
{
  if(g_bDisabledCmds[ComPITCHTOGGLE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
    g_bPitchEnabled = !g_bPitchEnabled;
  else
  {
    char arg1[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_PITCHTOGGLE_Usage", client);
      return Plugin_Handled;
    }
    g_bPitchEnabled = view_as<bool>(state);
  }

  if(g_bPitchEnabled)
    TagActivity2(client, "%T", "SM_PITCHTOGGLE_Enable", LANG_SERVER);
  else
    TagActivity2(client, "%T", "SM_PITCHTOGGLE_Disable", LANG_SERVER);

  return Plugin_Handled;
}
#endif


/**
 * Execute a taunt by specifiying the item index.
 *
 * sm_tauntid [Target] <Taunt Item Index>
 * Requires satansfunpack_toybox.cfg and gamedata file
 * Will only accept taunt IDs in that file
 */
#if defined _INCLUDE_TAUNTS
public Action CMD_TauntById(int client, int args)
{
  if(g_bDisabledCmds[ComTAUNTID])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_TAUNTBYID_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  int tauntIdx, globalIndex;

  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    tauntIdx = StringToInt(arg1);
    globalIndex = IsTauntIndexValid(tauntIdx);

    if(globalIndex == -1)
    {
      TagReply(client, "%T", "SM_TAUNTBYID_Invalid", client, tauntIdx);
      return Plugin_Handled;
    }

    if(g_TauntClass[globalIndex] != TFAllClass
      && TF2_GetPlayerClass(client) != view_as<TFClassType>(g_TauntClass[globalIndex]))
    {
      switch(g_TauntClass[globalIndex])
      {
        case TFScout:   TagReply(client, "%T", "SM_TAUNTBYID_Scout",    client);
        case TFSoldier: TagReply(client, "%T", "SM_TAUNTBYID_Soldier",  client);
        case TFPyro:    TagReply(client, "%T", "SM_TAUNTBYID_Pyro",     client);
        case TFDemoman: TagReply(client, "%T", "SM_TAUNTBYID_Demoman",  client);
        case TFHeavy:   TagReply(client, "%T", "SM_TAUNTBYID_Heavy",    client);
        case TFEngie:   TagReply(client, "%T", "SM_TAUNTBYID_Engineer", client);
        case TFMedic:   TagReply(client, "%T", "SM_TAUNTBYID_Medic",    client);
        case TFSniper:  TagReply(client, "%T", "SM_TAUNTBYID_Sniper",   client);
        case TFSpy:     TagReply(client, "%T", "SM_TAUNTBYID_Spy",      client);
      }
      return Plugin_Handled;
    }

    ExecuteTaunt(client, tauntIdx);

    // Clean name by splitting at ") "
    // This is added during LoadConfig so it's safe.
    int cleanNameIdx = StrContains(g_szTauntName[globalIndex], ") ", true);
    if(cleanNameIdx != -1)
      TagReply(client,
        "%T",
        "SM_TAUNTBYID_Done_Self",
        client,
        g_szTauntName[globalIndex][cleanNameIdx+2], // +2 to remove ") "
        tauntIdx);
    return Plugin_Handled;
  }

  // Check targeting
  if(!CheckCommandAccess(client, "sm_tauntid_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[16];
  GetCmdArg(2, arg2, sizeof(arg2));
  tauntIdx = StringToInt(arg2);
  globalIndex = IsTauntIndexValid(tauntIdx);

  if(globalIndex == -1)
  {
    TagReply(client, "%T", "SM_TAUNTBYID_Invalid", client, tauntIdx);
    return Plugin_Handled;
  }

  // Get Target
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
    {
      if(g_TauntClass[globalIndex] == TFAllClass
      || TF2_GetPlayerClass(targ_list[i]) == view_as<TFClassType>(g_TauntClass[globalIndex]))
      {
        ExecuteTaunt(targ_list[i], tauntIdx);
      }
    }
  }

  // Clean name by splitting at ") "
  // This is added during LoadConfig so it's safe.
  int cleanNameIdx = StrContains(g_szTauntName[globalIndex], ") ", true);
  if(cleanNameIdx != -1)
    TagActivity2(
      client,
      "%T",
      "SM_TAUNTBYID_Done",
      LANG_SERVER,
      targ_name,
      g_szTauntName[globalIndex][cleanNameIdx+2], // +2 to remove ") "
      tauntIdx);
  return Plugin_Handled;
}

/**
 * Check if Taunt Index is in g_iTauntId
 * Return g_iTauntId index or -1 on failure
 */
int IsTauntIndexValid(int itemIndex)
{
  int found = -1;
  for(int i = 0; i < g_iTauntCount; ++i)
  {
    if(g_iTauntId[i] == itemIndex)
    {
      found = i;
      break;
    }
  }
  return found;
}

/**
 * Open a menu with a list of taunts, select to use.
 *
 * sm_taunt or sm_taunts
 * Requires satansfunpack_toybox.cfg and gamedata file
 */
public Action CMD_TauntMenu(int client, int args)
{
  if(g_bDisabledCmds[ComTAUNTMENU])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args > 0)
  {
    // TODO Merge sm_taunt and sm_tauntid
    TagReply(client, "%T", "SM_TAUNTMENU_TryTauntID", client);
    return Plugin_Handled;
  }

  Menu menu = new Menu(TauntMenuHandler,
    MenuAction_End|MenuAction_Display|MenuAction_DrawItem|MenuAction_Select);
  SetMenuTitle(menu, "Taunt Menu"); // Translated in handler

  for(int i = 0; i < g_iTauntCount; ++i)
  {
    char buffer[4];
    IntToString(i, buffer, sizeof(buffer));
    AddMenuItem(menu, buffer, g_szTauntName[i]);
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return Plugin_Handled;
}

public int TauntMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_End:
    {
      delete menu;
    }

    case MenuAction_Display:
    {
      // Client Translation: p1 = client, p2 = menu
      char buffer[64];
      Format(buffer, sizeof(buffer), "%T", "SM_TAUNTMENU_Title", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }

    case MenuAction_DrawItem:
    {
      // Disable Incompatible Taunts: p1 = client, p2 = menuitem
      int style;
      char info[4];
      GetMenuItem(menu, param2, info, sizeof(info), style);
      int index = StringToInt(info); // This should never fail since it's set by loop.

      if(!ClientClassMatchesTaunt(param1, index))
        return ITEMDRAW_IGNORE;
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[4];
      GetMenuItem(menu, param2, info, sizeof(info));
      int index = StringToInt(info); // Shouldn't ever fail

      // In case they change class after opening menu
      if(ClientClassMatchesTaunt(param1, index))
      {
        switch(ExecuteTaunt(param1, g_iTauntId[index]))
        {
          case -1: TagPrintChat(param1, "%T", "SM_TAUNTMENU_EntFail", param1);
          case -2: TagPrintChat(param1, "%T", "SM_TAUNTMENU_AddressFail", param1);
          // Don't say anything if it succeeds.
        }
      }
      else
        TagReply(param1, "%T", "SM_TAUNTMENU_BadClass", param1);
    }
  }
  return 0;
}

/**
 * Execute Taunt on Client by giving them...some item.
 * Returns -1 on invalid item, -2 on invalid address.
 */
stock int ExecuteTaunt(int client, int tauntIndex)
{
  static Handle hItem;
  hItem = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);

  TF2Items_SetClassname(hItem, "tf_wearable_vm");
  TF2Items_SetQuality(hItem, 6);
  TF2Items_SetLevel(hItem, 1);
  TF2Items_SetNumAttributes(hItem, 0);
  TF2Items_SetItemIndex(hItem, tauntIndex);

  int ent = TF2Items_GiveNamedItem(client, hItem);
  if(!IsValidEntity(ent))
  	return -1;

  // Get EconItemView of the taunt. Whatever that is.
  Address pEconItemView = GetEntityAddress(ent)
  + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
  if(pEconItemView == Address_Null)
    return -2;

  SDKCall(h_SDKPlayTauntScene, client, pEconItemView);
  AcceptEntityInput(ent, "Kill");
  return 0;
}
#endif



/**
 * Play sounds identically to sm_play, but do not indicate to players.
 *
 * sm_splay <Target> <File Path>
 * Code Ripped from Sourcemod's sounds.sp
 */
#if defined _INCLUDE_SPLAY
public Action CMD_StealthPlay(int client, int args)
{
  if(g_bDisabledCmds[ComSPLAY])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if (args < 2)
  {
    TagReplyUsage(client, "%T", "SM_SPLAY_Usage", client);
    return Plugin_Handled;
  }

  char Arguments[PLATFORM_MAX_PATH + 65];
  GetCmdArgString(Arguments, sizeof(Arguments));

  char Arg[65];
  int len = BreakString(Arguments, Arg, sizeof(Arg));

  /* Make sure it does not go out of bound by doing "sm_play user  "*/
  if (len == -1)
  {
    TagReplyUsage(client, "%T", "SM_SPLAY_Usage", client);
    return Plugin_Handled;
  }

  /* Incase they put quotes and white spaces after the quotes */
  if (Arguments[len] == '"')
  {
    ++len;
    int FileLen = TrimString(Arguments[len]) + len;

    if (Arguments[FileLen - 1] == '"')
    {
      Arguments[FileLen - 1] = '\0';
    }
  }

  // Get Target
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
      Arg,
      client,
      targ_list,
      MAXPLAYERS,
      COMMAND_FILTER_NO_BOTS,
      targ_name,
      sizeof(targ_name),
      tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    if(!IsClientReplay(targ_list[i]) && !IsClientSourceTV(targ_list[i]))
      ClientCommand(targ_list[i], "playgamesound \"%s\"", Arguments[len]);
  }

  LogAction(client, -1, "\"%L\" played stealth-sound on \"%s\" (file \"%s\")", client, targ_name, Arguments[len]);

  return Plugin_Handled;
}
#endif



/**
 * Set a player's colour.
 *
 * sm_colour [Target] <Hex Colour>
 * OR sm_colour [Target] <Red 0-255> <Green 0-255> <Blue 0-255> <Alpha 0-255>
 * You can either have 1/2, or 4/5 args.
 * Both 1 & 4 self target.
 * TODO Check if this works after respawn
 */
#if defined _INCLUDE_COLOUR
public Action CMD_ColourPlayer(int client, int args)
{
  if(g_bDisabledCmds[ComCOLOUR])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1 || args > 5 || args == 3)
  {
    TagReplyUsage(client, "%T", "SM_COLOURSELF_Usage", client);
    return Plugin_Handled;
  }

  // Get minimum required args
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Get Target. Default to client.
  bool bSelfTarget = false;
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if(args == 2 || args == 4) // Either 8-Hex or RGBA, with target specified
  {
    if(!CheckCommandAccess(client, "sm_colour_target", ADMFLAG_BAN, true))
    {
      TagReply(client, "%T", "SFP_NoTargeting", client);
      return Plugin_Handled;
    }

    if ((targ_count = ProcessTargetString(
      arg1,
      client,
      targ_list,
      MAXPLAYERS,
      COMMAND_FILTER_ALIVE,
      targ_name,
      sizeof(targ_name),
      tn_is_ml)) <= 0)
    {
      ReplyToTargetError(client, targ_count);
      return Plugin_Handled;
    }
  }
  else // No target, set to client
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    targ_count = 1;
    targ_list[0] = client;
    GetClientName(client, targ_name, sizeof(targ_name));
    bSelfTarget = true;
  }

  // Get Colour
  int iRed, iGreen, iBlue, iAlpha;
  char arg2[9], arg3[4], arg4[4], arg5[4]; // Arg2 can be 8 or 3-digits, 3, 4 & 5 are only 3.


  if(args == 1)       // arg1:8-Digit Hex
  {
    if(!HexToRGBA(arg1, iRed, iGreen, iBlue, iAlpha))
    {
      TagReply(client, "%T", "SFP_Bad8DigitHexColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 2)  // arg1:Target, arg2:8-Digit Hex
  {
    GetCmdArg(2, arg2, sizeof(arg2));

    if(!HexToRGBA(arg2, iRed, iGreen, iBlue, iAlpha))
    {
      TagReply(client, "%T", "SFP_Bad8DigitHexColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 4)  // arg1-4:RGBA
  {
    GetCmdArg(2, arg2, sizeof(arg2));
    GetCmdArg(3, arg3, sizeof(arg3));
    GetCmdArg(4, arg4, sizeof(arg4));

    iRed    = StringToInt(arg1);
    iGreen  = StringToInt(arg2);
    iBlue   = StringToInt(arg3);
    iAlpha  = StringToInt(arg4);
    if(!IsColourRGBA(iRed, iGreen, iBlue, iAlpha))
    {
      TagReply(client, "%T", "SFP_BadRGBAColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 5)  // arg1:Target, arg2-5:RGBA
  {
    GetCmdArg(2, arg2, sizeof(arg2));
    GetCmdArg(3, arg3, sizeof(arg3));
    GetCmdArg(4, arg4, sizeof(arg4));
    GetCmdArg(5, arg5, sizeof(arg5));

    iRed    = StringToInt(arg2);
    iGreen  = StringToInt(arg3);
    iBlue   = StringToInt(arg4);
    iAlpha  = StringToInt(arg5);
    if(!IsColourRGBA(iRed, iGreen, iBlue, iAlpha))
    {
      TagReply(client, "%T", "SFP_BadRGBAColour", client);
      return Plugin_Handled;
    }
  }


  bool bDefault = false;
  if(iRed == 255 && iGreen == 255 && iBlue == 255 && iAlpha == 255)
    bDefault = true;

  // Target and Colour Ready. Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
    {
      SetEntityRenderColor(targ_list[i], iRed, iGreen, iBlue, iAlpha);
      if(bDefault)
        SetEntityRenderMode(targ_list[i], RENDER_NORMAL);
      else
        SetEntityRenderMode(targ_list[i], RENDER_TRANSALPHA);
    }
  }

  if(bSelfTarget)
    TagReply(client, "%T", "SM_COLOURSELF_Done", client, iRed, iGreen, iBlue, iAlpha);
  else
  {
    TagActivity2(client, "%T", "SM_COLOURSELF_Done_Server", LANG_SERVER,
      targ_name,
      iRed,
      iGreen,
      iBlue,
      iAlpha);
  }
  return Plugin_Handled;
}
#endif



/**
 * Set a player's sentry to deal no damage.
 * TODO Add godmode too?
 * sm_friendlysentry [Target] <1/0>
 */
#if defined _INCLUDE_FRIENDLYSENTRY
public Action CMD_FriendlySentry(int client, int args)
{
  if(g_bDisabledCmds[ComFRIENDLYSENTRY])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_FRIENDSENTRY_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Self Target
  if(args == 1)
  {
    if(!IsClientPlaying(client, true)) // Allow Spectators
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_FRIENDSENTRY_Usage", client);
      return Plugin_Handled;
    }

    g_bFriendlySentry[client] = view_as<bool>(state);

    if(state)
      TagReply(client, "%T", "SM_FRIENDSENTRY_Enable_Self", client);
    else
      TagReply(client, "%T", "SM_FRIENDSENTRY_Disable_Self", client);
    return Plugin_Handled;
  }

  // Other Target
  if(!CheckCommandAccess(client, "sm_friendlysentry_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(2, arg2, sizeof(arg2));

  int state = GetStringBool(arg2, false, true, true, true);
  if(state == -1)
  {
    TagReplyUsage(client, "%T", "SM_FRIENDSENTRY_Usage", client);
    return Plugin_Handled;
  }

  // Get Target
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0, // Allow bots and observers, only takes effect if you build a sentry
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
    g_bFriendlySentry[targ_list[i]] = view_as<bool>(state);

  if(state)
    TagActivity2(client, "%T", "SM_FRIENDSENTRY_Enable", LANG_SERVER, targ_name);
  else
    TagActivity2(client, "%T", "SM_FRIENDSENTRY_Disable", LANG_SERVER, targ_name);

  return Plugin_Handled;
}
#endif



/**
 * Slap a player and optionally play a custom sound file and/or print a message.
 *
 * sm_cslap <Target>
 * TODO Add sound file and message override.
 * TODO Add colours for config.
 * TODO Add different message styles (hint, center, etc.).
 * TODO Add damage option?
 */
#if defined _INCLUDE_CUSTOMSLAP
public Action CMD_CustomSlap(int client, int args)
{
  if(g_bDisabledCmds[ComCSLAP])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_CSLAP_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Get Target
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    if(!IsClientPlaying(targ_list[i])) // This also checks alive state, but other things too.
      continue;

    SlapPlayer(targ_list[i], 0, true); // Bots can be slapped

    if(!IsFakeClient(targ_list[i]))
    {
      if(g_bSlapUseSound)
        ClientCommand(targ_list[i], "playgamesound \"%s\"", g_szSlapSound);
      if(g_bSlapUseMsg)
        PrintToChat(targ_list[i], "%s", g_szSlapMsg);
    }
  }
  return Plugin_Handled;
}
#endif



//=================================
// Config File
// TODO Better logging of errors for LoadConfig

/**
 * Runs LoadConfig manually.
 *
 * sm_toybox_reloadcfg
 */
public Action CMD_ConfigReload(int client, int args)
{
  bool result = LoadConfig();
  if(result)
    TagReply(client, "%T", "SFP_ConfigReload_Success", client);
  else
    TagReply(client, "%T", "SFP_ConfigReload_Fail", client, "sfp_toybox");
  return Plugin_Handled;
}

stock bool LoadConfig()
{
  if(!FileExists(g_szConfig))
  {
    SetFailState("%T", "SFP_NoConfig", LANG_SERVER, g_szConfig);
    return false;
  }

  // Create and check KeyValues
  KeyValues hKeys = CreateKeyValues("SatansToyBox"); // Requires Manual Delete
  if(!FileToKeyValues(hKeys, g_szConfig))
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfig", LANG_SERVER, g_szConfig);
    return false;
  }

  if(!hKeys.GotoFirstSubKey())
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfigSubKey", LANG_SERVER, g_szConfig);
    return false;
  }

  // Reset Traversal to root node
  hKeys.Rewind();

  /**
   * Load Taunts
   */
  #if defined _INCLUDE_TAUNTS
  if(hKeys.JumpToKey("SFPTaunts", false))
  {
    if(!hKeys.GotoFirstSubKey())
      PrintToServer("%T", "SM_TAUNTMENU_NoTaunts", LANG_SERVER);
    else
    {
      // Zero out Globals
      for(int i = 0; i < MAX_TAUNTS; ++i)
      {
        g_szTauntName[i]  = "";
        g_iTauntId[i]     = 0;
        g_TauntClass[i]   = TFInvalid;
      }
      g_iTauntCount = 0;

      int skipCount = 0;
      do
      {
        // Get Class, check it's valid. If not, skip taunt.
        char className[8];
        TFClasses tfClass;
        hKeys.GetString("class", className, sizeof(className));
        if(StrEqual(className, "ANY", true))
          tfClass = TFAllClass;
        else if(StrEqual(className, "SCOUT", true))
          tfClass = TFScout;
        else if(StrEqual(className, "SOLDIER", true))
          tfClass = TFSoldier;
        else if(StrEqual(className, "PYRO", true))
          tfClass = TFPyro;
        else if(StrEqual(className, "DEMO", true))
          tfClass = TFDemoman;
        else if(StrEqual(className, "HEAVY", true))
          tfClass = TFHeavy;
        else if(StrEqual(className, "ENGIE", true))
          tfClass = TFEngie;
        else if(StrEqual(className, "MEDIC", true))
          tfClass = TFMedic;
        else if(StrEqual(className, "SNIPER", true))
          tfClass = TFSniper;
        else if(StrEqual(className, "SPY", true))
          tfClass = TFSpy;
        else
        {
          ++skipCount;
          continue;
        }

        // Check ID
        char buff[32];
        hKeys.GetString("id", buff, sizeof(buff));
        int idBuff = StringToInt(buff);
        if(idBuff < 1 || idBuff > MAX_TAUNTID_INT)
        {
          ++skipCount;
          continue;
        }

        // Class and ID are Valid, Add taunt and increment
        g_iTauntId[g_iTauntCount]   = idBuff;
        g_TauntClass[g_iTauntCount] = tfClass;

        // Menu-Ready name string: "(ANY) Some Taunt"
        // NOTE g_szTauntName must store ") " before the name to work with sm_tauntid
        hKeys.GetSectionName(buff, sizeof(buff));
        Format(g_szTauntName[g_iTauntCount], sizeof(g_szTauntName[]), "(%s) %s", className, buff);

        ++g_iTauntCount; // Only increment after use/adding to a fixed array or you get 'holes'
      }
      while(hKeys.GotoNextKey() && g_iTauntCount < MAX_TAUNTS);

      PrintToServer("%T", "SM_TAUNTMENU_ConfigLoad", LANG_SERVER, g_iTauntCount, skipCount);
    }
  }
  else
    PrintToServer("%T", "SFP_NoConfigKey", LANG_SERVER, "SFPTaunts");
  #endif

  delete hKeys;
  return true;
}


stock bool ClientClassMatchesTaunt(int client, int tauntIndex)
{
  if(g_TauntClass[tauntIndex] == TFAllClass)
    return true;

  switch(TF2_GetPlayerClass(client))
  {
    case TFClass_Scout:     return (g_TauntClass[tauntIndex] != TFScout)    ? false : true;
    case TFClass_Sniper:    return (g_TauntClass[tauntIndex] != TFSniper)   ? false : true;
    case TFClass_Soldier:   return (g_TauntClass[tauntIndex] != TFSoldier)  ? false : true;
    case TFClass_DemoMan:   return (g_TauntClass[tauntIndex] != TFDemoman)  ? false : true;
    case TFClass_Medic:     return (g_TauntClass[tauntIndex] != TFMedic)    ? false : true;
    case TFClass_Heavy:     return (g_TauntClass[tauntIndex] != TFHeavy)    ? false : true;
    case TFClass_Pyro:      return (g_TauntClass[tauntIndex] != TFPyro)     ? false : true;
    case TFClass_Spy:       return (g_TauntClass[tauntIndex] != TFSpy)      ? false : true;
    case TFClass_Engineer:  return (g_TauntClass[tauntIndex] != TFEngie)    ? false : true;
  }
  return false;
}



//=================================
// Updater
public void OnConfigsExecuted()
{
  if(LibraryExists("updater") && g_bUpdate)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryAdded(const char[] name)
{
  if(StrEqual(name, "updater") && g_bUpdate)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryRemoved(const char[] name)
{
  if(StrEqual(name, "updater"))
    Updater_RemovePlugin();
  return;
}
