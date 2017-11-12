#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL  "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL  "https://sirdigbot.github.io/SatansFunPack/sourcemod/admintools_update.txt"

// List of commands that can be disabled.
// Set by CVar, updated in ProcessDisabledCmds, Checked in Command.
enum CommandNames {
  ComCCOM,
  ComTBAN,
  ComADDCOND,
  ComREMCOND,
  ComDISARM,
  ComSWITCHTEAM,
  ComFORCESPEC,
  ComFSAYALL,
  ComFSAYTEAM,
  ComNAMELOCK,
  ComNOTARGET,
  ComOUTLINE,
  ComTELELOCK,
  ComOPENTELE,
  ComFORCECLASS, // Affects both sm_forceclass and sm_unlockclass
  ComSETHEALTH,
  ComTOTAL
};


//=================================
// Globals
Handle  h_bUpdate     = null;
bool    g_bUpdate;
Handle  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];

Handle  h_iTempBanMax = null;
int     g_iTempBanMax;
bool    g_bNoTarget[MAXPLAYERS + 1];
bool    g_bOutline[MAXPLAYERS + 1];
bool    g_bTeleLock[MAXPLAYERS + 1];
bool    g_bOpenTele[MAXPLAYERS + 1];
bool    g_bForceClassLocked[MAXPLAYERS + 1];

/**
 * Known Bugs:
 * - TODO OpenTele and Telelock should indicate the tele is different.
 * - TODO Force-class lock can possibly cause a crash if used with a class-limit.
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Admin Tools",
  author =      "SirDigby",
  description = "Commands For Admins to Use",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};



//=================================
// Forwards/Events

public APLRes AskPluginLoad2(Handle self, bool late, char[] err, int err_max)
{
  EngineVersion engine = GetEngineVersion();
  if(engine != Engine_TF2)
  {
    Format(err, err_max, "%T", "SFP_Incompatible", LANG_SERVER);
    return APLRes_Failure;
  }
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  LoadTranslations("sfp.admintools.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");


  h_bUpdate = CreateConVar("sm_sfp_admintools_update", "1", "Update Satan's Fun Pack - AdminTools Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_bDisabledCmds = CreateConVar("sm_admintools_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- CCom\n- TBan\n- AddCond\n- RemCond\n- Disarm\n- SwitchTeam\n- ForceSpec\n- FSayAll\n- FSayTeam\n- NameLock\n- NoTarget\n- Outline\n- TeleLock\n- OpenTele\n- ForceClass\n- SetHealth", FCVAR_SPONLY|FCVAR_REPLICATED);
  ProcessDisabledCmds();
  HookConVarChange(h_bDisabledCmds, UpdateCvars);

  h_iTempBanMax = CreateConVar("sm_maxtempban", "180", "Max Length Of Temporary Ban\n(Default: 180)", FCVAR_NONE, true, 0.0, false);
  g_iTempBanMax = GetConVarInt(h_iTempBanMax);
  HookConVarChange(h_iTempBanMax, UpdateCvars);

  HookEvent("player_spawn",       OnPlayerSpawn,        EventHookMode_Post);
  HookEvent("player_changeclass", OnPlayerChangeClass,  EventHookMode_Pre);

  RegAdminCmd("sm_ccom",        CMD_ClientCmd, ADMFLAG_ROOT, "Force Player to Use a Command");
  RegAdminCmd("sm_tban",        CMD_TempBan, ADMFLAG_BAN, "Ban Players. Temporarily");
  RegAdminCmd("sm_addcond",     CMD_AddCond, ADMFLAG_BAN, "Add a Condition to a Player");
  RegAdminCmd("sm_remcond",     CMD_RemCond, ADMFLAG_BAN, "Remove a Condition from a Player");
  RegAdminCmd("sm_removecond",  CMD_RemCond, ADMFLAG_BAN, "Remove a Condition from a Player");
  RegAdminCmd("sm_disarm",      CMD_Disarm, ADMFLAG_BAN, "Strip Weapons from a Player");
  RegAdminCmd("sm_switchteam",  CMD_SwitchTeam, ADMFLAG_BAN, "Force Player to switch Teams");
  RegAdminCmd("sm_forcespec",   CMD_ForceSpec, ADMFLAG_BAN, "Force Player into Spectator");
  RegAdminCmd("sm_fsay",        CMD_FakeSay, ADMFLAG_BAN, "I didn't say that, I swear!");
  RegAdminCmd("sm_fsayteam",    CMD_FakeSayTeam, ADMFLAG_BAN, "I didn't say that, I swear!");
  RegAdminCmd("sm_namelock",    CMD_NameLock, ADMFLAG_BAN, "Prevent a Player from Changing Names");
  RegAdminCmd("sm_notarget",    CMD_NoTarget, ADMFLAG_BAN, "Disable Sentry Targeting on a Player");
  RegAdminCmd("sm_outline",     CMD_Outline, ADMFLAG_BAN, "Set Outline Effect on a Player");
  RegAdminCmd("sm_telelock",    CMD_TeleLock, ADMFLAG_BAN, "Lock teleporters from other Players");
  RegAdminCmd("sm_opentele",    CMD_OpenTele, ADMFLAG_BAN, "Allow Enemies Through Your Teleporter");
  RegAdminCmd("sm_forceclass",  CMD_ForceClass, ADMFLAG_BAN, "Force a Player to a Certain Class");
  RegAdminCmd("sm_unlockclass", CMD_UnlockClass, ADMFLAG_BAN, "Unlock a Player from sm_forceclass");
  RegAdminCmd("sm_hp",          CMD_SetHealth, ADMFLAG_BAN, "Set a Player's Health");

  /**
   * Overrides
   * sm_addcond_target  - Can client target others with sm_addcond
   * sm_remcond_target  - Can client target others with sm_remcond
   * sm_notarget_target - Can client target others with sm_notarget
   * sm_outline_target  - Can client target others wtih sm_outline
   * sm_telelock_target - Can client target others with sm_telelock
   * sm_opentele_target - Can client target others with sm_opentele
   * sm_forceclass_canlock - Can lock a player into a class with sm_forceclass
   * sm_sethealth_target - Can client target others with sm_hp
   */

  PrintToServer("%T", "SFP_AdminToolsLoaded", LANG_SERVER);
}


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_iTempBanMax)
    g_iTempBanMax = StringToInt(newValue);
  else if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_bDisabledCmds)
    ProcessDisabledCmds();
  return;
}


