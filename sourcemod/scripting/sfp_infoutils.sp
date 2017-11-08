#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <sdktools>
#include <basecomm>
#include <geoip>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/infoutils_update.txt"
#define MAX_STEAMID_SIZE 64

#define _INCLUDE_AMIMUTED
#define _INCLUDE_CANPLAYERHEAR
#define _INCLUDE_LOCATEIP
#define _INCLUDE_ID
#define _INCLUDE_PROFILE
#define _INCLUDE_CHECKRESTART
#define _INCLUDE_JOINGROUP

// List of commands that can be disabled.
// Set by CVar, updated in ProcessDisabledCmds, Checked in Command.
enum CommandNames {
  ComAMIMUTED = 0,
  ComCANPLAYERHEAR,
  ComLOCATEIP,
  ComPLAYERID,
  ComPROFILECMD,
  ComGETPROFILE,
  ComCHECKRESTART,
  ComJOINGROUP,
  ComTOTAL
};


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
Handle  h_bDisabledCmds = null;
bool    g_bDisabledCmds[ComTOTAL];

#if defined _INCLUDE_CHECKRESTART
bool    g_bRestartRequested = false;
#endif

#if defined _INCLUDE_ID
Handle  h_bIdIgnoreImmunity = null;
bool    g_bIdIgnoreImmunity;
#endif

#if defined _INCLUDE_PROFILE
Handle  h_bProfileIgnoreImmunity = null;
bool    g_bProfileIgnoreImmunity;
#endif

