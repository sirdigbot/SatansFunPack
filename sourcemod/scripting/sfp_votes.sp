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
#include <nativevotes>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>
#include <sfh_chatlib>


//=================================
// Constants
#define PLUGIN_VERSION  "1.1.2"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/votes_update.txt"

#define _INCLUDE_TOGGLEGRAPPLE
#define _INCLUDE_TOGGLEBHOPLIMIT

// List of commands that can be disabled.
// Set by CVar, updated in ProcessDisabledCmds, Checked in Command.
enum CommandNames {
  ComVOTEGRAPPLE = 0,
  ComTOGGLEGRAPPLE,
  ComVOTEBHOPLIMIT,
  ComTOGGLEBHOPLIMIT,
  ComTOTAL
};


//=================================
// Global
ConVar  h_bUpdate = null;
ConVar  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];

#if defined _INCLUDE_TOGGLEGRAPPLE
ConVar  h_bGrappleEnabled;
#endif

// REQUIRES Fysics Control -- https://forums.alliedmods.net/showthread.php?p=1776179
#if defined _INCLUDE_TOGGLEBHOPLIMIT 
ConVar  h_bFCBhopEnabled;     // Fysics Control: fc_bhop_enabled
ConVar  h_iFCBhopMaxSpeed;    // Fysics Control: fc_bhop_maxspeed 
ConVar  h_iBhopSpeedLimit;    // The limit value to use for fc_bhop_maxspeed
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
    Format(err, err_max, "Satan's Fun Pack is only compatible with Team Fortress 2.");
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
  h_bUpdate.AddChangeHook(OnCvarChanged);
  
  h_bDisabledCmds = CreateConVar("sm_sfpvotes_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- VoteGrapple\n- ToggleGrapple\n- VoteBhopLimit\n- ToggleBhopLimit", FCVAR_SPONLY|FCVAR_REPLICATED);
  ProcessDisabledCmds();
  h_bDisabledCmds.AddChangeHook(OnCvarChanged);
  
  #if defined _INCLUDE_TOGGLEGRAPPLE
  h_bGrappleEnabled = FindConVar("tf_grapplinghook_enable");

  RegAdminCmd("sm_votegrapple", CMD_VoteGrapple, ADMFLAG_BAN, "Start a vote to toggle grappling hooks");
  RegAdminCmd("sm_votehooks", CMD_VoteGrapple, ADMFLAG_BAN, "Start a vote to toggle grappling hooks");
  RegAdminCmd("sm_togglegrapple", CMD_ToggleGrapple, ADMFLAG_BAN, "Forcefully toggle grappling hooks");
  #endif
  
  #if defined _INCLUDE_TOGGLEBHOPLIMIT
  h_bFCBhopEnabled      = FindConVar("fc_bhop_enabled");
  h_iFCBhopMaxSpeed     = FindConVar("fc_bhop_maxspeed");
  h_iBhopSpeedLimit     = CreateConVar("sm_sfp_votes_bhopmax", "400", "Max Speed Limit to set on Fysics Controls' 'fc_bhop_maxspeed' cvar\nThis should be manually synced with custom configured values for fc_bhop_maxspeed\n(Default: 400)", FCVAR_NONE, true, 0.0, false);
  
  RegAdminCmd("sm_votebhoplimit", CMD_VoteBhopLimit, ADMFLAG_BAN, "Start a vote to toggle the bhop speed limiting");
  RegAdminCmd("sm_togglebhoplimit", CMD_ToggleBhopLimit, ADMFLAG_BAN, "Forcefully toggle the bhop speed limiting");
  #endif
  

  PrintToServer("%T", "SFP_VotesLoaded", LANG_SERVER);
}