/**
 * Set Enable/Disable state for every command from CVar
 */
void ProcessDisabledCmds()
{
  for(int i = 0; i < view_as<int>(ComTOTAL); ++i)
    g_bDisabledCmds[i] = false;

  char buffer[300]; // TODO get proper size
  GetConVarString(h_bDisabledCmds, buffer, sizeof(buffer));
  if(StrContains(buffer, "CCom", true) != -1)
    g_bDisabledCmds[ComCCOM] = true;

  if(StrContains(buffer, "TBan", true) != -1)
    g_bDisabledCmds[ComTBAN] = true;

  if(StrContains(buffer, "AddCond", true) != -1)
    g_bDisabledCmds[ComADDCOND] = true;

  if(StrContains(buffer, "RemCond", true) != -1)
    g_bDisabledCmds[ComREMCOND] = true;

  if(StrContains(buffer, "Disarm", true) != -1)
    g_bDisabledCmds[ComDISARM] = true;

  if(StrContains(buffer, "SwitchTeam", true) != -1)
    g_bDisabledCmds[ComSWITCHTEAM] = true;

  if(StrContains(buffer, "ForceSpec", true) != -1)
    g_bDisabledCmds[ComFORCESPEC] = true;

  if(StrContains(buffer, "FSayAll", true) != -1)
    g_bDisabledCmds[ComFSAYALL] = true;

  if(StrContains(buffer, "FSayTeam", true) != -1)
    g_bDisabledCmds[ComFSAYTEAM] = true;

  if(StrContains(buffer, "NameLock", true) != -1)
    g_bDisabledCmds[ComNAMELOCK] = true;

  if(StrContains(buffer, "NoTarget", true) != -1)
    g_bDisabledCmds[ComNOTARGET] = true;

  if(StrContains(buffer, "Outline", true) != -1)
    g_bDisabledCmds[ComOUTLINE] = true;

  if(StrContains(buffer, "TeleLock", true) != -1)
    g_bDisabledCmds[ComTELELOCK] = true;

  if(StrContains(buffer, "OpenTele", true) != -1)
    g_bDisabledCmds[ComOPENTELE] = true;

  if(StrContains(buffer, "ForceClass", true) != -1)
    g_bDisabledCmds[ComFORCECLASS] = true;

  if(StrContains(buffer, "SetHealth", true) != -1)
    g_bDisabledCmds[ComSETHEALTH] = true;
  return;
}