#if defined _INCLUDE_JOINGROUP
Handle  h_szJoinGroup = null;
char    g_szJoinGroupTitle[64];
char    g_szJoinGroupUrl[192];
#endif


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Info Utils",
  author =      "SirDigby",
  description = "Brought to You by The N.S.A",
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

  h_bDisabledCmds = CreateConVar("sm_infoutils_disabledcmds", "", "List of Disabled Commands, separated by space.\nCommands (Case-sensitive):\n- AmIMuted\n- CanPlayerHear\n- LocateIP\n- PlayerID\n- ProfileCmd\n- GetProfile\n- CheckRestart\n- JoinGroup", FCVAR_SPONLY);
  ProcessDisabledCmds();
  HookConVarChange(h_bDisabledCmds, UpdateCvars);


  #if defined _INCLUDE_ID
  h_bIdIgnoreImmunity = CreateConVar("sm_infoutils_id_noimmunity", "0", "Ignore Target Immunity with sm_id\n(Default: 0)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bIdIgnoreImmunity = GetConVarBool(h_bIdIgnoreImmunity);
  HookConVarChange(h_bIdIgnoreImmunity, UpdateCvars);
  #endif

  #if defined _INCLUDE_PROFILE
  h_bProfileIgnoreImmunity = CreateConVar("sm_infoutils_profile_noimmunity", "0", "Ignore Target Immunity with sm_profile\n(Default: 0)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bProfileIgnoreImmunity = GetConVarBool(h_bProfileIgnoreImmunity);
  HookConVarChange(h_bProfileIgnoreImmunity, UpdateCvars);
  #endif

  #if defined _INCLUDE_JOINGROUP
  h_szJoinGroup = CreateConVar("sm_infoutils_group", "Join Our Group!;https://store.steampowered.com/", "Title and URL for sm_joingroup, separated by semicolon. Max 255 characters.", FCVAR_NONE);
  ProcessJoinGroupCvar();
  HookConVarChange(h_szJoinGroup, UpdateCvars);
  #endif


  #if defined _INCLUDE_AMIMUTED
  RegConsoleCmd("sm_amigagged",   CMD_MuteGagStatus, "Check if you are gagged/muted");
  RegConsoleCmd("sm_amimuted",    CMD_MuteGagStatus, "Check if you are gagged/muted");
  #endif

  #if defined _INCLUDE_CANPLAYERHEAR
  RegAdminCmd("sm_canplayerhear", CMD_HearCheck, ADMFLAG_BAN, "Check if a player can hear another");
  RegAdminCmd("sm_canhear", CMD_HearCheck, ADMFLAG_BAN, "Check if a player can hear another");
  #endif

  #if defined _INCLUDE_LOCATEIP
  RegAdminCmd("sm_locateip", CMD_LocateIP, ADMFLAG_BAN, "Get IP Location");
  #endif

  #if defined _INCLUDE_ID
  RegConsoleCmd("sm_id",  CMD_PlayerID, "Get a Player's SteamID");
  #endif

  #if defined _INCLUDE_PROFILE
  RegConsoleCmd("sm_profile",  Cmd_Profile, "Display a Player's Steam Profile");
  RegConsoleCmd("sm_getprofile",  Cmd_GetProfile, "Get a Player's Steam Profile URL");
  #endif

  #if defined _INCLUDE_CHECKRESTART
  RegConsoleCmd("sm_checkforupdate", CMD_CheckRestartRequest, "Check if Valve has sent a Restart Request to the Server");
  #endif

  #if defined _INCLUDE_JOINGROUP
  RegConsoleCmd("sm_joingroup", CMD_JoinGroup, "Display the group for the server");
  #endif

  /**
   * These commands dont really need target-override checks,
   * since they dont DO anything to others.
   */

  PrintToServer("%T", "SFP_InfoUtilsLoaded", LANG_SERVER);
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
  else if(cvar == h_bIdIgnoreImmunity)
    g_bIdIgnoreImmunity = GetConVarBool(h_bIdIgnoreImmunity);
  else if(cvar == h_bProfileIgnoreImmunity)
    g_bProfileIgnoreImmunity = GetConVarBool(h_bProfileIgnoreImmunity);
  else if(cvar == h_szJoinGroup)
    ProcessJoinGroupCvar();
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
  if(StrContains(buffer, "AmIMuted", true) != -1)
    g_bDisabledCmds[ComAMIMUTED] = true;

  if(StrContains(buffer, "CanPlayerHear", true) != -1)
    g_bDisabledCmds[ComCANPLAYERHEAR] = true;

  if(StrContains(buffer, "LocateIP", true) != -1)
    g_bDisabledCmds[ComLOCATEIP] = true;

  if(StrContains(buffer, "PlayerID", true) != -1)
    g_bDisabledCmds[ComPLAYERID] = true;

  if(StrContains(buffer, "ProfileCmd", true) != -1)
    g_bDisabledCmds[ComPROFILECMD] = true;

  if(StrContains(buffer, "GetProfile", true) != -1)
    g_bDisabledCmds[ComGETPROFILE] = true;

  if(StrContains(buffer, "CheckRestart", true) != -1)
    g_bDisabledCmds[ComCHECKRESTART] = true;

  if(StrContains(buffer, "JoinGroup", true) != -1)
    g_bDisabledCmds[ComJOINGROUP] = true;

  return;
}


public Action Steam_RestartRequested()
{
  g_bRestartRequested = true;
  return Plugin_Continue;
}

#if defined _INCLUDE_JOINGROUP
void ProcessJoinGroupCvar() // TODO: Verify
{
  char cvarStr[256];
  GetConVarString(h_szJoinGroup, cvarStr, sizeof(cvarStr));

  int part2Idx = SplitString(cvarStr, ";", g_szJoinGroupTitle, sizeof(g_szJoinGroupTitle));
  if(part2Idx == -1)
  {
    g_szJoinGroupTitle  = "Join Our Group!";
    strcopy(g_szJoinGroupUrl, sizeof(g_szJoinGroupUrl), cvarStr);
    return;
  }

  strcopy(g_szJoinGroupUrl, sizeof(g_szJoinGroupUrl), cvarStr[part2Idx]);
}
#endif



/**
 * Check if you're muted or gagged.
 *
 * sm_amimuted or sm_amigagged
 */
#if defined _INCLUDE_AMIMUTED
public Action CMD_MuteGagStatus(int client, int args)
{
  if(g_bDisabledCmds[ComAMIMUTED])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(!IsClientPlaying(client))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }

  bool bMuted = BaseComm_IsClientMuted(client);
  bool bGagged = BaseComm_IsClientGagged(client);

  if(bMuted)
  {
    if(bGagged)
      TagReply(client, "%T", "SM_AMIMUTED_MuteGag", client);
    else
      TagReply(client, "%T", "SM_AMIMUTED_Mute", client);
  }
  else
  {
    if(bGagged)
      TagReply(client, "%T", "SM_AMIMUTED_Gag", client);
    else
      TagReply(client, "%T", "SM_AMIMUTED_None", client);
  }
  return Plugin_Handled;
}
#endif