public void OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
    (h_bUpdate.BoolValue) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
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
  h_bDisabledCmds.GetString(buffer, sizeof(buffer));
  
  if(StrContains(buffer, "VoteGrapple", true) != -1)
    g_bDisabledCmds[ComVOTEGRAPPLE] = true;
  
  if(StrContains(buffer, "ToggleGrapple", true) != -1)
    g_bDisabledCmds[ComTOGGLEGRAPPLE] = true;
    
  if(StrContains(buffer, "VoteBhopLimit", true) != -1)
    g_bDisabledCmds[ComVOTEBHOPLIMIT] = true;
  
  if(StrContains(buffer, "ToggleBhopLimit", true) != -1)
    g_bDisabledCmds[ComTOGGLEBHOPLIMIT] = true;
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

  // Closed in Handler
  Handle vote = NativeVotes_Create(VoteGrappleHandler, NativeVotesType_Custom_YesNo, NATIVEVOTES_ACTIONS_DEFAULT|MenuAction_Display);
  char voteNameStr[2] = ""; // Translated in handler

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
    
    case MenuAction_Display:
    {
      // NativeVotes Only: Param1 = client, Param2 = none
      char title[64];
      if(!h_bGrappleEnabled.BoolValue)
        Format(title, sizeof(title), "%T", "SM_VOTEGRAPPLE_Enable", param1);
      else
        Format(title, sizeof(title), "%T", "SM_VOTEGRAPPLE_Disable", param1);
      if(NativeVotes_RedrawVoteTitle(title) == Plugin_Changed)
        return 1; // Title changed, NativeVotes says to return 1
    }

    case MenuAction_VoteCancel:
    {
      if(param1 == VoteCancel_NoVotes)
        NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
      else
        NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
    }

    case MenuAction_VoteEnd:
    {
      if(param1 == NATIVEVOTES_VOTE_NO)
        NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
      else
      {
        // Vote Passed; Toggle Grapple Cvar
        char voteMsg[64];
        if(!h_bGrappleEnabled.BoolValue)
        {
          Format(voteMsg, sizeof(voteMsg), "%T", "SM_VOTEGRAPPLE_EnablePass", LANG_SERVER);
          TagPrintChatAll("%T", "SM_TOGGLEGRAPPLE_Enabled", LANG_SERVER);
        }
        else
        {
          Format(voteMsg, sizeof(voteMsg), "%T", "SM_VOTEGRAPPLE_DisablePass", LANG_SERVER);
          TagPrintChatAll("%T", "SM_TOGGLEGRAPPLE_Disabled", LANG_SERVER);
        }
        
        NativeVotes_DisplayPass(vote, voteMsg);
        h_bGrappleEnabled.SetBool(!h_bGrappleEnabled.BoolValue);
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
    h_bGrappleEnabled.SetBool(!h_bGrappleEnabled.BoolValue);
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
    h_bGrappleEnabled.SetBool(view_as<bool>(state));
  }

  if(h_bGrappleEnabled.BoolValue)
    TagActivity2(client, "%T", "SM_TOGGLEGRAPPLE_Enabled", LANG_SERVER);
  else
    TagActivity2(client, "%T", "SM_TOGGLEGRAPPLE_Disabled", LANG_SERVER);

  return Plugin_Handled;
}
#endif





#if defined _INCLUDE_TOGGLEBHOPLIMIT
/**
 * Start a Native Vote to toggle the Fysics Control Bhop Limit
 *
 * sm_votebhoplimit
 */
