#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>  // Shared function library


//=================================
// Constants
#define PLUGIN_VERSION  "0.0.1"
#define PLUGIN_URL      "UNDEFINED"
#define UPDATE_URL      "UNDEFINED" // NOTE Unique update file per compiled plugin.


//=================================
// Globals
bool    g_bLateLoad;
Handle  g_hTempBanMax = null;
int     g_iTempBanMax;


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
  g_bLateLoad = late;
  EngineVersion eng = GetEngineVersion();
  if(eng != Engine_TF2)
  {
    Format(err, err_max, "%T", "SFP_Incompatible", LANG_SERVER);
    return APLRes_Failure;
  }
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");


  /*** AdminTools ***/
  g_hTempBanMax = CreateConVar("sm_maxlengthban", "180", "Max Length Of Temporary Ban\n(Default: 180)", FCVAR_NONE, true, 0.0, false);
  g_iTempBanMax = GetConVarInt(g_hTempBanMax);
  HookConVarChange(g_hTempBanMax, UpdateCvars);

  RegAdminCmd("sm_ccom",        CMD_ClientCmd, ADMFLAG_ROOT, "Force Player to Use a Command");
  RegAdminCmd("sm_tban",        CMD_TempBan, ADMFLAG_BAN, "Ban Players. Temporarily");
  RegAdminCmd("sm_addcond",     CMD_AddCond, ADMFLAG_BAN, "Add a Condition to a Player");
  RegAdminCmd("sm_remcond",     CMD_RemCond, ADMFLAG_BAN, "Remove a Condition from a Player");
  RegAdminCmd("sm_removecond",  CMD_RemCond, ADMFLAG_BAN, "Remove a Condition from a Player");
  RegAdminCmd("sm_disarm",      CMD_Disarm, ADMFLAG_BAN, "Strip Weapons from a Player");
  RegAdminCmd("sm_forceteam",   CMD_ForceTeam, ADMFLAG_BAN, "Force Player onto a Team");
  RegAdminCmd("sm_forcespec",   CMD_ForceSpec, ADMFLAG_BAN, "Force Player into Spectator");
  RegAdminCmd("sm_fsay",        CMD_FakeSay, ADMFLAG_BAN, "I didn't say that, I swear!");
  RegAdminCmd("sm_namelock",    CMD_NameLock, ADMFLAG_BAN, "Prevent a Player from Changing Names");
  RegAdminCmd("sm_notarget",    CMD_NoTarget, ADMFLAG_BAN, "Disable Sentry Targeting on a Player");
  RegAdminCmd("sm_outline",     CMD_Outline, ADMFLAG_BAN, "Set Outline Effect on a Player");


  /*** Handle Late Loads ***/
  if(g_bLateLoad)
    PrintToServer("LateLoad Warning Fix"); // FIXME debug

  PrintToServer("%T", "SFP_AdminToolsLoaded", LANG_SERVER);
}


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == g_hTempBanMax)
    g_iTempBanMax = StringToInt(newValue);
  return;
}





/**
 * Force a client to run a console command.
 *
 * sm_ccom <Target> <Command>
 */
public Action CMD_ClientCmd(int client, int args)
{
  if(args < 2)
  {
    ReplyUsage(client, "%T", "SM_CCOM_Usage", client);
    return Plugin_Handled;
  }

  // Process Args
  char arg1[MAX_NAME_LENGTH], argFull[256];
  GetCmdArgString(argFull, sizeof(argFull));

  int arg2Idx = BreakString(argFull, arg1, sizeof(arg1));
  if(arg2Idx == -1)
  {
    ReplyUsage(client, "%T", "SM_CCOM_Usage", client);
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
    COMMAND_FILTER_NO_BOTS,
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
    if (IsClientInGame(targ_list[i]))
      FakeClientCommandEx(targ_list[i], argFull[arg2Idx]);
  }

  ReplyStandard(client, "%T", "SM_CCOM_Done", client, targ_name, argFull[arg2Idx]);
  return Plugin_Handled;
}



/**
 * Ban a player normally, but limit the duration to a cvar value.
 * FIXME Reason output is wrong af
 * sm_tban <Target> <Duration> [Reason]
 */
