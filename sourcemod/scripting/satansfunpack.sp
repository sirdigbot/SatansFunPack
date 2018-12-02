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
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>
#include <sfh_chatlib>


//=================================
// Constants
#define PLUGIN_VERSION  "1.1.1"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/main_update.txt"


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
char    g_szList[222] = "MODULE - INSTALLED(Y/N)\n--------\n";


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack",
  author =      "SirDigby",
  description = "A Megapack of Commands",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};


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



/***
 * This file doesn't do a lot, but it's a common hub we can attach
 * any shared files to for updating.
 *
 * As such, this is the ONLY required file.
 ***/
public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");

  CreateConVar("satansfunpack_version", PLUGIN_VERSION, "Satan's Fun Pack version. Do Not Touch!", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

  h_bUpdate = CreateConVar("sm_satansfunpack_update", "1", "Update this Plugin Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  RegAdminCmd("sm_sfpplugincheck", CMD_InstallCheck, ADMFLAG_ROOT, "Check which Satan's Fun Pack Modules are Installed");
  RegAdminCmd("sm_sfpsource", CMD_PluginPackSource, ADMFLAG_ROOT, "Get the URL to Satan's Fun Pack's Source Code");

  /**
   * Check what modules are installed and cache list.
   * Expensive so do only OnPluginStart.
   **/
  int count = 0;
  count += CheckFileAndCache("AdminTools", "plugins/sfp_admintools.smx");
  count += CheckFileAndCache("Bans", "plugins/sfp_bans.smx");
  count += CheckFileAndCache("ChatVision", "plugins/sfp_chatvision.smx");
  count += CheckFileAndCache("GodMode", "plugins/sfp_godmode.smx");
  count += CheckFileAndCache("HelpMenu", "plugins/sfp_help.smx");
  count += CheckFileAndCache("InfoUtils", "plugins/sfp_infoutils.smx");
  count += CheckFileAndCache("Mirror", "plugins/sfp_mirror.smx");
  count += CheckFileAndCache("MiscTweaks", "plugins/sfp_misctweaks.smx");
  count += CheckFileAndCache("NameColour", "plugins/sfp_namecolour.smx");
  count += CheckFileAndCache("QuickConditions", "plugins/sfp_quickconditions.smx");
  count += CheckFileAndCache("Targeting", "plugins/sfp_targeting.smx");
  count += CheckFileAndCache("ToyBox", "plugins/sfp_toybox.smx");
  count += CheckFileAndCache("Votes", "plugins/sfp_votes.smx");
  PrintToServer("%T", "SFP_Loaded", LANG_SERVER, count);
}

void OnConfigsExecuted_Main()
{
  CreateTimer(600.0, Timer_ServerRunningSFP, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
  return;
}


int CheckFileAndCache(const char[] pluginName, const char[] filepath)
{
  char path[PLATFORM_MAX_PATH], buffer[32];
  bool result;

  BuildPath(Path_SM, path, PLATFORM_MAX_PATH, filepath);
  result = FileExists(path);

  Format(buffer, sizeof(buffer), "%s - %s", pluginName, (result) ? "Y\n" : "N\n");
  StrCat(g_szList, sizeof(g_szList), buffer);
  return view_as<int>(result);
}


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = view_as<bool>(StringToInt(newValue));
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  return;
}



public Action CMD_InstallCheck(int client, int args)
{
  PrintToConsole(client, g_szList);
  if(client != 0 && GetCmdReplySource() == SM_REPLY_TO_CHAT)
    TagReply(client, "%T", "SFP_ConsoleOutput", client);

  return Plugin_Handled;
}


public Action CMD_PluginPackSource(int client, int args)
{
  TagReply(client, "%T", "SFP_PluginPackSource", client, PLUGIN_URL);
  return Plugin_Handled;
}

public Action Timer_ServerRunningSFP(Handle timer)
{
  CPrintToChatAll("%T", "SFP_Advert", LANG_SERVER, PLUGIN_VERSION);
  return Plugin_Continue;
}



//=================================
// Updater
public void OnConfigsExecuted()
{
  if(LibraryExists("updater") && g_bUpdate)
    Updater_AddPlugin(UPDATE_URL);
  OnConfigsExecuted_Main();
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
