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
#define UPDATE_URL  "https://sirdigbot.github.io/SatansFunPack/sourcemod/quickcond_update.txt"

// List of commands that can be disabled.
// Set by CVar, updated in ProcessDisabledCmds, Checked in Command.
enum CommandNames {
  ComBOING,
  ComDANCEMONKEY,
  ComTOTAL
};


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
Handle  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Quick Conditions",
  author =      "SirDigby",
  description = "Easy-Access Superpowers",
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
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");

  h_bUpdate = FindConVar("sm_satansfunpack_update");
  if(h_bUpdate == null)
    SetFailState("%T", "SFP_MainCvarFail", LANG_SERVER, "sm_satansfunpack_update");
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_bDisabledCmds = CreateConVar("sm_quickcond_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- Boing\n- DanceMonkey", FCVAR_SPONLY);
  ProcessDisabledCmds();
  HookConVarChange(h_bDisabledCmds, UpdateCvars);

  RegAdminCmd("sm_boing", CMD_Boing, ADMFLAG_BAN, "Bouncy + Pew Pew");
  RegAdminCmd("sm_dancemonkey", CMD_Dance, ADMFLAG_BAN, "Use this before shooting near a player's feet");

  PrintToServer("%T", "SFP_QuickConditionsLoaded", LANG_SERVER);
}

public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
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

  char buffer[300];
  GetConVarString(h_bDisabledCmds, buffer, sizeof(buffer));
  if(StrContains(buffer, "Boing", true) != -1)
    g_bDisabledCmds[ComBOING] = true;

  if(StrContains(buffer, "DanceMonkey", true) != -1)
    g_bDisabledCmds[ComDANCEMONKEY] = true;
  return;
}



/**
 * Give player infinite jumps and double fire rate.
 * (Cond 72/TFCond_HalloweenSpeedBoost)
 *
 * sm_boing [Target] <1/0/On/Off>
 */
public Action CMD_Boing(int client, int args)
{
  if(g_bDisabledCmds[ComBOING])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_BOING_Usage", client);
    return Plugin_Handled;
  }

  char state[8];
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if(args == 1)
  {
    GetCmdArg(1, state, sizeof(state));
    targ_count = 1;
    targ_list[0] = client;
  }
  else if(args > 1)
  {
    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(2, state, sizeof(state));
    GetCmdArg(1, arg1, sizeof(arg1));

    // Get Target List
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


  int iState = GetStringBool(state, false, true, true, true);
  if(iState == -1)
  {
    TagReplyUsage(client, "%T", "SM_BOING_Usage", client);
    return Plugin_Handled;
  }


  if(iState == 1)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_AddCondition(targ_list[i], TFCond_HalloweenSpeedBoost, TFCondDuration_Infinite, 0);
      TagPrintChat(targ_list[i], "%T", "SM_BOING_On", targ_list[i]);
    }
  }
  else
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_RemoveCondition(targ_list[i], TFCond_HalloweenSpeedBoost);
      TagPrintChat(targ_list[i], "%T", "SM_BOING_Off", targ_list[i]);
    }
  }

  return Plugin_Handled;
}


/**
 * Force player into the thriller-taunt-lock state
 * (Cond 54/TFCond_HalloweenThriller)
 *
 * sm_dancemonkey <Target> <Duration/0/Stop/End/Off>
 */
public Action CMD_Dance(int client, int args)
{
  if(g_bDisabledCmds[ComDANCEMONKEY])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_DANCE_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[16];
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
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Process arg2/duration
  int iArg2;
  if(StrEqual(arg2, "stop", false)
  || StrEqual(arg2, "end", false)
  || StrEqual(arg2, "off", false)
  || StrEqual(arg2, "0", true))
  {
    iArg2 = -1;
  }
  else
  {
    iArg2 = StringToInt(arg2);
  }

  if(iArg2 > 0)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_AddCondition(targ_list[i], TFCond_HalloweenThriller, StringToFloat(arg2), 0);
      TagPrintChat(targ_list[i], "%T", "SM_DANCE_On", targ_list[i]);
    }
  }
  else if (iArg2 < 0)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_RemoveCondition(targ_list[i], TFCond_HalloweenThriller);
      TagPrintChat(targ_list[i], "%T", "SM_DANCE_Off", targ_list[i]);
    }
  }
  else // if iArg2 = 0; if It's not "stop" and not an int above 0
    TagReplyUsage(client, "%T", "SM_DANCE_Usage", client);

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