/**
 * Check if a player can hear another certain player.
 *
 * sm_canplayerhear <Target 1> [Target 2]
 */
#if defined _INCLUDE_CANPLAYERHEAR
public Action CMD_HearCheck(int client, int args)
{
  if(g_bDisabledCmds[ComCANPLAYERHEAR])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_CANHEAR_Usage", client);
    return Plugin_Handled;
  }

  if(!IsClientPlaying(client))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }

  // Get First Target
  char arg1[MAX_NAME_LENGTH], targ1Name[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  int targ1 = FindTarget(client, arg1, true, false); // No bots or immunity
  if(targ1 == -1)
    return Plugin_Handled;
  GetClientName(targ1, targ1Name, sizeof(targ1Name));


  // Get Second Target. Default to Client
  int targ2;
  char targ2Name[MAX_NAME_LENGTH];
  if(args > 1)
  {
    char arg2[MAX_NAME_LENGTH];
    GetCmdArg(2, arg2, sizeof(arg2));
    targ2 = FindTarget(client, arg2, true, false); // No bots or immunity
    if(targ2 == -1)
      return Plugin_Handled;
    GetClientName(targ2, targ2Name, sizeof(targ2Name));
  }
  else
    targ2 = client;

  // Output
  if(targ1 == targ2)
  {
    TagReply(client, "%T", "SM_CANHEAR_SelfTarget", client);
    return Plugin_Handled;
  }

  if(IsClientMuted(targ1, targ2))
  {
    if(targ2 == client)
      TagReply(client, "%T", "SM_CANHEAR_True_Self", client, targ1Name);
    else
      TagReply(client, "%T", "SM_CANHEAR_True", client, targ1Name, targ2Name);
  }
  else
  {
    if(targ2 == client)
      TagReply(client, "%T", "SM_CANHEAR_False_Self", client, targ1Name);
    else
      TagReply(client, "%T", "SM_CANHEAR_False", client, targ1Name, targ2Name);
  }
  return Plugin_Handled;
}
#endif



/**
 * Get the GeoIP Location of a Client
 *
 * sm_locateip <Target>
 */
#if defined _INCLUDE_LOCATEIP
public Action CMD_LocateIP(int client, int args)
{
  if(g_bDisabledCmds[ComLOCATEIP])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_LOCATE_Usage", client);
    return Plugin_Handled;
  }

  // Get Target
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  int target = FindTarget(client, arg1, true);
  if(target == -1)
    return Plugin_Handled;

  // Get IP
  char targIP[32];
  if(!GetClientIP(target, targIP, sizeof(targIP)))
  {
    TagReply(client, "%T", "SM_LOCATE_IPFail", client);
    return Plugin_Handled;
  }

  // Get Name
  char clientName[MAX_NAME_LENGTH];
  GetClientName(target, clientName, sizeof(clientName));

  // Get Country and output
  char country[64];
  if(GeoipCountry(targIP, country, sizeof(country)))
    TagReply(client, "%T", "SM_LOCATE_Done", client, clientName, country);
  else
    TagReply(client, "%T", "SM_LOCATE_CountryFail", client);

  return Plugin_Handled;
}
#endif



/**
 * Get a player's Steam ID in any format. (2, 3, 64 or engine)
 *
 * sm_id <Target> [ID Type 1-4]
 */
#if defined _INCLUDE_ID
public Action CMD_PlayerID(int client, int args)
{
  if(g_bDisabledCmds[ComPLAYERID])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_PLAYERID_Usage", client);
    return Plugin_Handled;
  }

  // Get Target
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  int target = FindTarget(client, arg1, true, !g_bIdIgnoreImmunity);
  if(target == -1)
    return Plugin_Handled;

  // Get ID Type. Default to 3.
  AuthIdType idType = AuthId_Steam3;
  char idTypeStr[10] = "SteamID3"; // "SteamID64" + \0
  if(args > 1)
  {
    char arg2[4];
    GetCmdArg(2, arg2, sizeof(arg2));
    int val = StringToInt(arg2);
    switch(val)
    {
      case 1:
      {
        idType = AuthId_Engine;
        idTypeStr = "EngineID";
      }
      case 2:
      {
        idType = AuthId_Steam2;
        idTypeStr = "SteamID2";
      }
      case 3:
      {
        idType = AuthId_Steam3;
        idTypeStr = "SteamID3";
      }
      case 4:
      {
        idType = AuthId_SteamID64;
        idTypeStr = "SteamID64";
      }
      default:
      {
        TagReplyUsage(client, "%T", "SM_PLAYERID_Usage", client);
        return Plugin_Handled;
      }
    }
  }

  // Get ID and Output
  char idStr[MAX_STEAMID_SIZE], targName[MAX_NAME_LENGTH];
  GetClientAuthId(target, idType, idStr, sizeof(idStr), true);
  GetClientName(target, targName, sizeof(targName));
  TagReply(client, "%T", "SM_PLAYERID_Found", client, targName, idTypeStr, idStr);
  return Plugin_Handled;
}
#endif