public Action CMD_VoteBhopLimit(int client, int args)
{
  if(g_bDisabledCmds[ComVOTEBHOPLIMIT])
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
  
  if(!FysicsControlReady())
  {
    TagReply(client, "%T", "SFP_BhopFCNotReady", client);
    return Plugin_Handled;
  }
  
  if(!h_bFCBhopEnabled.BoolValue)
  {
    TagReply(client, "%T", "SFP_BhopFCDisabled", client);
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
  
  // Closed in handler
  Handle vote = NativeVotes_Create(VoteBhopHandler, NativeVotesType_Custom_YesNo, NATIVEVOTES_ACTIONS_DEFAULT|MenuAction_Display);
  char voteNameStr[2] = ""; // Translated in handler

  NativeVotes_SetInitiator(vote, client);
  NativeVotes_SetDetails(vote, voteNameStr);
  NativeVotes_DisplayToAll(vote, 30);

  return Plugin_Handled;
}


public int VoteBhopHandler(Handle vote, MenuAction action, int param1, int param2)
{
  switch (action)
  {
    case MenuAction_End:
    {
      NativeVotes_Close(vote); // Must use NativeVotes_Close
    }
    
    case MenuAction_Display:
    {
      // NativeVotes Only: Param1 = client, Param2 = none
      char title[64];
      if(IsBhopUnlimited())
        Format(title, sizeof(title), "%T", "SM_VOTEBHOPLIMIT_Enable", param1);
      else
        Format(title, sizeof(title), "%T", "SM_VOTEBHOPLIMIT_Disable", param1);
      if(NativeVotes_RedrawVoteTitle(title) == Plugin_Changed)
        return 1; // Title changed, NativeVotes says to return 1
    }

    case MenuAction_VoteCancel:
    {
      if(param1 == VoteCancel_NoVotes)
        NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
      else
        NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
    }
    
    case MenuAction_VoteEnd:
    {
      if(param1 == NATIVEVOTES_VOTE_NO)
        NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
      else
      {
        // Vote Passed; Toggle Bhop Limit
        char voteMsg[64];
        if(IsBhopUnlimited())
        {
          Format(voteMsg, sizeof(voteMsg), "%T", "SM_VOTEBHOPLIMIT_EnablePass", LANG_SERVER);
          TagPrintChatAll("%T", "SM_TOGGLEBHOPLIMIT_Enabled", LANG_SERVER);
        }
        else
        {
          Format(voteMsg, sizeof(voteMsg), "%T", "SM_VOTEBHOPLIMIT_DisablePass", LANG_SERVER);
          TagPrintChatAll("%T", "SM_TOGGLEBHOPLIMIT_Disabled", LANG_SERVER);
        }
        
        NativeVotes_DisplayPass(vote, voteMsg);
        SetBhopLimitEnabled(IsBhopUnlimited());
      }
    }
  }
  return 0;
}



/**
 * Forcibly Toggle Bhop Limit
 *
 * sm_togglebhoplimit [1/0]
 */
public Action CMD_ToggleBhopLimit(int client, int args)
{
  if(g_bDisabledCmds[ComTOGGLEBHOPLIMIT])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }
  
  if(!FysicsControlReady())
  {
    TagReply(client, "%T", "SFP_BhopFCNotReady", client);
    return Plugin_Handled;
  }
  
  if(!h_bFCBhopEnabled.BoolValue)
  {
    TagReply(client, "%T", "SFP_BhopFCDisabled", client);
    return Plugin_Handled;
  }

  if(args < 1)
    SetBhopLimitEnabled(IsBhopUnlimited());
  else
  {
    char arg1[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_TOGGLEBHOPLIMIT_Usage", client);
      return Plugin_Handled;
    }
    SetBhopLimitEnabled(view_as<bool>(state));
  }

  if(!IsBhopUnlimited())
    TagActivity2(client, "%T", "SM_TOGGLEBHOPLIMIT_Enabled", LANG_SERVER);
  else
    TagActivity2(client, "%T", "SM_TOGGLEBHOPLIMIT_Disabled", LANG_SERVER);

  return Plugin_Handled;
}

stock void SetBhopLimitEnabled(const bool enabled)
{
  if(FysicsControlReady())
    h_iFCBhopMaxSpeed.SetInt((enabled) ? h_iBhopSpeedLimit.IntValue : -1); // -1 removes limit
  return;
}

stock bool FysicsControlReady()
{
  return (h_bFCBhopEnabled != null && h_iFCBhopMaxSpeed != null);
}

stock bool IsBhopUnlimited()
{
  return (h_iFCBhopMaxSpeed.IntValue == -1);
}
#endif




//=================================
// Updater
public void OnConfigsExecuted()
{
  if(LibraryExists("updater") && h_bUpdate.BoolValue)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryAdded(const char[] name)
{
  if(StrEqual(name, "updater") && h_bUpdate.BoolValue)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryRemoved(const char[] name)
{
  if(StrEqual(name, "updater"))
    Updater_RemovePlugin();
  return;
}
