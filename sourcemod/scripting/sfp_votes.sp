#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <nativevotes>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.2"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/votes_update.txt"

#define _INCLUDE_TOGGLEGRAPPLE

// List of commands that can be disabled.
// Set by CVar, updated in ProcessDisabledCmds, Checked in Command.
enum CommandNames {
  ComVOTEGRAPPLE = 0,
  ComTOGGLEGRAPPLE,
  ComTOTAL
};


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
Handle  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];

#if defined _INCLUDE_TOGGLEGRAPPLE
Handle  h_bGrappleEnabled = null;
bool    g_bGrappleEnabled;
#endif


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Votes",
  author =      "SirDigby",
  description = "New Features for the Indecisive Admin",
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
  LoadTranslations("sfp.votes.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");
  
  h_bUpdate = CreateConVar("sm_sfp_votes_update", "1", "Update Satan's Fun Pack - Votes Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_bDisabledCmds = CreateConVar("sm_sfpvotes_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- VoteGrapple\n- ToggleGrapple", FCVAR_SPONLY|FCVAR_REPLICATED);
  ProcessDisabledCmds();
  HookConVarChange(h_bDisabledCmds, UpdateCvars);
  
  
  #if defined _INCLUDE_TOGGLEGRAPPLE
  RegAdminCmd("sm_votegrapple", CMD_VoteGrapple, ADMFLAG_BAN, "Start a vote to toggle grappling hooks");
  RegAdminCmd("sm_votehooks", CMD_VoteGrapple, ADMFLAG_BAN, "Start a vote to toggle grappling hooks");
  RegAdminCmd("sm_togglegrapple", CMD_ToggleGrapple, ADMFLAG_BAN, "Forcefully toggle grappling hooks");
  #endif
  
  #if defined _INCLUDE_TOGGLEGRAPPLE
  h_bGrappleEnabled = FindConVar("tf_grapplinghook_enable");
  if(h_bGrappleEnabled != null)
    g_bGrappleEnabled = GetConVarBool(h_bGrappleEnabled);
  #endif
  
  PrintToServer("%T", "SFP_VotesLoaded", LANG_SERVER);
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
  
  if(StrContains(buffer, "VoteGrapple", true) != -1)
    g_bDisabledCmds[ComVOTEGRAPPLE] = true;
  
  else if(StrContains(buffer, "ToggleGrapple", true) != -1)
    g_bDisabledCmds[ComTOGGLEGRAPPLE] = true;
  
  return;
}



#if defined _INCLUDE_TOGGLEGRAPPLE
/**
 * Start a Native Vote to toggle Grapple Hooks
 *
 * sm_votegrapple
 */
public Action CMD_VoteGrapple(int client, int args)
{
  if(g_bDisabledCmds[ComVOTEGRAPPLE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(!IsClientPlaying(client, true))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }
  
  // NativeVotes checks
  if(!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
  {
    TagReply(client, "%T", "SFP_VoteSupport_YesNo", client);
    return Plugin_Handled;
  }

  if(!NativeVotes_IsNewVoteAllowed())
  {
    int seconds = NativeVotes_CheckVoteDelay();
    TagReply(client, "%T", "SFP_NativeVoteDelay", client, seconds);
    return Plugin_Handled;
  }

  char voteNameStr[64];
  if(!g_bGrappleEnabled)
    Format(voteNameStr, sizeof(voteNameStr), "%T", "SM_VOTEGRAPPLE_Enable", LANG_SERVER);
  else
    Format(voteNameStr, sizeof(voteNameStr), "%T", "SM_VOTEGRAPPLE_Disable", LANG_SERVER);
  
  // Closed in Vote Handler
  Handle vote = NativeVotes_Create(VoteGrappleHandler, NativeVotesType_Custom_YesNo);

  NativeVotes_SetInitiator(vote, client);
  NativeVotes_SetDetails(vote, voteNameStr);
  NativeVotes_DisplayToAll(vote, 30);

  return Plugin_Handled;
}


public int VoteGrappleHandler(Handle vote, MenuAction action, int param1, int param2)
{
  switch (action)
  {
    case MenuAction_End:
    {
      NativeVotes_Close(vote); // Must use NativeVotes_Close
    }

    case MenuAction_VoteCancel:
    {
      if (param1 == VoteCancel_NoVotes)
        NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
      else
        NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
    }

    case MenuAction_VoteEnd:
    {
      if (param1 == NATIVEVOTES_VOTE_NO)
        NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
      else
      {
        // Vote Passed; Toggle Grapple Cvar
        char voteMsg[64];
        if(!g_bGrappleEnabled)
          Format(voteMsg, sizeof(voteMsg), "%T", "SM_VOTEGRAPPLE_EnablePass", LANG_SERVER);
        else
          Format(voteMsg, sizeof(voteMsg), "%T", "SM_VOTEGRAPPLE_DisablePass", LANG_SERVER);
        
        NativeVotes_DisplayPass(vote, voteMsg);
        SetGrappleCvar(!g_bGrappleEnabled);
      }
    }
  }
  return 0;
}



/**
 * Forcibly Toggle Grapple Hooks
 *
 * sm_togglegrapple [1/0]
 */
public Action CMD_ToggleGrapple(int client, int args)
{
  if(g_bDisabledCmds[ComTOGGLEGRAPPLE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
    SetGrappleCvar(!g_bGrappleEnabled);
  else
  {
    char arg1[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_TOGGLEGRAPPLE_Usage", client);
      return Plugin_Handled;
    }
    SetGrappleCvar(view_as<bool>(state));
  }

  if(g_bGrappleEnabled)
    TagActivity(client, "%T", "SM_TOGGLEGRAPPLE_Enabled", LANG_SERVER);
  else
    TagActivity(client, "%T", "SM_TOGGLEGRAPPLE_Disabled", LANG_SERVER);

  return Plugin_Handled;
}


void SetGrappleCvar(bool state)
{
  if(h_bGrappleEnabled == null)
    return;
  
  SetConVarBool(h_bGrappleEnabled, state);
  g_bGrappleEnabled = state;
}
#endif




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