public Action OnPlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
  if(client >= 1)
  {
    if(g_bOutline[client])
    {
      SetOutline(client, true);
      TagPrintChat(client, "%T", "SM_OUTLINE_SpawnMsg", client);
    }
    if(g_bNoTarget[client])
    {
      SetNoTarget(client, true);
      TagPrintChat(client, "%T", "SM_NOTARGET_SpawnMsg", client);
    }
  }
  return Plugin_Continue;
}

public Action OnPlayerChangeClass(Handle event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
  if(client >= 1)
  {
    if(g_bForceClassLocked[client])
    {
      TFClassType current = TF2_GetPlayerClass(client);
      TF2_SetPlayerClass(client, current, false, true); // TODO Verify it works
    }
  }
}


public void OnClientDisconnect_Post(int client)
{
  g_bOutline[client] = false;
  g_bNoTarget[client] = false;
  g_bTeleLock[client] = false;
  g_bOpenTele[client] = false;
  g_bForceClassLocked[client] = false;
  return;
}


public Action TF2_OnPlayerTeleport(int client, int teleporter, bool &result)
{
  int iOwner = GetEntPropEnt(teleporter, Prop_Send, "m_hBuilder");

  if(iOwner < 1 || iOwner > MaxClients) // TODO: Does this work against RTD?
    return Plugin_Continue;

  // Tele-Lock. Takes precedence so you can still lock open-teles
  if(g_bTeleLock[iOwner])
  {
    if(client != iOwner)
    {
      result = false;
      return Plugin_Changed;
    }
  }

  // Open-Tele - Always allow teleports.
  if(g_bOpenTele[iOwner])
  {
    result = true;
    return Plugin_Changed;
  }
  return Plugin_Continue;
}




//=================================
// Commands

/**
 * Force a client to run a console command.
 *
 * sm_ccom <Target> <Command>
 */
public Action CMD_ClientCmd(int client, int args)
{
  if(g_bDisabledCmds[ComCCOM])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_CCOM_Usage", client);
    return Plugin_Handled;
  }

  // Process Args
  char arg1[MAX_NAME_LENGTH], argFull[256];
  GetCmdArgString(argFull, sizeof(argFull));

  int arg2Idx = BreakString(argFull, arg1, sizeof(arg1));
  if(arg2Idx == -1)
  {
    TagReplyUsage(client, "%T", "SM_CCOM_Usage", client);
    return Plugin_Handled;
  }

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0, // Works on bots
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Run Client Command
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true))
      FakeClientCommandEx(targ_list[i], argFull[arg2Idx]);
  }

  TagReply(client, "%T", "SM_CCOM_Done", client, targ_name, argFull[arg2Idx]);
  return Plugin_Handled;
}



/**
 * Ban a player normally, but limit the duration to a cvar value.
 *
 * sm_tban <Target> <Duration> [Reason]
 */