/**
 * Get a player's profile through their SteamID64 and display it.
 *
 * sm_profile <Target>
 */
#if defined _INCLUDE_PROFILE
public Action Cmd_Profile(int client, int args)
{
  if(g_bDisabledCmds[ComPROFILECMD])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_PROFILE_Usage", client);
    return Plugin_Handled;
  }

  if(!IsClientPlaying(client))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }

  // Get Target
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  int target = FindTarget(client, arg1, true, !g_bProfileIgnoreImmunity);
  if(target == -1)
    return Plugin_Handled;

  // Get SteamID64
  char idStr[MAX_STEAMID_SIZE];
  GetClientAuthId(target, AuthId_SteamID64, idStr, sizeof(idStr), true);

  // Show page
  char pageUrl[192];
  Format(pageUrl, sizeof(pageUrl), "https://steamcommunity.com/profiles/%s/", idStr);
  ShowMOTDUrl(client, "Player Profile", pageUrl);
  return Plugin_Handled;
}

/**
 * Get a player's profile through their SteamID64 and print to client.
 *
 * sm_getprofile <Target>
 */
public Action Cmd_GetProfile(int client, int args)
{
  if(g_bDisabledCmds[ComGETPROFILE])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_GETPROFILE_Usage", client);
    return Plugin_Handled;
  }

  // Get Target
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  int target = FindTarget(client, arg1, true, !g_bProfileIgnoreImmunity);
  if(target == -1)
    return Plugin_Handled;

  // Get SteamID64
  char idStr[MAX_STEAMID_SIZE];
  GetClientAuthId(target, AuthId_SteamID64, idStr, sizeof(idStr), true);

  // Get Full Name, in case arg1 was a partial name
  GetClientName(target, arg1, sizeof(arg1));

  // Show page
  char pageUrl[192];
  Format(pageUrl, sizeof(pageUrl), "https://steamcommunity.com/profiles/%s/", idStr);
  TagReply(client, "%T", "SM_GETPROFILE_Done", client, arg1, pageUrl);
  return Plugin_Handled;
}
#endif

/**
 * Display an MOTD page with a given url
 */
stock void ShowMOTDUrl(int client, char[] title, char[] url)
{
  Handle setup = CreateKeyValues("data", "", "");
  if(setup == null)
  {
    LogError("ShowMOTDUrl::Setup handle failed to init.");
    return;
  }
  KvSetString(setup, "title", title);
  KvSetNum(setup, "type", 2);
  KvSetString(setup, "msg", url);
  KvSetNum(setup, "customsvr", 1);
  ShowVGUIPanel(client, "info", setup, true);
  return;
}



/**
 * Check if an update has been issued since the map started.
 *
 * sm_checkforupdate
 */
#if defined _INCLUDE_CHECKRESTART
public Action CMD_CheckRestartRequest(int client, int args)
{
  if(g_bDisabledCmds[ComCHECKRESTART])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if (g_bRestartRequested)
    TagReply(client, "%T", "SM_CHECKRESTART_True", client);
  else
    TagReply(client, "%T", "SM_CHECKRESTART_False", client);
  return Plugin_Handled;
}
#endif



/**
 * Show player the server's group page
 *
 * sm_joingroup
 */
#if defined _INCLUDE_JOINGROUP
public Action CMD_JoinGroup(int client, int args)
{
  if(g_bDisabledCmds[ComJOINGROUP])
  {
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    TagReply(client, "%T", "SFP_CmdDisabled", client, arg0);
    return Plugin_Handled;
  }

  if(!IsClientPlaying(client))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }

  ShowMOTDUrl(client, g_szJoinGroupTitle, g_szJoinGroupUrl);
  return Plugin_Handled;
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
