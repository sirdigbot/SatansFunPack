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
  ComGHOSTMODE,
  ComTOTAL
};

static const char c_GhostModels[][40] = {
	"models/props_halloween/ghost.mdl",
	"models/props_halloween/ghost_no_hat.mdl"
};

static const char c_GhostSounds[][26] = {
	"vo/halloween_moan1.mp3",
	"vo/halloween_moan2.mp3",
	"vo/halloween_moan3.mp3",
	"vo/halloween_moan4.mp3",
	"vo/halloween_boo1.mp3",
	"vo/halloween_boo2.mp3",
	"vo/halloween_boo3.mp3",
	"vo/halloween_boo4.mp3",
	"vo/halloween_boo5.mp3",
	"vo/halloween_boo6.mp3",
	"vo/halloween_boo7.mp3",
	"vo/halloween_haunted1.mp3",
	"vo/halloween_haunted2.mp3",
	"vo/halloween_haunted3.mp3",
	"vo/halloween_haunted4.mp3",
	"vo/halloween_haunted5mp3v"
};


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
Handle  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];

bool    g_bGhostMode[MAXPLAYERS + 1];

/**
 * Known Bugs
 * Commands dont use TagActivity. They don't really need to, but they could.
 */
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
  LoadTranslations("sfp.quickconditions.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");

  h_bUpdate = CreateConVar("sm_sfp_quickconditions_update", "1", "Update Satan's Fun Pack - Quick Conditions Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_bDisabledCmds = CreateConVar("sm_quickcond_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- Boing\n- DanceMonkey\n- Ghost", FCVAR_SPONLY|FCVAR_REPLICATED);
  ProcessDisabledCmds();
  HookConVarChange(h_bDisabledCmds, UpdateCvars);

  RegAdminCmd("sm_boing", CMD_Boing, ADMFLAG_BAN, "Bouncy + Pew Pew");
  RegAdminCmd("sm_dancemonkey", CMD_Dance, ADMFLAG_BAN, "Use this before shooting near a player's feet");
  RegAdminCmd("sm_ghost", CMD_GhostMode, ADMFLAG_BAN, "I'll give you 3 guesses");

  AddCommandListener(Listener_Voicemenu, "voicemenu");

  /**
   * Overrides
   * sm_ghost_target - Can target others
   */

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

  if(StrContains(buffer, "Ghost", true) != -1)
    g_bDisabledCmds[ComGHOSTMODE] = true;
  return;
}


public void OnMapStart()
{
  for(int i = 0; i < sizeof(c_GhostModels); ++i)
    PrecacheModel(c_GhostModels[i], true);

  for(int i = 0; i < sizeof(c_GhostSounds); ++i)
    PrecacheSound(c_GhostSounds[i], true);
  return;
}

public void OnClientDisconnect_Post(int client)
{
  g_bGhostMode[client] = false;
  return;
}


public Action Listener_Voicemenu(int client, char[] command, int args)
{
  if(client < 1 || client > MaxClients || !IsClientInGame(client))
    return Plugin_Continue;

  if(g_bGhostMode[client])
  {
    SetGhostMode(client, false); // Handles g_bGhostMode
    if(!IsFakeClient(client))
      TagPrintChat(client, "%T", "SM_GHOST_Disabled_Self", client);
    return Plugin_Handled; // Doesn't matter if this successfully blocks or not
  }
  return Plugin_Continue;
}


/**
 * Give player infinite jumps and double fire rate.
 * (Cond 72/TFCond_HalloweenSpeedBoost)
 *
 * sm_boing [Target] <1/0>
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


  if(iState)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      if(IsClientPlaying(targ_list[i]))
      {
        TF2_AddCondition(targ_list[i], TFCond_HalloweenSpeedBoost, TFCondDuration_Infinite, 0);
        if(!IsFakeClient(targ_list[i]))
          TagPrintChat(targ_list[i], "%T", "SM_BOING_On", targ_list[i]);
      }
    }
  }
  else
  {
    for(int i = 0; i < targ_count; ++i)
    {
      if(IsClientPlaying(targ_list[i]))
      {
        TF2_RemoveCondition(targ_list[i], TFCond_HalloweenSpeedBoost);
        if(!IsFakeClient(targ_list[i]))
          TagPrintChat(targ_list[i], "%T", "SM_BOING_Off", targ_list[i]);
      }
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
      if(IsClientPlaying(targ_list[i]))
      {
        TF2_AddCondition(targ_list[i], TFCond_HalloweenThriller, StringToFloat(arg2), 0);
        if(!IsFakeClient(targ_list[i]))
          TagPrintChat(targ_list[i], "%T", "SM_DANCE_On", targ_list[i]);
      }
    }
  }
  else if (iArg2 < 0)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      if(IsClientPlaying(targ_list[i]))
      {
        TF2_RemoveCondition(targ_list[i], TFCond_HalloweenThriller);
        if(!IsFakeClient(targ_list[i]))
          TagPrintChat(targ_list[i], "%T", "SM_DANCE_Off", targ_list[i]);
      }
    }
  }
  else // if iArg2 = 0; if It's not "stop" and not an int above 0
    TagReplyUsage(client, "%T", "SM_DANCE_Usage", client);

  return Plugin_Handled;
}



/**
 * Turn into a ghost
 * (Cond 77/TFCond_HalloweenGhostMode)
 *
 * sm_ghost <[Target] [1/0]>
 */
public Action CMD_GhostMode(int client, int args)
{
  if(args == 0)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(g_bGhostMode[client])
    {
      SetGhostMode(client, false);
      TagReply(client, "%T", "SM_GHOST_Disabled_Self", client);
    }
    else
    {
      SetGhostMode(client, true);
      TagReply(client, "%T", "SM_GHOST_Enabled_Self", client);
    }
    return Plugin_Handled;
  }

  // To prevent annoying flip-flop situations, both args are mandatory at once.
  if(args == 1)
  {
    TagReplyUsage(client, "%T", "SM_GHOST_Usage", client);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_ghost_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));

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


  // Get State
  int state = GetStringBool(arg2, false, true, true, true);
  if(state == -1)
  {
    TagReplyUsage(client, "%T", "SM_GHOST_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i])) // Only alive players
      SetGhostMode(targ_list[i], view_as<bool>(state));
  }

  if(state)
    TagActivity(client, "%T", "SM_GHOST_Enabled", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_GHOST_Disabled", LANG_SERVER, targ_name);
  return Plugin_Handled;
}

stock void SetGhostMode(int client, bool state)
{
  if(state)
  {
    g_bGhostMode[client] = true;
    TF2_AddCondition(client, TFCond_HalloweenGhostMode, TFCondDuration_Infinite, 0);
    if(!IsFakeClient(client))
      ShowGhostCancelTip(client);
  }
  else
  {
    g_bGhostMode[client] = false;
    TF2_RemoveCondition(client, TFCond_HalloweenGhostMode);
  }
  return;
}

stock void ShowGhostCancelTip(int client)
{
  SetHudTextParams(-1.0, 0.87, 4.0, 255, 255, 255, 255); // TODO Add colour cvar
  ShowHudText(client, -1, "%T", "SM_GHOST_TauntCancelTip", client);
  return;
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