public Action CMD_TempBan(int client, int args)
{
  if(g_bDisabledCmds[ComTBAN])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_TBAN_Usage", client);
    return Plugin_Handled;
  }

  // Process args
  char arg1[MAX_NAME_LENGTH], arg2[16], argFull[256];
  GetCmdArgString(argFull, sizeof(argFull));

  int argIndex = BreakString(argFull, arg1, sizeof(arg1));
  int buffer = BreakString(argFull[argIndex], arg2, sizeof(arg2));

  // Check for 3rd arg/reason, get index if any
  if(buffer == -1)
    argIndex = -1;
  else
    argIndex += buffer;

  // Check Args
  int duration = StringToInt(arg2);
  if (duration < 1 || duration > g_iTempBanMax)
  {
    TagReply(client, "%T", "SM_TBAN_BadTime", client, g_iTempBanMax);
    return Plugin_Handled;
  }

  int target = FindTarget(client, arg1, true); // Single target, no bots
  if(target == -1)
    return Plugin_Handled;

  // Prepare output
  char targ_name[MAX_NAME_LENGTH], reason[256]; // reason > 29 + 192
  GetClientName(target, targ_name, sizeof(targ_name));

  if(argIndex == -1)
  {
    Format(reason, sizeof(reason), "%T",
      "SM_TBAN_Time",
      LANG_SERVER,
      duration);
  }
  else
  {
    Format(reason, sizeof(reason), "%T: %s",
      "SM_TBAN_Time",
      LANG_SERVER,
      duration,
      argFull[argIndex]);
  }

  // Output
  TagActivity(client, "%T", "SM_TBAN_BanMessage",
    LANG_SERVER,
    targ_name,
    duration,
    (argIndex != -1) ? argFull[argIndex] : reason[0]);
    // We don't need "Temporary Ban (3m)" here if there's a reason.

  BanClient(target, duration, BANFLAG_AUTO, reason, reason, "sm_tban", client);
  return Plugin_Handled;
}



/**
 * Add condition to player.
 *
 * sm_addcond [Target] <Condition> <Duration>
 */
public Action CMD_AddCond(int client, int args)
{
  if(g_bDisabledCmds[ComADDCOND])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_ADDCOND_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[16];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));

  int iArg1 = StringToInt(arg1); // iArg1 = TFCond
  int iArg2 = StringToInt(arg2);

  // Process args on self
  if(args == 2)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    // Check arg1, arg2/duration can be negative.
    if(iArg1 < 0)
    {
      TagReply(client, "%T", "SM_ADDCOND_BadCondition", client);
      return Plugin_Handled;
    }

    // Output
    TF2_AddCondition(client, view_as<TFCond>(iArg1), StringToFloat(arg2), 0);
    TagReply(client, "%T", "SM_ADDCOND_Done", client, iArg1);
    return Plugin_Handled;
  }

  // Process args on target player, args is > 2
  if(!CheckCommandAccess(client, "sm_addcond_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg3[16];
  GetCmdArg(3, arg3, sizeof(arg3));

  // Check arg2
  if(iArg2 < 0)
  {
    TagReply(client, "%T", "SM_ADDCOND_BadCondition", client);
    return Plugin_Handled;
  }

  // Get Target List
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

  // Output
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
      TF2_AddCondition(targ_list[i], view_as<TFCond>(iArg2), StringToFloat(arg3), 0);
  }

  TagActivity(client, "%T", "SM_ADDCOND_Done_Server", LANG_SERVER, iArg2, targ_name);
  return Plugin_Handled;
}



/**
 * Remove condition from player.
 *
 * sm_remcond [Target] <Condition>
 */
public Action CMD_RemCond(int client, int args)
{
  if(g_bDisabledCmds[ComREMCOND])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_REMCOND_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));


  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int iArg1 = StringToInt(arg1);

    // Check arg
    if(iArg1 < 0)
    {
      TagReply(client, "%T", "SM_ADDCOND_BadCondition", client);
      return Plugin_Handled;
    }

    TF2_RemoveCondition(client, view_as<TFCond>(iArg1));
    TagReply(client, "%T", "SM_REMCOND_Done", client, iArg1);
    return Plugin_Handled;
  }

  // Other target, args is > 1
  if(!CheckCommandAccess(client, "sm_remcond_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[16];
  GetCmdArg(2, arg2, sizeof(arg2));
  int iArg2 = StringToInt(arg2);

  // Get Target List
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
      TF2_RemoveCondition(targ_list[i], view_as<TFCond>(iArg2));
  }

  TagActivity(client, "%T", "SM_REMCOND_Done_Server", LANG_SERVER, iArg2, targ_name);
  return Plugin_Handled;
}



