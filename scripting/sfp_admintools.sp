#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
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

  RegAdminCmd("sm_ccom",        AdminTools_CMD_ClientCmd, ADMFLAG_ROOT, "Force Player to Use a Command");
  RegAdminCmd("sm_tban",        AdminTools_CMD_TempBan, ADMFLAG_BAN, "Ban Players. Temporarily");
  RegAdminCmd("sm_addcond",     AdminTools_CMD_AddCond, ADMFLAG_BAN, "Add a Condition to a Player");
  RegAdminCmd("sm_remcond",     AdminTools_CMD_RemCond, ADMFLAG_BAN, "Remove a Condition from a Player");
  RegAdminCmd("sm_removecond",  AdminTools_CMD_RemCond, ADMFLAG_BAN, "Remove a Condition from a Player");
  RegAdminCmd("sm_disarm",      AdminTools_CMD_Disarm, ADMFLAG_BAN, "Strip Weapons from a Player");
  RegAdminCmd("sm_forceteam",   AdminTools_CMD_ForceTeam, ADMFLAG_BAN, "Force Player onto a Team");
  RegAdminCmd("sm_forcespec",   AdminTools_CMD_ForceSpec, ADMFLAG_BAN, "Force Player into Spectator");
  RegAdminCmd("sm_fsay",        AdminTools_CMD_FakeSay, ADMFLAG_BAN, "I didn't say that, I swear!");
  RegAdminCmd("sm_namelock",    AdminTools_CMD_NameLock, ADMFLAG_BAN, "Prevent a Player from Changing Names");
  RegAdminCmd("sm_notarget",    AdminTools_CMD_NoTarget, ADMFLAG_BAN, "Disable Sentry Targeting on a Player");
  RegAdminCmd("sm_outline",     AdminTools_CMD_Outline, ADMFLAG_BAN, "Set Outline Effect on a Player");


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
public Action AdminTools_CMD_ClientCmd(int client, int args)
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
 *
 * sm_tban <Target> <Duration> [Reason]
 */
public Action AdminTools_CMD_TempBan(int client, int args)
{
  if(args < 2)
  {
    ReplyUsage(client, "%T", "SFP_SM_TBAN_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[16], argFull[256];
  GetCmdArgString(argFull, sizeof(argFull));

  int arg1Idx = BreakString(argFull, arg1, sizeof(arg1));
  int target = FindTarget(client, arg1, true);
  if(target == -1)
    return Plugin_Handled; // Don't print, FindTarget() will.


  PrintToServer("%d", g_iTempBanMax);
  return Plugin_Handled;
}



public Action AdminTools_CMD_AddCond(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_RemCond(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_Disarm(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_ForceTeam(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_ForceSpec(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_FakeSay(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_NameLock(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_NoTarget(int client, int args)
{
  return Plugin_Handled;
}



public Action AdminTools_CMD_Outline(int client, int args)
{
  return Plugin_Handled;
}