public Action CMD_TempBan(int client, int args)
{
  if(args < 2)
  {
    ReplyUsage(client, "%T", "SM_TBAN_Usage", client);
    return Plugin_Handled;
  }

  // Process args
  char arg1[MAX_NAME_LENGTH], arg2[16], argFull[256], dummyArg3[4];
  GetCmdArgString(argFull, sizeof(argFull));

  int arg1Idx = BreakString(argFull, arg1, sizeof(arg1));
  int buffer = BreakString(argFull[arg1Idx], arg2, sizeof(arg2));
  arg1Idx += buffer;

  // Check for 3rd arg/reason
  buffer = BreakString(argFull[arg1Idx], dummyArg3, sizeof(dummyArg3));
  if(buffer != -1)
    arg1Idx += buffer;
  else
  {
    arg1Idx = 0;
    argFull[0] = 1; // Not using 0 in case of weird C problems.
  }

  // Check Args
  int duration = StringToInt(arg2);
  if (duration < 1 || duration > g_iTempBanMax)
  {
    ReplyStandard(client, "%T", "SM_TBAN_BadTime", client, g_iTempBanMax);
    return Plugin_Handled;
  }

  // Prepare output
  int target = FindTarget(client, arg1, true); // Single target, no bots
  if(target == -1)
    return Plugin_Handled;

  char targ_name[MAX_NAME_LENGTH], reason[256];
  GetClientName(target, targ_name, sizeof(targ_name));

  if(argFull[0] == 1)
    Format(reason, sizeof(reason), "Temporary Ban (%d min)", duration);
  else
    Format(reason, sizeof(reason), "Temporary Ban (%d min): %s", duration, argFull[arg1Idx]);

  // Output
  ReplyActivity(client, "%T", "SM_TBAN_BanMessage", client, targ_name, duration, reason);
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
  if(args < 2)
  {
    ReplyUsage(client, "%T", "SM_ADDCOND_Usage", client);
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
    // Check arg1, arg2/duration can be negative.
    if(iArg1 < 0)
    {
      ReplyStandard(client, "%T", "SM_ADDCOND_BadCondition", client);
      return Plugin_Handled;
    }

    // Output
    TF2_AddCondition(client, view_as<TFCond>(iArg1), view_as<float>(iArg2), 0);
    ReplyStandard(client, "%T", "SM_ADDCOND_Done", client, iArg1);
  }

  // Process args on target player
  else if(args > 2)
  {
    char arg3[16];
    GetCmdArg(3, arg3, sizeof(arg3));
    int iArg3 = StringToInt(arg3);

    // Check arg2
    if(iArg2 < 0)
    {
      ReplyStandard(client, "%T", "SM_ADDCOND_BadCondition", client);
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
      COMMAND_FILTER_NO_BOTS,
      targ_name,
      sizeof(targ_name),
      tn_is_ml)) <= 0)
    {
      ReplyToTargetError(client, targ_count);
      return Plugin_Handled;
    }

    // Output
    for(int i = 0; i < targ_count; ++i)
      TF2_AddCondition(targ_list[i], view_as<TFCond>(iArg2), view_as<float>(iArg3), 0);
    ReplyActivity(client, "%T", "SM_ADDCOND_Done_Other", client, iArg2, targ_name);
  }

  return Plugin_Handled;
}


/**
 * Remove condition from player.
 *
 * sm_remcond [Target] <Condition>
 */
public Action CMD_RemCond(int client, int args)
{
  if(args < 1)
  {
    ReplyUsage(client, "%T", "SM_REMCOND_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));


  if(args == 1)
  {
    int iArg1 = StringToInt(arg1);

    // Check arg
    if(iArg1 < 0)
    {
      ReplyStandard(client, "%T", "SM_ADDCOND_BadCondition", client);
      return Plugin_Handled;
    }

    TF2_RemoveCondition(client, view_as<TFCond>(iArg1));
    ReplyStandard(client, "%T", "SM_REMCOND_Done", client, iArg1);
  }
  else if(args > 1)
  {
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
      COMMAND_FILTER_NO_BOTS,
      targ_name,
      sizeof(targ_name),
      tn_is_ml)) <= 0)
    {
      ReplyToTargetError(client, targ_count);
      return Plugin_Handled;
    }

    for(int i = 0; i < targ_count; ++i)
      TF2_RemoveCondition(targ_list[i], view_as<TFCond>(iArg2));
    ReplyActivity(client, "%T", "SM_REMCOND_Done_Other", client, iArg2, targ_name);
  }
  return Plugin_Handled;
}



public Action CMD_Disarm(int client, int args)
{
  return Plugin_Handled;
}



public Action CMD_ForceTeam(int client, int args)
{
  return Plugin_Handled;
}



public Action CMD_ForceSpec(int client, int args)
{
  return Plugin_Handled;
}



public Action CMD_FakeSay(int client, int args)
{
  return Plugin_Handled;
}



public Action CMD_NameLock(int client, int args)
{
  return Plugin_Handled;
}



public Action CMD_NoTarget(int client, int args)
{
  return Plugin_Handled;
}



public Action CMD_Outline(int client, int args)
{
  return Plugin_Handled;
}