/**
 * Remove all weapons from a player.
 *
 * TODO: Add toggle capability + Disarm on weapon pickup.
 * sm_disarm <Target>
 */
public Action CMD_Disarm(int client, int args)
{
  if(g_bDisabledCmds[ComDISARM])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_DISARM_Usage", client);
    return Plugin_Handled;
  }

  // Get Target List
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

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
    {
      TF2_RemoveAllWeapons(targ_list[i]);
      TagReply(targ_list[i], "%T", "SM_DISARM_Done", targ_list[i]);
    }
  }

  TagActivity(client, "%T", "SM_DISARM_Done_Server", LANG_SERVER, targ_name);
  return Plugin_Handled;
}



/**
 * Force client to switch teams, or to a specified too.
 *
 * sm_switchteam <Target> [Team Red/Blu/Spec]
 */
public Action CMD_SwitchTeam(int client, int args)
{
  if(g_bDisabledCmds[ComSWITCHTEAM])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_SWITCHTEAM_Usage", client);
    return Plugin_Handled;
  }

  // Check arg2, if any
  TFTeam team = TFTeam_Unassigned;
  if(args > 1)
  {
    char arg2[8];
    GetCmdArg(2, arg2, sizeof(arg2));

    if(StrEqual(arg2, "red", false))
      team = TFTeam_Red;
    else if(StrEqual(arg2, "blu", false)
    || StrEqual(arg2, "blue", false))
    {
      team = TFTeam_Blue;
    }
    else if(StrEqual(arg2, "spec", false)
    || StrEqual(arg2, "spectator", false)
    || StrEqual(arg2, "spectate", false))
    {
      team = TFTeam_Spectator;
    }
  }

  // Get Target List
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
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow specators. Obviously.
    {
      if(team == TFTeam_Unassigned)
        TF2_ChangeClientTeam(targ_list[i], GetClientOtherTeam(targ_list[i]));
      else
        TF2_ChangeClientTeam(targ_list[i], team);
    }
  }

  TagActivity(client, "%T", "SM_SWITCHTEAM_Done", LANG_SERVER, targ_name);
  return Plugin_Handled;
}

TFTeam GetClientOtherTeam(int client)
{
  TFTeam team = TF2_GetClientTeam(client);
  if(team == TFTeam_Red)
    return TFTeam_Blue;
  return TFTeam_Red;
}



/**
 * Force a player into spectator mode.
 *
 * sm_forcespec <Target>
 */
public Action CMD_ForceSpec(int client, int args)
{
  if(g_bDisabledCmds[ComFORCESPEC])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_FORCESPEC_Usage", client);
    return Plugin_Handled;
  }

  // Get Target List
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
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
      TF2_ChangeClientTeam(targ_list[i], TFTeam_Spectator);
  }

  TagActivity(client, "%T", "SM_FORCESPEC_Done", LANG_SERVER, targ_name);
  return Plugin_Handled;
}



/**
 * Force player to say something in chat
 *
 * sm_fsay <Target> <Message>
 */
public Action CMD_FakeSay(int client, int args)
{
  if(g_bDisabledCmds[ComFSAYALL])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_FAKESAY_Usage", client);
    return Plugin_Handled;
  }

  // Get Args
  char argFull[256], arg1[MAX_NAME_LENGTH];
  GetCmdArgString(argFull, sizeof(argFull));
  int msgIndex = BreakString(argFull, arg1, sizeof(arg1));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0, // Works on bots
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow spectators
      FakeClientCommandEx(targ_list[i], "say %s", argFull[msgIndex]);
  }

  // Don't output success since the player will just say the message.
  return Plugin_Handled;
}



/**
 * Force player to say something in teamchat
 *
 * sm_fsayteam <Target> <Message>
 */
public Action CMD_FakeSayTeam(int client, int args)
{
  if(g_bDisabledCmds[ComFSAYTEAM])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_FAKESAYTEAM_Usage", client);
    return Plugin_Handled;
  }

  // Get Args
  char argFull[256], arg1[MAX_NAME_LENGTH];
  GetCmdArgString(argFull, sizeof(argFull));
  int msgIndex = BreakString(argFull, arg1, sizeof(arg1));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0, // Works on bots
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow Spectators
      FakeClientCommandEx(targ_list[i], "say_team %s", argFull[msgIndex]);
  }

  // Don't output success since the player will just say the message.
  return Plugin_Handled;
}



