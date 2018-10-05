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
#include <basecomm>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>
#include <sfh_chatlib>


//=================================
// Constants
#define PLUGIN_VERSION  "1.1.0"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/chatvision_update.txt"

#define COL_RED     "\x07FF3D3D"
#define COL_BLU     "\x079ACDFF"
#define COL_SPEC    "\x07CCCCCC"


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
Handle  h_bEnabled = null; // If chat is displayed. Everything else stays on.
bool    g_bEnabled;
TFTeam  g_PlayerTeam[MAXPLAYERS + 1];
bool    g_bIsChatAdmin[MAXPLAYERS + 1];


/**
 * Known Bugs
 * TODO Is spectator all-chat seen by normal players?
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Chat Vision",
  author =      "SirDigby",
  description = "Allow Admins to See Enemy Team Chat",
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
  LoadTranslations("sfp.chatvision.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");

  h_bUpdate = CreateConVar("sm_sfp_chatvision_update", "1", "Update Satan's Fun Pack - ChatVision Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_bEnabled = CreateConVar("sm_chatvision_enabled", "1", "Is Admin Chat Vision Enabled (1/0)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bEnabled = GetConVarBool(h_bEnabled);
  HookConVarChange(h_bEnabled, UpdateCvars);

  RegAdminCmd("sm_chatvision_reload", CMD_ReloadChatVision, ADMFLAG_ROOT, "Reloads Admin Chat Vision");
  RegAdminCmd("sm_ischatadmin", CMD_IsChatAdmin, ADMFLAG_GENERIC, "Checks if Player sees Enemy Team Chat");

  HookEvent("player_team", Event_TeamChange, EventHookMode_Post);

  AddCommandListener(Listener_Say, "say_team");
  AddCommandListener(Listener_ReloadAdmins, "sm_reloadadmins");

  /**
   * Overrides
   * sm_chatvision_access - Client can see enemy team chat
   */

  /*** Handle Late Loads ***/
  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; ++i)
    {
      if(IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
      {
        SetChatAdmin(i);
        g_PlayerTeam[i] = TF2_GetClientTeam(i);
      }
    }
  }

  PrintToServer("%T", "SFP_ChatVisionLoaded", LANG_SERVER);
}



public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_bEnabled)
    g_bEnabled = GetConVarBool(h_bEnabled);
  return;
}



public void OnClientPostAdminCheck(int client)
{
  if(IsClientPlaying(client, true))
    SetChatAdmin(client);
  return;
}

public void OnClientDisconnect_Post(int client)
{
  g_bIsChatAdmin[client] = false;
  g_PlayerTeam[client] = TFTeam_Unassigned;
  return;
}

public Action Listener_Say(int client, char[] command, int args)
{
  if(!g_bEnabled || client < 1 || client > MaxClients)
    return Plugin_Continue; // Only use enable here for mid-game toggling

  char msg[256];
  GetCmdArg(1, msg, sizeof(msg));

  char colour[8], teamStr[11] = "", deadStr[10] = ""; // teamStr = "SPECTATOR" + \0 + 1
  bool bDead = !IsPlayerAlive(client);

  switch(g_PlayerTeam[client])
  {
    case TFTeam_Spectator:
    {
      // Spectators are always dead, dont add text.
      Format(teamStr, sizeof(teamStr), "%T", "SM_CHATVISION_Spectator", LANG_SERVER);
      colour = COL_SPEC;
    }

    case TFTeam_Red:
    {
      if(bDead)
        Format(deadStr, sizeof(deadStr), "%T", "SM_CHATVISION_Dead", LANG_SERVER);
      Format(teamStr, sizeof(teamStr), "%T", "SM_CHATVISION_Enemy", LANG_SERVER);
      colour = COL_RED;
    }

    case TFTeam_Blue:
    {
      if(bDead)
        Format(deadStr, sizeof(deadStr), "%T", "SM_CHATVISION_Dead", LANG_SERVER);
      Format(teamStr, sizeof(teamStr), "%T", "SM_CHATVISION_Enemy", LANG_SERVER);
      colour = COL_BLU;
    }
  }

  for(int i = 1; i <= MaxClients; ++i)
  {
    if(g_bIsChatAdmin[i]
      && g_PlayerTeam[i] != TFTeam_Unassigned
      && g_PlayerTeam[i] != g_PlayerTeam[client])
    {
      PrintToChat(i, "\x01%s(%s) %s%N\x01 :  %s", // *DEAD*(ENEMY) Bob :  Some message
        deadStr,
        teamStr,
        colour,
        client,
        msg);
    }
  }
  return Plugin_Continue;
}

public Action Listener_ReloadAdmins(int client, char[] command, int args)
{
  ReloadChatAdmins();
  return Plugin_Continue;
}

public Action Event_TeamChange(Handle event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid", -1));

  if(client > 0 && client <= MaxClients)
  {
    switch(GetEventInt(event, "team", -1)) // TF2_GetClientTeam does not work here
    {
      case 1: g_PlayerTeam[client]  = TFTeam_Spectator;
      case 2: g_PlayerTeam[client]  = TFTeam_Red;
      case 3: g_PlayerTeam[client]  = TFTeam_Blue;
      default: g_PlayerTeam[client] = TFTeam_Unassigned;
    }
  }
  return Plugin_Continue;
}



/**
 * Reloads all chat admins
 *
 * sm_chatvision_reload
 */
public Action CMD_ReloadChatVision(int client, int args)
{
  ReloadChatAdmins();
  TagReply(client, "%T", "SM_CHATVISION_Reload", client);
  return Plugin_Handled;
}

/**
 * Check if a certain player can see enemy team chat
 *
 * sm_ischatadmin <Target>
 */
public Action CMD_IsChatAdmin(int client, int args)
{
  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_CHATADMIN_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  int target = FindTarget(client, arg1, true, false); // No bots or immunity
  if(target == -1)
    return Plugin_Handled;

  GetClientName(target, arg1, sizeof(arg1)); // To print back to client

  if(g_bIsChatAdmin[target])
    TagReply(client, "%T", "SM_CHATADMIN_True", client, arg1);
  else
    TagReply(client, "%T", "SM_CHATADMIN_False", client, arg1);
  return Plugin_Handled;
}

stock void ReloadChatAdmins()
{
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
      SetChatAdmin(i);
  }
  return;
}

stock void SetChatAdmin(int client)
{
  g_bIsChatAdmin[client] = CheckCommandAccess(client, "sm_chatvision_access", ADMFLAG_KICK, true);
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