/**
 * Prevent a player from changing their name.
 *
 * sm_namelock <Target> <1/0>
 */
public Action CMD_NameLock(int client, int args)
{
  if(g_bDisabledCmds[ComNAMELOCK])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_NAMELOCK_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
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

  // Apply
  int state = GetStringBool(arg2, false, true, true, true);
  if(state == -1)
  {
    TagReplyUsage(client, "%T", "SM_NAMELOCK_Usage", client);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    int userid = GetClientUserId(targ_list[i]);  // TODO: Do you need to verify IDs
    ServerCommand("namelockid %i %i", userid, state);
  }

  if(state)
    TagActivity(client, "%T", "SM_NAMELOCK_Lock", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_NAMELOCK_Unlock", LANG_SERVER, targ_name);
  return Plugin_Handled;
}



/**
 * Prevent a player from changing their name.
 *
 * sm_notarget [Target] <1/0>
 */
public Action CMD_NoTarget(int client, int args)
{
  if(g_bDisabledCmds[ComNOTARGET])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_NOTARGET_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Self target
  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_NOTARGET_Usage", client);
      return Plugin_Handled;
    }

    // Apply
    g_bNoTarget[client] = (state == 1) ? true : false;
    if(IsPlayerAlive(client))
      SetNoTarget(client, (state == 1) ? true : false);

    if(state == 1)
      TagReply(client, "%T", "SM_NOTARGET_Enable_Self", client);
    else
      TagReply(client, "%T", "SM_NOTARGET_Disable_Self", client);
    return Plugin_Handled;
  }

  // Other target, args is > 1 here.
  if(!CheckCommandAccess(client, "sm_notarget_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0, // Don't filter alive here, we need to set global.
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Check arg2
  int iState = GetStringBool(arg2, false, true, true, true);
  if(iState == -1)
  {
    TagReplyUsage(client, "%T", "SM_NOTARGET_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    g_bNoTarget[targ_list[i]] = view_as<bool>(iState);
    if(IsClientPlaying(targ_list[i], true) && IsPlayerAlive(targ_list[i])) // Allow spectators
      SetNoTarget(targ_list[i], view_as<bool>(iState));
  }

  if(iState)
    TagActivity(client, "%T", "SM_NOTARGET_Enable", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_NOTARGET_Disable", LANG_SERVER, targ_name);
  return Plugin_Handled;
}

// Assumes valid client index
void SetNoTarget(int client, bool state)
{
  int flags = GetEntityFlags(client);
  (state) ? (flags |= FL_NOTARGET) : (flags &= ~FL_NOTARGET);
  SetEntityFlags(client, flags);
  return;
}



/**
 * Adds a glowing outline effect to a player.
 *
 * sm_outline [Target] <1/0>
 */
public Action CMD_Outline(int client, int args)
{
  if(g_bDisabledCmds[ComOUTLINE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_OUTLINE_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Self target
  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_OUTLINE_Usage", client);
      return Plugin_Handled;
    }

    // Apply
    g_bOutline[client] = (state == 1) ? true : false;
    if(IsPlayerAlive(client))
      SetOutline(client, (state == 1) ? true : false);

    if(state == 1)
      TagReply(client, "%T", "SM_OUTLINE_Enable_Self", client);
    else
      TagReply(client, "%T", "SM_OUTLINE_Disable_Self", client);
    return Plugin_Handled;
  }

  // Other target, args is > 1 here.
  if(!CheckCommandAccess(client, "sm_outline_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0, // Don't filter alive here, we need to set global.
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Check arg2
  int iState = GetStringBool(arg2, false, true, true, true);
  if(iState == -1)
  {
    TagReplyUsage(client, "%T", "SM_OUTLINE_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    g_bOutline[targ_list[i]] = view_as<bool>(iState);
    if(IsClientPlaying(targ_list[i]) && IsPlayerAlive(targ_list[i]))
      SetOutline(targ_list[i], view_as<bool>(iState));
  }

  if(iState)
    TagActivity(client, "%T", "SM_OUTLINE_Enable", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_OUTLINE_Disable", LANG_SERVER, targ_name);
  return Plugin_Handled;
}

// Assumes valid client index
void SetOutline(int client, bool state)
{
  SetEntProp(client, Prop_Send, "m_bGlowEnabled", state);
  return;
}



/**
 * Prevents anyone except the owner from using their teleporter.
 *
 * sm_telelock [Target] <1/0>
 */
public Action CMD_TeleLock(int client, int args)
{
  if(g_bDisabledCmds[ComTELELOCK])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_TELELOCK_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Self Target
  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int iState = GetStringBool(arg1, false, true, true, true);
    if(iState == -1)
    {
      TagReplyUsage(client, "%T", "SM_TELELOCK_Usage", client);
      return Plugin_Handled;
    }

    // Apply
    if(iState == 1)
    {
      g_bTeleLock[client] = true;
      TagReply(client, "%T", "SM_TELELOCK_Enable_Self", client);
    }
    else
    {
      g_bTeleLock[client] = false;
      TagReply(client, "%T", "SM_TELELOCK_Disable_Self", client);
    }
    return Plugin_Handled;
  }

  // Other target, args is > 1
  if(!CheckCommandAccess(client, "sm_telelock_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Check arg2
  int iState = GetStringBool(arg2, false, true, true, true);
  if(iState == -1)
  {
    TagReplyUsage(client, "%T", "SM_TELELOCK_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
    g_bTeleLock[targ_list[i]] = view_as<bool>(iState);

  if(iState)
    TagActivity(client, "%T", "SM_TELELOCK_Enable", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_TELELOCK_Disable", LANG_SERVER, targ_name);
  return Plugin_Handled;
}



/**
 * Allows enemy players to use the teleporter.
 *
 * sm_opentele [Target] <1/0>
 */
public Action CMD_OpenTele(int client, int args)
{
  if(g_bDisabledCmds[ComOPENTELE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_OPENTELE_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Self Target
  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int iState = GetStringBool(arg1, false, true, true, true);
    if(iState == -1)
    {
      TagReplyUsage(client, "%T", "SM_OPENTELE_Usage", client);
      return Plugin_Handled;
    }

    // Apply
    if(iState == 1)
    {
      g_bOpenTele[client] = true;
      TagReply(client, "%T", "SM_OPENTELE_Enable_Self", client);
    }
    else
    {
      g_bOpenTele[client] = false;
      TagReply(client, "%T", "SM_OPENTELE_Disable_Self", client);
    }
    return Plugin_Handled;
  }

  // Other target, args is > 1
  if(!CheckCommandAccess(client, "sm_opentele_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Check arg2
  int iState = GetStringBool(arg2, false, true, true, true);
  if(iState == -1)
  {
    TagReplyUsage(client, "%T", "SM_OPENTELE_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
    g_bOpenTele[targ_list[i]] = view_as<bool>(iState);

  if(iState)
    TagActivity(client, "%T", "SM_OPENTELE_Enable", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_OPENTELE_Disable", LANG_SERVER, targ_name);
  return Plugin_Handled;
}


/**
 * Allows enemy players to use the teleporter.
 *
 * sm_forceclass <Target> <Class> [Lock 1/0]
 */
public Action CMD_ForceClass(int client, int args)
{
  if(g_bDisabledCmds[ComFORCECLASS])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_FORCECLASS_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[10]; // "engineer"
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Get Class
  TFClassType classType;
  char className[16];
  if(StrEqual(arg2, "scout", false) || StrEqual(arg2, "1", true))
  {
    classType = TFClass_Scout;
    Format(className, sizeof(className), "%T", "SFP_Scout", LANG_SERVER);
  }
  else if(StrEqual(arg2, "soldier", false) || StrEqual(arg2, "2", true))
  {
    classType = TFClass_Soldier;
    Format(className, sizeof(className), "%T", "SFP_Soldier", LANG_SERVER);
  }
  else if(StrEqual(arg2, "pyro", false) || StrEqual(arg2, "3", true))
  {
    classType = TFClass_Pyro;
    Format(className, sizeof(className), "%T", "SFP_Pyro", LANG_SERVER);
  }
  else if(StrEqual(arg2, "demoman", false) || StrEqual(arg2, "4", true))
  {
    classType = TFClass_DemoMan;
    Format(className, sizeof(className), "%T", "SFP_Demoman", LANG_SERVER);
  }
  else if(StrEqual(arg2, "heavy", false) || StrEqual(arg2, "5", true))
  {
    classType = TFClass_Heavy;
    Format(className, sizeof(className), "%T", "SFP_Heavy", LANG_SERVER);
  }
  else if(StrEqual(arg2, "engineer", false) || StrEqual(arg2, "6", true))
  {
    classType = TFClass_Engineer;
    Format(className, sizeof(className), "%T", "SFP_Engineer", LANG_SERVER);
  }
  else if(StrEqual(arg2, "medic", false) || StrEqual(arg2, "7", true))
  {
    classType = TFClass_Medic;
    Format(className, sizeof(className), "%T", "SFP_Medic", LANG_SERVER);
  }
  else if(StrEqual(arg2, "sniper", false) || StrEqual(arg2, "8", true))
  {
    classType = TFClass_Sniper;
    Format(className, sizeof(className), "%T", "SFP_Sniper", LANG_SERVER);
  }
  else if(StrEqual(arg2, "spy", false) || StrEqual(arg2, "9", true))
  {
    classType = TFClass_Spy;
    Format(className, sizeof(className), "%T", "SFP_Spy", LANG_SERVER);
  }
  else
  {
    TagReplyUsage(client, "%T", "SM_FORCECLASS_BadClass", client);
    return Plugin_Handled;
  }

  // Get Lock State
  int state = 0;
  if(args > 2)
  {
    if(!CheckCommandAccess(client, "sm_forceclass_canlock", ADMFLAG_BAN, true))
    {
      TagReply(client, "%T", "SM_FORCECLASS_NoLock", client);
      return Plugin_Handled;
    }

    char arg3[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(3, arg3, sizeof(arg3));
    
    state = GetStringBool(arg3, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_FORCECLASS_Usage", client);
      return Plugin_Handled;
    }
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i])) // No spectators or dead players
    {
      TF2_SetPlayerClass(targ_list[i], classType, false, true);
      g_bForceClassLocked[targ_list[i]] = view_as<bool>(state);
    }
  }

  if(!state)
    TagActivity(client, "%T", "SM_FORCECLASS_Done_NoLock", LANG_SERVER, targ_name, className);
  else
    TagActivity(client, "%T", "SM_FORCECLASS_Done_Lock", LANG_SERVER, targ_name, className);
  return Plugin_Handled;
}

/**
 * Unlock players from sm_forceclass's lock
 *
 * sm_unlockclass <Target>
 */
public Action CMD_UnlockClass(int client, int args)
{
  if(g_bDisabledCmds[ComFORCECLASS]) // Intentionally bound to ComFORCECLASS
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_FORCECLASS_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Get Target List
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
    g_bForceClassLocked[targ_list[i]] = false;

  TagActivity(client, "%T", "SM_UNLOCKCLASS_Done", LANG_SERVER, targ_name);
  return Plugin_Handled;
}


/**
 * Set a player's health
 *
 * sm_hp [Target] <Amount>
 */
public Action CMD_SetHealth(int client, int args)
{
  if(g_bDisabledCmds[ComSETHEALTH])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_SETHEALTH_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  if(args == 1) // Self Target
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int amount = StringToInt(arg1);
    TF2_SetHealth(client, amount);
    TagReply(client, "%T", "SM_SETHEALTH_Done_Self", client, amount);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_sethealth_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  // Get Target List
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

  char arg2[10];
  GetCmdArg(2, arg2, sizeof(arg2));
  int amount = StringToInt(arg2);

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
      TF2_SetHealth(targ_list[i], amount);
  }

  TagActivity(client, "%T", "SM_SETHEALTH_Done", LANG_SERVER, targ_name, amount);
  return Plugin_Handled;
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
