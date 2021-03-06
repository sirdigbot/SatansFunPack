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
#include <regex>
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
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/bans_update.txt"

//#define _TESTCOMMAND    // Enable sm_sfp_bans_runtests
//#define _QUERYDEBUG     // Enable logging of all variable SQL Queries

#define LOG_PREFIX        "sfpbans_"
#define INT_MAX_32        2147483647
#define INT_LENGTH        11 // "2147483647" + \0
#define AUTH_MAX          21
#define AUTH_SANITISE     (AUTH_MAX * 2) + 1
#define NAME_SANITISE     (MAX_NAME_LENGTH * 2) + 1
#define MSG_MAX           128
#define MSG_SANITISE      (MSG_MAX * 2) + 1     // Reason and Note size in database
#define FULLRESET_TIMEOUT 10.0

enum BanType
{
  Ban_SteamId,
  Ban_IPAddress
};

enum IDType
{
  Invalid_Id = -1,
  Steam_2,
  Steam_2_Uscore,
  Steam_3,
  Ip_Addr
};

#define ADDBANQUERY       "REPLACE INTO bannedusers (steamid3, steamid2, ip_address, ban_type, permanent, player_name, utc_issued, duration_sec, reason, admin_id3, admin_name, last_modified, modifier_id, modifier_name) VALUES (%s, %s, %s, %i, %i, '%s', CAST(strftime('%%s', 'now') AS INTEGER), %i, '%s', '%s', '%s', CAST(strftime('%%s', 'now') AS INTEGER), '%s', '%s');"
#define ADDBANQUERY_SIZE  (5*AUTH_SANITISE) + (4*INT_LENGTH) + (3*NAME_SANITISE) + MSG_SANITISE + 343  // Max Size of Inputs + strlen(ADDBANQUERY) + \0
#define ADDBANQUERY_LOG   192 // Start Index in ADDBANQUERY for Logging (Log Line Length is 318)

// Delete expired bans, or IP bans older than g_iMaxIPBanDays
#define CLEANQUERY        "DELETE FROM bannedusers WHERE permanent!=1 AND ((utc_issued + duration_sec < CAST(strftime('%%s', 'now') AS INTEGER)) OR (ban_type=1 AND CAST(strftime('%%s', 'now') AS INTEGER) - utc_issued > (%i*86400)));"
#define CLEANQUERY_SIZE   INT_LENGTH + 206

// Select bans that haven't expired by steamid, or ip (only if ban_type is Ban_IPAddress)
// For ip bans, only select if ban was also issued < g_iMaxIPBanDays ago
// In case of both IP and ID ban existing, order by latest expire date
#define JOINQUERY         "SELECT utc_issued, duration_sec, reason FROM bannedusers WHERE ((ban_type=0 AND %s='%s') OR (ban_type=1 AND ip_address='%s')) AND (permanent=1 OR (((utc_issued + duration_sec >= CAST(strftime('%%s', 'now') AS INTEGER)) AND (ban_type=0 OR (ban_type=1 AND CAST(strftime('%%s', 'now') AS INTEGER) - utc_issued < (%i*86400)))))) ORDER BY utc_issued + duration_sec DESC;"
#define JOINQUERY_SIZE    10 + AUTH_SANITISE + AUTH_SANITISE + INT_LENGTH + 366 // 10="ip_address"
#define JOINQUERY_LOG     80

//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;

Handle  h_Database      = null;
Handle  h_iMaxLogDays   = null;
int     g_iMaxLogDays;          // How long can a log file exist for
char    g_szLogFile[PLATFORM_MAX_PATH];
Handle  h_iMaxIPBanDays = null;
int     g_iMaxIPBanDays;        // How long before IP bans are cleared. (IPs change frequently)
Handle  h_RegexSteam2   = null; // STEAM_0:1:23456789
Handle  h_RegexSteam2US = null; // STEAM_0_1_23456789
Handle  h_RegexSteam3   = null; // [U:1:23456789]

Handle  h_iFullResetTimer       = null;   // Timer Handle to auto-cancel full reset
bool    g_bFullResetInUse       = false;  // Used to disable full-reset between rounds.
int     g_iFullResetClient;
int     g_iFullResetPendingNum  = -1;     // Number needed to confirm database reset. (<0 = invalid)

BanType g_iBrowseMenuType[MAXPLAYERS + 1]; // To display the correct text in sm_browsebans' menu

/**
 * Known Bugs
 * - OnBanClient and OnBanIdentity reasons do not limit at MSG_MAX
 * - sm_editban will reply that the ban has been successfully edited, even if it doesn't exist
 * - MSG_MAX is likely excessively higher than what sm_ban, sm_addban and sm_banip can type ingame
 * - No way to undo ban removals/full reset. There should be a sm_restoreban command or something
 * - TODO Add quick-unban or quick-edit buttons to browse menu
 *
 * - None of the non-displayed/math-only strftime occurences use 'localtime' modifier.
 *   It's not needed as long as they are all consistent.
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Bans",
  author =      "SirDigby",
  description = "Passive Ban Database",
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
  LoadTranslations("sfp.bans.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");

  char timeStr[64];
  FormatTime(timeStr, sizeof(timeStr), "%Y%m%d");               // 20171225
  BuildPath(Path_SM, g_szLogFile, sizeof(g_szLogFile), "logs/%s%s.log", LOG_PREFIX, timeStr);
  LogGeneric("%t", "SM_BANS_LogStart");

  h_bUpdate = CreateConVar("sm_sfp_bans_update", "1", "Update Satan's Fun Pack - Bans Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);


  h_iMaxLogDays = CreateConVar("sm_sfp_bans_logdays", "14", "How many days log files are kept for (0 = Forever)\n(Default: 14)", FCVAR_NONE, true, 0.0);
  g_iMaxLogDays = GetConVarInt(h_iMaxLogDays);
  HookConVarChange(h_iMaxLogDays, UpdateCvars);

  h_iMaxIPBanDays = CreateConVar("sm_sfp_bans_ipban_max", "1", "How many days IP Bans are stored for before expiring\n(Default: 1)", FCVAR_NONE, true, 1.0);
  g_iMaxIPBanDays = GetConVarInt(h_iMaxIPBanDays);
  HookConVarChange(h_iMaxIPBanDays, UpdateCvars);

  InitDatabase(); // Must come after log file and h_iMaxIPBanDays CreateConVar


  // These should handle all variation in steamids, as documented on the valve wiki
  h_RegexSteam2 = CompileRegex("^[A-Za-z]{2,}[_][0-9]{1}(:0:|:1:){1}[0-9]{1,}$");
  h_RegexSteam2US = CompileRegex("^[A-Za-z]{2,}[_][0-9]{1}(_0_|_1_){1}[0-9]{1,}$");
  h_RegexSteam3 = CompileRegex("^[[](I|U|M|G|A|P|C|g|T|c|L|a){1}[:][0-9]{1}[:][0-9]{1,}([:][0-9])?[]]$");

  if(h_RegexSteam2 == null || h_RegexSteam2US == null || h_RegexSteam3 == null)
  {
    LogGeneric("%t", "SM_BANS_RegexFail");
    SetFailState("%T", "SM_BANS_RegexFail", LANG_SERVER);
    return;
  }


  RegAdminCmd("sm_cleanbanlogs",  CMD_CleanLogs,  ADMFLAG_GENERIC, "Delete old plugin logs");
  RegAdminCmd("sm_cleanbans",     CMD_CleanBans,  ADMFLAG_BAN, "Wipe expired bans from database");
  RegAdminCmd("sm_editban",       CMD_EditBan,    ADMFLAG_BAN, "Edit an existing ban");
  RegAdminCmd("sm_isbanned",      CMD_IsBanned,   ADMFLAG_GENERIC, "Check if a player is banned");
  RegAdminCmd("sm_browsebans",    CMD_BrowseBans, ADMFLAG_GENERIC, "Browse Ban Database");
  RegAdminCmd("sm_sfp_bans_full_reset", CMD_FullReset,  ADMFLAG_ROOT, "Reset the entire ban database");
  #if defined _TESTCOMMAND
  RegAdminCmd("sm_sfp_bans_runtests",   CMD_RunTests,   ADMFLAG_ROOT, "Run Function Tests");
  #endif

  HookEvent("teamplay_round_win",   OnRoundEnd,     EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_start", OnRoundStart,   EventHookMode_PostNoCopy);

  PrintToServer("%T", "SFP_BansLoaded", LANG_SERVER);
}



public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_iMaxLogDays)
    g_iMaxLogDays = StringToInt(newValue); // Dont clear logs. Allow undoing before map change.
  else if(cvar == h_iMaxIPBanDays)
    g_iMaxIPBanDays = StringToInt(newValue);
  return;
}


/**
 * Clear any expired logs.
 * Called after OnPluginStart()
 */
public void OnMapStart()
{
  // Not all servers restart daily, so this shouldn't be in OnPluginStart
  // Cleaning bans is not as important because they wont have an effect if expired
  ClearExpiredLogs();
  return;
}


/**
 * Handle g_bFullResetInUse on map changes
 */
public Action OnRoundStart(Handle event, char[] name, bool dontBroadcast)
{
  g_bFullResetInUse = false;
  return Plugin_Continue;
}

public Action OnRoundEnd(Handle event, char[] name, bool dontBroadcast)
{
  ClearFullReset();
  g_bFullResetInUse = true; // Will make fullreset unusable as client idx is reset to -1
  return Plugin_Continue;
}




//=================================
// Init Functions

/**
 * Connect to Database, Create and/or Cleann Table
 */
void InitDatabase()
{
  char err[128];
  h_Database = SQLite_UseDatabase("SatansBanDB", err, sizeof(err)); // Create file automatically
  if(h_Database == null)
  {
    delete h_Database;
    LogGeneric("%t", "SM_BANS_DBConnectFail", err);
    SetFailState("%T", "SM_BANS_DBConnectFail", LANG_SERVER, err);
    return;
  }

  LogGeneric("%t", "SM_BANS_DBConnectSuccess");

  SQL_LockDatabase(h_Database);
  CreateDatabaseTable();
  InitCleanDatabase();
  SQL_UnlockDatabase(h_Database);
  return;
}

/**
 * Used to create a 'bannedusers' table
 * Must lock the database before calling.
 */
void CreateDatabaseTable()
{
  SQL_FastQuery(h_Database,
    "CREATE TABLE IF NOT EXISTS `bannedusers` \
    (`banid` INTEGER, \
      `steamid3` TEXT UNIQUE, \
      `steamid2` TEXT UNIQUE, \
      `ip_address` TEXT UNIQUE, \
      `ban_type` INTEGER NOT NULL, \
      `permanent` INTEGER NOT NULL, \
      `player_name` TEXT NOT NULL, \
      `utc_issued` INTEGER NOT NULL, \
      `duration_sec` INTEGER NOT NULL, \
      `reason` TEXT, \
      `admin_id3` TEXT NOT NULL, \
      `admin_name` TEXT NOT NULL, \
      `admin_note` TEXT, \
      `last_modified` INTEGER NOT NULL, \
      `modifier_id` TEXT NOT NULL, \
      `modifier_name` TEXT NOT NULL, \
      PRIMARY KEY(`banid`));");
  return;
}

/**
 * Clean the database of expired bans, or IP bans older than g_iMaxIPBanDays
 * Must lock the database before calling.
 */
void InitCleanDatabase()
{
  char query[CLEANQUERY_SIZE];
  Format(query, sizeof(query), CLEANQUERY, g_iMaxIPBanDays);
  SQL_FastQuery(h_Database, query);
  LogGeneric("%t", "SM_CLEANBANS_Cleaned");
  return;
}



/**
 * Clears logs older in days than g_iMaxLogDays
 * 0 = Don't delete old logs
 */
void ClearExpiredLogs()
{
  if(g_iMaxLogDays == 0)
    return;

  char logsPath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, logsPath, sizeof(logsPath), "logs");
  if(DirExists(logsPath))
  {
    Handle hDir = OpenDirectory(logsPath);
    if(hDir == null)
    {
      delete hDir;
      return;
    }

    char buff[256];
    FileType type = FileType_Unknown;
    while(ReadDirEntry(hDir, buff, sizeof(buff), type)) // Get File. Store name+ext in buff
    {
      if(type == FileType_File && StrContains(buff, LOG_PREFIX, true) == 0)
      {
        // Get file's full path for GetFileTime
        char filePath[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, filePath, sizeof(filePath), "logs/%s", buff);
        int fileUTC = GetFileTime(filePath, FileTime_LastChange);

        if(fileUTC != -1 && GetTime() - fileUTC > (g_iMaxLogDays * 86400)) // seconds in a day
        {
          if(DeleteFile(filePath))
            LogGeneric("%t", "SM_BANS_LogDelete", filePath);
          else
            LogGeneric("%t", "SM_BANS_LogDeleteFail", filePath);
        }
      }
    }
    delete hDir;
  }
  return;
}




//=================================
// Commands/Entry Points

/**
 * Called when the BanClient function is run. (sm_ban)
 * Adds ban to database
 */
public Action OnBanClient(
  int client,
  int time,
  int flags,
  const char[] reason,
  const char[] kick_message,
  const char[] command,
  any source)
{
  // Ignore Invalid Clients
  if(client < 1 || client > MaxClients || !IsClientInGame(client))
    return Plugin_Continue;

  int IsPermaBan = 0;
  if(time <= 0)
  {
    IsPermaBan = 1;
    time = GetPermabanMinutes(); // Get maximum possible minutes for bans
  }

  BanType type = (flags & BANFLAG_IP) ? Ban_IPAddress : Ban_SteamId;

  // Get Client Raw Info
  char steamId2[AUTH_MAX], steamId3[AUTH_MAX], ipAddress[AUTH_MAX], clientName[MAX_NAME_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, steamId2, sizeof(steamId2), true);
  GetClientAuthId(client, AuthId_Steam3, steamId3, sizeof(steamId3), true);
  GetClientIP(client, ipAddress, sizeof(ipAddress));
  GetClientName(client, clientName, sizeof(clientName));

  // Validate Client SteamIDs and IP Address
  bool validSteam2 = true, validSteam3 = true;
  if(!MatchRegex(h_RegexSteam2, steamId2))
  {
    LogGeneric("%t", "SM_ONBAN_RetrieveFail",
      "SteamID2",
      clientName,
      steamId2,
      steamId3,
      ipAddress);
    validSteam2 = false;
  }
  if(!MatchRegex(h_RegexSteam3, steamId3))
  {
    LogGeneric("%t", "SM_ONBAN_RetrieveFail",
      "SteamID3",
      clientName,
      steamId2,
      steamId3,
      ipAddress);
    validSteam3 = false;
    if(type == Ban_SteamId && !validSteam2) // If both IDs fail, we cant convert
    {
      LogGeneric("%t", "SM_ONBAN_NotBanned");
      return Plugin_Continue;
    }
  }
  if(!IsValidIPv4(ipAddress))
  {
    LogGeneric("%t", "SM_ONBAN_RetrieveFail",
      "IP",
      clientName,
      steamId2,
      steamId3,
      ipAddress);
    if(type == Ban_IPAddress) // No alternative for getting IP
    {
      LogGeneric("%t", "SM_ONBAN_NotBanned");
      return Plugin_Continue;
    }
  }

  // Convert Client SteamIDs if either one is missing (both missing is handled above)
  if(!validSteam2 && validSteam3)
    SteamID3ToID2(steamId3, steamId2, sizeof(steamId2));
  else if(validSteam2 && !validSteam3)
    SteamID2ToID3(steamId2, steamId3, sizeof(steamId3));


  // Get Admin Raw Info (Checking isn't important)
  char admin_steamId3[AUTH_MAX], admin_name[MAX_NAME_LENGTH];
  if(source > 0 && source <= MaxClients)
  {
    GetClientAuthId(source, AuthId_Steam3, admin_steamId3, sizeof(admin_steamId3), true);
    GetClientName(source, admin_name, sizeof(admin_name));
  }
  else
  {
    Format(admin_steamId3, sizeof(admin_steamId3), "%T", "SM_ONBAN_Unknown", LANG_SERVER);
    Format(admin_name, sizeof(admin_name), "%T", "SM_ONBAN_Unknown", LANG_SERVER);
  }

  // Sanitise Inputs (Mind the variable names)
  char id3_san[AUTH_SANITISE], id2_san[AUTH_SANITISE], ip_san[AUTH_SANITISE];
  char name_san[NAME_SANITISE], reason_san[MSG_SANITISE];
  char adminId3_san[AUTH_SANITISE], adminName_san[NAME_SANITISE];
  SQL_EscapeString(h_Database, steamId3,        id3_san,        sizeof(id3_san));
  SQL_EscapeString(h_Database, steamId2,        id2_san,        sizeof(id2_san));
  SQL_EscapeString(h_Database, ipAddress,       ip_san,         sizeof(ip_san));
  SQL_EscapeString(h_Database, clientName,      name_san,       sizeof(name_san));
  SQL_EscapeString(h_Database, reason,          reason_san,     sizeof(reason_san));
  SQL_EscapeString(h_Database, admin_steamId3,  adminId3_san,   sizeof(adminId3_san));
  SQL_EscapeString(h_Database, admin_name,      adminName_san,  sizeof(adminName_san));


  // Pre-buffer ID/IP Values (Unknown values must be set to null not 'null')
  // NOTE Keep IDs and IP mutually exclusive for cleaner safety.
  char id3_out[AUTH_SANITISE + 2], id2_out[AUTH_SANITISE + 2], ip_out[AUTH_SANITISE + 2];
  if(type == Ban_SteamId)
  {
    Format(id3_out, sizeof(id3_out), "'%s'", id3_san);
    Format(id2_out, sizeof(id2_out), "'%s'", id2_san);
    ip_out = "null";
  }
  else
  {
    Format(ip_out, sizeof(ip_out), "'%s'", ip_san);
    id3_out = "null";
    id2_out = "null";
  }

  // Create Query
  char query[ADDBANQUERY_SIZE];
  Format(query, sizeof(query),
    ADDBANQUERY,
    id3_out, id2_out, ip_out, view_as<int>(type), IsPermaBan,
    name_san, time*60, reason_san,                              // Convert time to seconds
    adminId3_san, adminName_san, adminId3_san, adminName_san);  // Original Modifier is Admin

  int printTarget = 0;
  if(source > 0 && source <= MaxClients && source != client)
  {
    // Set printTarget to server if source cant accept PrintToChat (after kick)
    printTarget = GetClientUserId(source);
    TagPrintChat(source, "%t", "SM_ONBAN_Querying", (type == Ban_SteamId) ? steamId3 : ipAddress);
  }

  LogGeneric("%t", "SM_ONBAN_Querying_Full",
    admin_name,
    admin_steamId3,
    type,
    IsPermaBan,
    clientName,
    (type == Ban_SteamId) ? steamId3 : ipAddress);

#if defined _QUERYDEBUG
  LogGeneric("OnBanClient QUERY: %s", query[ADDBANQUERY_LOG]);
#endif
  SQL_TQuery(h_Database, Callback_OnBanClient, query, printTarget, DBPrio_Normal);
  return Plugin_Handled; // NOTE Plugin_Handled so client will see our reject msg in OnClientAuth
}

/**
 * Called when the BanIdentity function is run. (sm_banip and sm_addban)
 * Adds ban to database
 */
public Action OnBanIdentity(
  const char[] identity,
  int time,
  int flags,
  const char[] reason,
  const char[] command,
  any source)
{
  int IsPermaBan = 0;
  if(time <= 0)
  {
    IsPermaBan = 1;
    time = GetPermabanMinutes(); // Get maximum possible minutes for bans
  }

  BanType banType = (flags & BANFLAG_IP) ? Ban_IPAddress : Ban_SteamId; // Cant have both flags

  // Get default text for unretrievable data
  char buff[MAX_NAME_LENGTH], unknown[NAME_SANITISE]; // 32 and 32*2 + 1
  Format(buff, sizeof(buff), "%T", "SM_ONBAN_Unknown", LANG_SERVER);
  SQL_EscapeString(h_Database, buff, unknown, sizeof(unknown));


  // Get other SteamID from identity if possible
  char steamId2[AUTH_MAX], steamId3[AUTH_MAX], ipAddress[AUTH_MAX];

  IDType idType = GetBanIdType(identity);
  switch(idType)
  {
    case Steam_3:
    {
      strcopy(steamId3, sizeof(steamId3), identity);
      SteamID3ToID2(identity, steamId2, sizeof(steamId2));
      strcopy(ipAddress, sizeof(ipAddress), unknown);
    }

    case Steam_2:
    {
      strcopy(steamId2, sizeof(steamId2), identity);
      SteamID2ToID3(identity, steamId3, sizeof(steamId3));
      strcopy(ipAddress, sizeof(ipAddress), unknown);
    }

    case Ip_Addr:
    {
      strcopy(ipAddress, sizeof(ipAddress), identity);
      strcopy(steamId3, sizeof(steamId3), unknown);
      strcopy(steamId2, sizeof(steamId2), unknown);
    }

    default:
    {
      LogGeneric("%t", "SM_ONBAN_IdentityFail", identity);
      return Plugin_Continue;
    }
  }



  // Get Admin Raw Info (Checking isn't important)
  char admin_steamId3[AUTH_MAX], admin_name[MAX_NAME_LENGTH];
  if(source > 0 && source <= MaxClients)
  {
    GetClientAuthId(source, AuthId_Steam3, admin_steamId3, sizeof(admin_steamId3), true);
    GetClientName(source, admin_name, sizeof(admin_name));
  }
  else
  {
    Format(admin_steamId3, sizeof(admin_steamId3), "%T", "SM_ONBAN_Unknown", LANG_SERVER);
    Format(admin_name, sizeof(admin_name), "%T", "SM_ONBAN_Unknown", LANG_SERVER);
  }


  // Sanitise Inputs (Mind the variable names)
  char id3_san[AUTH_SANITISE], id2_san[AUTH_SANITISE], ip_san[AUTH_SANITISE];
  char reason_san[MSG_SANITISE], adminId3_san[AUTH_SANITISE], adminName_san[NAME_SANITISE];
  SQL_EscapeString(h_Database, steamId3,        id3_san,        sizeof(id3_san));
  SQL_EscapeString(h_Database, steamId2,        id2_san,        sizeof(id2_san));
  SQL_EscapeString(h_Database, ipAddress,       ip_san,         sizeof(ip_san));
  SQL_EscapeString(h_Database, reason,          reason_san,     sizeof(reason_san));
  SQL_EscapeString(h_Database, admin_steamId3,  adminId3_san,   sizeof(adminId3_san));
  SQL_EscapeString(h_Database, admin_name,      adminName_san,  sizeof(adminName_san));



  // Pre-buffer ID/IP Values (Unknown values must be set to null not 'null')
  // NOTE Keep IDs and IP mutually exclusive for cleaner safety.
  char id3_out[AUTH_SANITISE + 2], id2_out[AUTH_SANITISE + 2], ip_out[AUTH_SANITISE + 2];
  if(banType == Ban_SteamId)
  {
    Format(id3_out, sizeof(id3_out), "'%s'", id3_san);
    Format(id2_out, sizeof(id2_out), "'%s'", id2_san);
    ip_out = "null";
  }
  else
  {
    Format(ip_out, sizeof(ip_out), "'%s'", ip_san);
    id3_out = "null";
    id2_out = "null";
  }


  // Create Query
  char query[ADDBANQUERY_SIZE];
  Format(query, sizeof(query),
    ADDBANQUERY,
    id3_out, id2_out, ip_out, view_as<int>(banType), IsPermaBan,
    unknown, time*60, reason_san, // Convert time to seconds
    adminId3_san, adminName_san, adminId3_san, adminName_san); // Original Modifier is Admin

  // Don't show message if ban target is the admin.
  // This isn't actually an issue with sm_addban and sm_banip
  int printTarget = 0;
  if(source > 0 && source <= MaxClients && !StrEqual(steamId3, admin_steamId3, true))
  {
    // Set printTarget to server if source cant accept PrintToChat (after kick)
    printTarget = GetClientUserId(source);
    TagPrintChat(source, "%t", "SM_ONBAN_Querying", (banType == Ban_SteamId) ? steamId3 : ipAddress);
  }

  LogGeneric("%t", "SM_ONBAN_Querying_Full",
    admin_name,
    admin_steamId3,
    view_as<int>(banType),
    IsPermaBan,
    unknown,
    (banType == Ban_SteamId) ? steamId3 : ipAddress);

#if defined _QUERYDEBUG
  LogGeneric("OnBanIdentity QUERY: %s", query[ADDBANQUERY_LOG]);
#endif
  SQL_TQuery(h_Database, Callback_OnBanClient, query, printTarget, DBPrio_Normal);
  return Plugin_Handled; // NOTE Plugin_Handled so client will see our reject msg in OnClientAuth
}

/**
 * Shared between OnBanClient and OnBanIdentity
 */
public void Callback_OnBanClient(Handle db, Handle result, const char[] err, any data)
{
  int client = (data == 0) ? 0 : GetClientOfUserId(data); // Defaults to server
  
  // Cant GetCmdReplySource
  if(client)
    TagPrintChat(client, "%t", "SM_ONBAN_Done");
  else
    TagPrintServer("%t", "SM_ONBAN_Done");
  return;
}




/**
 * Called when the RemoveBan function is run. (sm_unban)
 * Removes ban from database
 */
public Action OnRemoveBan(
  const char[] identity,
  int flags,
  const char[] command,
  any source)
{
  // Identify identity type
  char typeStr[11];
  IDType type = GetBanIdType(identity);
  if(type == Steam_3)
    typeStr = "steamid3"; // Database Column
  else if(type == Steam_2)
    typeStr = "steamid2";
  else if(type == Ip_Addr)
    typeStr = "ip_address";
  else
  {
    LogGeneric("%t", "SM_ONREMOVE_IdentityFail", identity);
    return Plugin_Continue;
  }

  // Sanitise Input
  char identity_san[AUTH_SANITISE];
  SQL_EscapeString(h_Database, identity, identity_san, sizeof(identity_san));

  // Do Query
  int printTarget = 0;
  if(source > 0 && source <= MaxClients)
    printTarget = GetClientUserId(source);

  char query[50 + AUTH_SANITISE]; // 39 + "ip_address" + \0
  Format(query, sizeof(query), "DELETE FROM bannedusers WHERE %s='%s';", typeStr, identity_san);

  LogGeneric("%t", "SM_ONREMOVE_Removing", typeStr, identity);
#if defined _QUERYDEBUG
  LogGeneric("OnRemoveBan QUERY: %s", query);
#endif
  SQL_TQuery(h_Database, Callback_OnRemoveBan, query, printTarget, DBPrio_Normal);
  return Plugin_Continue;
}

public void Callback_OnRemoveBan(Handle db, Handle result, const char[] err, any data)
{
  int client = (data == 0) ? 0 : GetClientOfUserId(data); // Defaults to server

  // Cant GetCmdReplySource
  if(client)
    TagPrintChat(client, "%t", "SM_ONREMOVE_Done");
  else
    TagPrintServer("%t", "SM_ONREMOVE_Done");
  return;
}



/**
 * When client connects to server and has a steamid
 *
 * Check if conneting player is banned.
 * Kick player if SteamID matches, regardless of ban type.
 * Only kick when IP matches if it's an IP ban.
 */
public void OnClientAuthorized(int client, const char[] auth)
{
  if(StrEqual(auth, "BOT", true))
    return;

  IDType type = GetBanIdType(auth);
  char clientIP[20], typeStr[9];
  GetClientIP(client, clientIP, sizeof(clientIP), true);

  // Get Database Column Name from ID Type
  if(type == Steam_3)
    typeStr = "steamid3";
  else if(type == Steam_2)
    typeStr = "steamid2";
  else
  {
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));

    LogGeneric("%t", "SM_ONJOIN_AuthFail", name, clientIP, auth);
    return;
  }

  char id_san[AUTH_SANITISE], ip_san[AUTH_SANITISE];
  SQL_EscapeString(h_Database, auth, id_san, sizeof(id_san));
  SQL_EscapeString(h_Database, clientIP, ip_san, sizeof(ip_san));

  // Select Non-expired bans: When ID matches, or when IP matches and ban_type is Ban_IPAddress
  char query[JOINQUERY_SIZE];
  Format(query, sizeof(query), JOINQUERY, typeStr, id_san, ip_san, g_iMaxIPBanDays);
  // Do not setup printTarget here. We shouldn't print during Callback_OnClientAuth

#if defined _QUERYDEBUG
  LogGeneric("OnClientAuth QUERY: %s", query[JOINQUERY_LOG]);
#endif
  SQL_TQuery(h_Database, Callback_OnClientAuth, query, GetClientUserId(client), DBPrio_High);
  return;
}

public void Callback_OnClientAuth(Handle db, Handle result, const char[] err, any data)
{
  // Check client and result set are valid
  int client = GetClientOfUserId(data);
  if(client == 0)
  {
    LogGeneric("%t", "SM_ONJOIN_ClientInvalid", data);
    return;
  }

  // Get ID for any Logging
  char auth[AUTH_MAX];
  GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth), true);

  if(result == null)
  {
    LogGeneric("%t", "SM_ONJOIN_NullResult", data, auth);
    return;
  }

  // Check if query returned a result (Indicating a valid, non-expired ban)
  int rowCount = SQL_GetRowCount(result);
  if(rowCount < 1)
    return;
  // Duplicates may exist if a client is both IP and ID banned.
  // In that event, the query will get kick for the one with the longest ban time

  // Process Result Set (utc_issued, duration_sec, reason)
  int issued;
  if(!DB_LogFetchInt(issued, result, 0, "OnClientAuthorized"))
    return;

  int duration;
  if(!DB_LogFetchInt(duration, result, 1, "OnClientAuthorized"))
    return;

  char reason[MSG_SANITISE];
  if(!DB_LogFetchString(reason, sizeof(reason), result, 2, "OnClientAuthorized"))
    return;

  // Kick Client
  char timeStr[64];
  FormatTime(timeStr, sizeof(timeStr), "%c", duration + issued);
  KickClient(client, "%T", "SM_ONJOIN_Kick", client, timeStr, "\n", reason);
  return;
}




/**
 * Remove expired bans from the database
 *
 * sm_cleanbans
 */
public Action CMD_CleanBans(int client, int args)
{
  if(client < 0 || client > MaxClients)
    return Plugin_Handled;

  // Delete any expired bans, or IP bans that are older than g_iMaxIPBanDays
  char query[CLEANQUERY_SIZE];
  Format(query, sizeof(query), CLEANQUERY, g_iMaxIPBanDays);

  int printTarget = (client != 0) ? GetClientUserId(client) : 0;

  LogGeneric("%t", "SM_CLEANBANS_Cleaned");
#if defined _QUERYDEBUG
  LogGeneric("CMD_CleanBans QUERY: %s", query);
#endif
  SQL_TQuery(h_Database, Callback_Clean, query, printTarget, DBPrio_Low);
  return Plugin_Handled;
}

public void Callback_Clean(Handle db, Handle result, const char[] err, any data)
{
  int client = (data == 0) ? 0 : GetClientOfUserId(data); // Defaults to server

  // Cant GetCmdReplySource
  if(client)
    TagPrintChat(client, "%t", "SM_CLEANBANS_Cleaned");
  else
    TagPrintServer("%t", "SM_CLEANBANS_Cleaned");
  return;
}



/**
 * Update an existing ban in the database
 * This command is console only, as each argument must be enclosed in quotes
 * otherwise, you cannot put spaces in them.
 *
 * sm_editban <SteamID/IP> <Duration (Mins)/SKIP> <Reason/SKIP> <Note/SKIP>
 */
public Action CMD_EditBan(int client, int args)
{
  if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
  {
    TagReply(client, "%t", "SFP_CmdConsoleOnly");
    return Plugin_Handled;
  }

  if(args != 4) // Strictly 4 because console-only requires quotes
  {
    TagReplyUsage(client, "%t", "SM_EDITBAN_Usage");
    return Plugin_Handled;
  }

  char arg1[AUTH_MAX], arg2[INT_LENGTH], arg3[MSG_MAX], arg4[MSG_MAX];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));
  GetCmdArg(3, arg3, sizeof(arg3));
  GetCmdArg(4, arg4, sizeof(arg4));

  // Clean Args from Console quotes
  StripQuotes(arg1);
  StripQuotes(arg2);
  StripQuotes(arg3);
  StripQuotes(arg4);

  // Check args for 'SKIP' (arg will be ignored)
  bool skipDuration = false, skipReason = false, skipNote = false;
  skipDuration  = StrEqual(arg2, "SKIP", false);
  skipReason    = StrEqual(arg3, "SKIP", false);
  skipNote      = StrEqual(arg4, "SKIP", false);
  if(skipDuration && skipReason && skipNote)
  {
    TagReply(client, "%t", "SM_EDITBAN_SkipAll");
    return Plugin_Handled;
  }

  // Validate Args
  IDType type = GetBanIdType(arg1);
  if(type == Invalid_Id)
  {
    TagReply(client, "%t", "SM_BANS_InvalidId");
    return Plugin_Handled;
  }

  int duration = 60 * StringToInt(arg2);      // Handle duration as seconds
  int maxDuration = INT_MAX_32 - GetTime();   // Max Possible duration
  if(duration < 0 || duration > maxDuration)
  {
    TagReply(client, "%t", "SM_EDITBAN_InvalidDuration", (maxDuration/60)); // Command uses mins
    return Plugin_Handled;
  }

  // Preapre Query and Query Fragments
  char reason[MSG_SANITISE], note[MSG_SANITISE];

  // UPDATE bannedusers SET
  // duration_sec=CASE WHEN permanent=0 THEN %i ELSE duration_sec END, reason='', admin_note='',
  // last_modified=CAST(strftime('%%s', 'now') AS INTEGER), modifier_id='', modifier_name=''
  // WHERE <10charid>='';
  char query[890] = "UPDATE bannedusers SET"; // query is Max ~887 (222+257+257+43+65+43)

  // If arg is not 'SKIP', concatenate new-value-setter to the query
  if(!skipDuration)
  {
    char durAppend[67 + INT_LENGTH];
    Format(durAppend, sizeof(durAppend), " duration_sec=CASE WHEN permanent=0 THEN %i ELSE duration_sec END,", duration); // Space at start
    StrCat(query, sizeof(query), durAppend);
  }

  if(!skipReason)
  {
    SQL_EscapeString(h_Database, arg3, reason, sizeof(reason));
    char reasonAppend[MSG_SANITISE + 12]; // " reason=''," + reason + \0
    Format(reasonAppend, sizeof(reasonAppend), " reason='%s',", reason);
    StrCat(query, sizeof(query), reasonAppend);
  }

  if(!skipNote)
  {
    SQL_EscapeString(h_Database, arg4, note, sizeof(note));
    char noteAppend[MSG_SANITISE + 16]; // " admin_note=''," + note + \0
    Format(noteAppend, sizeof(noteAppend), " admin_note='%s',", note);
    StrCat(query, sizeof(query), noteAppend);
  }

  // Prepare Query ID/IP
  char idTypeStr[INT_LENGTH]; // "ip_address"
  switch(type)
  {
    case Steam_3: idTypeStr = "steamid3";
    case Steam_2: idTypeStr = "steamid2";
    case Ip_Addr: idTypeStr = "ip_address";
    case Steam_2_Uscore:
    {
      // Fix STEAM_0_1_23456789 into STEAM_0:1:23456789
      idTypeStr = "steamid2";
      FixUnderscoredId2(arg1);
    }
  }

  // Prepare Modifier Details
  char modId[AUTH_MAX], modName[MAX_NAME_LENGTH];
  char modId_san[AUTH_SANITISE], modName_san[NAME_SANITISE];
  if(client > 0)
  {
    GetClientName(client, modName, sizeof(modName));
    GetClientAuthId(client, AuthId_Steam3, modId, sizeof(modId), true);
    SQL_EscapeString(h_Database, modName, modName_san, sizeof(modName_san));
    SQL_EscapeString(h_Database, modId, modId_san, sizeof(modId_san));
  }
  else
  {
    Format(modId_san, sizeof(modId_san), "%T", "SM_EDITBAN_Console", LANG_SERVER);
    Format(modName_san, sizeof(modName_san), "%T", "SM_EDITBAN_Console", LANG_SERVER);
  }


  // Finialize Query
  char auth[AUTH_SANITISE], queryEnd[108 + (2*AUTH_SANITISE) + NAME_SANITISE];
  SQL_EscapeString(h_Database, arg1, auth, sizeof(auth));
  Format(queryEnd, sizeof(queryEnd), " last_modified=CAST(strftime('%%s', 'now') AS INTEGER), modifier_id='%s', modifier_name='%s' WHERE %s='%s';", modId_san, modName_san, idTypeStr, auth);
  StrCat(query, sizeof(query), queryEnd);


  // Do Query
  int printTarget = 0;
  if(client > 0 && client <= MaxClients)
    printTarget = GetClientUserId(client);

  TagReply(client, "%t", "SM_EDITBAN_Querying", arg1);
  LogGeneric("%t", "SM_EDITBAN_Changes",
    modName,
    modId,
    auth,
    (skipDuration)  ? -1      : duration,
    (skipReason)    ? "SKIP"  : reason,
    (skipNote)      ? "SKIP"  : note);

#if defined _QUERYDEBUG
  LogGeneric("CMD_EditBan QUERY: %s", query);
#endif
  SQL_TQuery(h_Database, Callback_Editban, query, printTarget, DBPrio_Low);
  return Plugin_Handled;
}

public void Callback_Editban(Handle db, Handle result, const char[] err, any data)
{
  int client = (data == 0) ? 0 : GetClientOfUserId(data); // Defaults to server

  // Cant GetCmdReplySource
  if(client)
    TagPrintChat(client, "%t", "SM_EDITBAN_Done");
  else
    TagPrintServer("%t", "SM_EDITBAN_Done");
  return;
}



/**
 * Check if player is banned and get how long is remaining
 *
 * sm_isbanned <SteamID/IP Address>
 */
public Action CMD_IsBanned(int client, int args)
{
  if(client < 0 || client > MaxClients)
    return Plugin_Handled;

  if(args < 1)
  {
    TagReplyUsage(client, "%t", "SM_ISBANNED_Usage");
    return Plugin_Handled;
  }

  char argFull[AUTH_MAX];
  GetCmdArgString(argFull, sizeof(argFull));  // GetCmdArg will treat : as terminator
  TrimString(argFull);                        // Clean input since we used GetCmdArgString
  StripQuotes(argFull);

  // Get Database Column
  char idTypeStr[INT_LENGTH];                 // "ip_address"
  switch(GetBanIdType(argFull))
  {
    case Steam_3: idTypeStr = "steamid3";
    case Steam_2: idTypeStr = "steamid2";
    case Ip_Addr: idTypeStr = "ip_address";
    case Steam_2_Uscore:
    {
      idTypeStr = "steamid2";
      FixUnderscoredId2(argFull);
    }
    default:
    {
      TagReply(client, "%t", "SM_BANS_InvalidId");
      return Plugin_Handled;
    }
  }

  // Clean arg and Create query
  char auth[AUTH_SANITISE], query[120 + INT_LENGTH + AUTH_SANITISE];
  SQL_EscapeString(h_Database, argFull, auth, sizeof(auth));
  Format(query, sizeof(query),
    "SELECT (utc_issued + duration_sec) - CAST(strftime('%%s', 'now') AS INTEGER), permanent FROM bannedusers WHERE %s='%s';",
    idTypeStr,
    auth);

  int printTarget = 0;
  if(client > 0 && client <= MaxClients)
  {
    printTarget = GetClientUserId(client);
    TagReply(client, "%t", "SM_ISBANNED_Querying", argFull);
  }

#if defined _QUERYDEBUG
  LogGeneric("CMD_IsBanned QUERY: %s", query);
#endif
  SQL_TQuery(h_Database, Callback_IsBanned, query, printTarget, DBPrio_Low);
  return Plugin_Handled;
}

public void Callback_IsBanned(Handle db, Handle result, const char[] err, any data)
{
  int client = (data == 0) ? 0 : GetClientOfUserId(data); // Defaults to server
  if(SQL_GetRowCount(result) < 1)
  {
    // Cant GetCmdReplySource
    if(client)
      TagPrintChat(client, "%t", "SM_ISBANNED_NotFound");
    else
      TagPrintServer("%t", "SM_ISBANNED_NotFound");
    return;
  }

  int timeRemaining, permanent;
  if(!DB_LogFetchInt(timeRemaining, result, 0, "Callback_IsBanned"))  // Time is in seconds
    return;

  if(!DB_LogFetchInt(permanent, result, 1, "Callback_IsBanned"))
    return;

  int timeMins = (timeRemaining <= 60) ? 1 : timeRemaining/60;   // Show 1m instead of 0m

  if(permanent)
  {
    if(client)
      TagPrintChat(client, "%t", "SM_ISBANNED_Found_Perm");
    else
      TagPrintServer("%t", "SM_ISBANNED_Found_Perm");
  }
  else if(timeRemaining >= 1)
  {
    if(client)
      TagPrintChat(client, "%t", "SM_ISBANNED_Found", timeMins);
    else
      TagPrintServer("%t", "SM_ISBANNED_Found", timeMins);
    
  }
  else if(timeRemaining < 1)
  {    
    if(client)
      TagPrintChat(client, "%t", "SM_ISBANNED_NotFound"); // Expired bans do nothing on join
    else
      TagPrintServer("%t", "SM_ISBANNED_NotFound");
  }
  return;
}



/**
 * Remove any old log files manually
 *
 * sm_cleanbanlogs
 */
public Action CMD_CleanLogs(int client, int args)
{
  ClearExpiredLogs();
  TagReply(client, "%t", "SM_CLEANLOGS_Done", g_iMaxLogDays);
  LogGeneric("%t", "SM_CLEANLOGS_Done", g_iMaxLogDays);
  return Plugin_Handled;
}



/**
 * Browse all bans in the database via menu
 *
 * sm_browsebans
 */
public Action CMD_BrowseBans(int client, int args)
{
  if(!IsClientPlaying(client, true)) // Allow Spectator and Dead
  {
    TagReply(client, "%t", "SFP_InGameOnly");
    return Plugin_Handled;
  }

  BrowseBans_Main(client);
  return Plugin_Handled;
}

void BrowseBans_Main(int client)
{
  Menu menu = new Menu(BrowseHandler_Main,
    MenuAction_End|MenuAction_Display|MenuAction_DisplayItem|MenuAction_Select);
  SetMenuTitle(menu, "?"); // Translated in handler

  AddMenuItem(menu, "1", "SteamID Bans");
  AddMenuItem(menu, "2", "IP Bans");

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int BrowseHandler_Main(Handle menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_End:
      delete menu;

    case MenuAction_Display:
    {
      // Client Translation: p1 = client, p2 = menu
      char buffer[32];
      Format(buffer, sizeof(buffer), "%T", "SM_BROWSEBANS_Main_Title", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }

    case MenuAction_DisplayItem:
    {
      // Handle Text Translation: p1 = client, p2 = menuitem
      char info[2];
      GetMenuItem(menu, param2, info, sizeof(info));

      char display[32];

      if(StrEqual(info, "1"))
        Format(display, sizeof(display), "%T", "SM_BROWSEBANS_Main_ID", param1);
      else
        Format(display, sizeof(display), "%T", "SM_BROWSEBANS_Main_IP", param1);
      return RedrawMenuItem(display);
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[2];
      GetMenuItem(menu, param2, info, sizeof(info));

      if(StrEqual(info, "1"))
        BrowseBans_SteamId(param1);
      else
        BrowseBans_IpAddress(param1);
    }
  }
  return 0;
}

/**
 * Browse all SteamID bans in the database
 */
void BrowseBans_SteamId(int client)
{
  g_iBrowseMenuType[client] = Ban_SteamId;
  // No Need for _QUERYDEBUG
  SQL_TQuery(h_Database, Callback_BrowseBans,
    "SELECT banid, steamid3, player_name, strftime('%Y-%m-%d', utc_issued, 'unixepoch', 'localtime') FROM bannedusers WHERE (utc_issued + duration_sec >= CAST(strftime('%s', 'now') AS INTEGER)) AND ban_type=0 ORDER BY utc_issued + duration_sec DESC;",
    GetClientUserId(client),
    DBPrio_Low);
  return;
}

/**
 * Browse all IP bans in the database
 */
void BrowseBans_IpAddress(int client)
{
  g_iBrowseMenuType[client] = Ban_IPAddress;
  // No Need for _QUERYDEBUG
  SQL_TQuery(h_Database, Callback_BrowseBans,
    "SELECT banid, ip_address, player_name, strftime('%Y-%m-%d', utc_issued, 'unixepoch', 'localtime') FROM bannedusers WHERE (utc_issued + duration_sec >= CAST(strftime('%s', 'now') AS INTEGER)) AND ban_type=1 ORDER BY utc_issued + duration_sec DESC;",
    GetClientUserId(client),
    DBPrio_Low);
  return;
}

/**
 * Create menu for either SteamID or IP bans
 * Both select: banid, <auth>, player_name, string:utc_issued
 */
public void Callback_BrowseBans(Handle db, Handle result, const char[] err, any data)
{
  // Check if client became invalid
  int client = GetClientOfUserId(data); // Return 0 on fail
  if(client == 0)
    return;

  // Get ID for any Logging
  char clientId3[AUTH_MAX];
  GetClientAuthId(client, AuthId_Steam3, clientId3, sizeof(clientId3), true);

  // Validate Result Set
  if(result == null)
  {
    LogGeneric("%t", "SM_BROWSEBANS_ID_Null", g_iBrowseMenuType[client], data, clientId3);
    return;
  }

  int rowCount = SQL_GetRowCount(result);
  if(rowCount < 1)
  {
    // Cant GetCmdReplySource
    if(client)
      TagPrintChat(client, "%t", "SM_BROWSEBANS_NoneFound");
    else
      TagPrintServer("%t", "SM_BROWSEBANS_NoneFound");
    return;
  }


  Menu menu = new Menu(BrowseHandler,
    MenuAction_End|MenuAction_Cancel|MenuAction_Display|MenuAction_Select);
  SetMenuTitle(menu, "?"); // Translated in handler (with g_iBrowseMenuType)
  SetMenuExitBackButton(menu, true);

  // Add each item from the result set to the menu.
  // Note that both the results from BrowseBans_SteamId and BrowseBans_IpAddress must work here
  int count = 0;
  while(SQL_FetchRow(result) && count < rowCount)
  {
    char banIdStr[INT_LENGTH], name[NAME_SANITISE], authId[AUTH_SANITISE], time[16];
    int banId;
    if(!DB_LogFetchInt(banId, result, 0, "Callback_BrowseBans"))
      continue;
    if(!DB_LogFetchString(authId, sizeof(authId), result, 1, "Callback_BrowseBans"))
      continue;
    if(!DB_LogFetchString(name, sizeof(name), result, 2, "Callback_BrowseBans"))
      continue;
    if(!DB_LogFetchString(time, sizeof(time), result, 3, "Callback_BrowseBans"))
      continue;

    char buff[NAME_SANITISE + AUTH_SANITISE + 7]; // " () - " + \0
    Format(buff, sizeof(buff), "%s (%s) - %s", authId, name, time);

    IntToString(banId, banIdStr, sizeof(banIdStr));
    AddMenuItem(menu, banIdStr, buff);
    ++count;
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int BrowseHandler(Handle menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_End:
      delete menu;

    case MenuAction_Cancel:
    {
      if(param2 == MenuCancel_ExitBack)
        BrowseBans_Main(param1);
    }

    case MenuAction_Display:
    {
      // Client Translation: p1 = client, p2 = menu
      char buffer[32];
      if(g_iBrowseMenuType[param1] == Ban_SteamId)
        Format(buffer, sizeof(buffer), "%T", "SM_BROWSEBANS_Main_ID", param1);
      else
        Format(buffer, sizeof(buffer), "%T", "SM_BROWSEBANS_Main_IP", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[INT_LENGTH];
      GetMenuItem(menu, param2, info, sizeof(info));

      int id = StringToInt(info);
      if(id > 0 && id < INT_MAX_32)
        ShowBanDetails(param1, id);
      else
        LogGeneric("%t", "SM_BROWSEBANS_InvalidBanId", info); // TODO More detail?
    }
  }
  return 0;
}


/**
 * Show a submenu displaying data for a given ban id in the format below.
 * Query does not handle the prefix text as it needs to be translated.
 * Permanent bans have the maximum possible ban time
 *  Some Guy
 *  Steam: [U:1:4691357]                <-- Null turns to "--"
 *  IP: UNKNOWN                         <-- Null turns to "--"
 *  Ban Type: <IP/SteamID>
 *  Duration (mins): 1234567890
 *  Expires: 2017-12-4 12:33:05
 *  Reason: For a reason.               <-- Null turns to "--"
 *  Issued: 2017-12-4 12:33:05
 *  Banned By: Adman<[U:1:2345678]>
 *  Note: --                            <-- Null turns to "--"
 *  Last Modified: 2017-12-4 12:33:05
 *  Modified By: Adman<[U:1:2345678]>
 */
void ShowBanDetails(int client, int banId)
{
  char query[595 + INT_LENGTH]; // Roughly Accurate
  Format(query, sizeof(query),
    "SELECT player_name, \
    COALESCE(steamid3, '--'), \
    COALESCE(ip_address, '--'), \
    ban_type, \
    duration_sec/60, \
    strftime('%%Y-%%m-%%d %%H:%%M:%%S', utc_issued + duration_sec, 'unixepoch', 'localtime'), \
    COALESCE(reason, '--'), \
    strftime('%%Y-%%m-%%d %%H:%%M:%%S', utc_issued, 'unixepoch', 'localtime'), \
    admin_name || '<' || admin_id3 || '>', \
    COALESCE(admin_note, '--'), \
    strftime('%%Y-%%m-%%d %%H:%%M:%%S', last_modified, 'unixepoch', 'localtime'), \
    modifier_name || '<' || modifier_id || '>' \
    FROM bannedusers WHERE banid=%i;",
    banId);
  // No Need for _QUERYDEBUG
  SQL_TQuery(h_Database, Callback_BrowseDetails, query, GetClientUserId(client), DBPrio_Low);
  return;
}

public void Callback_BrowseDetails(Handle db, Handle result, const char[] err, any data)
{
  // Check if client became invalid
  int client = GetClientOfUserId(data); // Return 0 on fail
  if(client == 0)
    return;

  // Get ID for any Logging
  char clientId3[AUTH_MAX];
  GetClientAuthId(client, AuthId_Steam3, clientId3, sizeof(clientId3), true);

  // Validate Result Set
  if(result == null)
  {
    LogGeneric("%t", "SM_BROWSEDETAILS_ID_Null", data, clientId3);
    return;
  }

  // This should only happen if the ban is removed between query and DisplayMenu
  int rowCount = SQL_GetRowCount(result);
  if(rowCount < 1)
  {
    LogGeneric("%t", "SM_BROWSEDETAILS_NullBanId", data, clientId3);
    // Cant GetCmdReplySource
    if(client)
      TagPrintChat(client, "%t", "SM_BROWSEDETAILS_BanIdInvalid");
    else
      TagPrintServer("%t", "SM_BROWSEDETAILS_BanIdInvalid");
    return;
  }


  // Add all fields to the menu
  // This could use a repeated function but it actually takes up more code

  Menu menu = new Menu(DetailsHandler, MenuAction_End|MenuAction_Cancel|MenuAction_Display);
  SetMenuTitle(menu, "?"); // Translated in handler
  SetMenuExitBackButton(menu, true);

  bool error = false;
  char strBuff[MSG_SANITISE], strFormat[MSG_SANITISE + 32]; // Largest buffer in database
  int iBuff;



  // Get Name
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 0, "Callback_BrowseBans"))
    error = true;
  AddMenuItem(menu, "0", strBuff, ITEMDRAW_DISABLED);

  // Get SteamID
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 1, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_SteamId", client, strBuff);
  AddMenuItem(menu, "1", strFormat, ITEMDRAW_DISABLED);

  // Get IP
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 2, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_IP", client, strBuff);
  AddMenuItem(menu, "2", strFormat, ITEMDRAW_DISABLED);

  // Get Ban Type
  if(!DB_LogFetchInt(iBuff, result, 3, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %T",
    "SM_BROWSEDETAILS_BanType",
    client,
    (view_as<BanType>(iBuff) == Ban_SteamId) ? "SM_BROWSEDETAILS_SteamId" : "SM_BROWSEDETAILS_IP",
    client);
  AddMenuItem(menu, "3", strFormat, ITEMDRAW_DISABLED);

  // Get Duration
  if(!DB_LogFetchInt(iBuff, result, 4, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %i", "SM_BROWSEDETAILS_Duration", client, iBuff);
  AddMenuItem(menu, "4", strFormat, ITEMDRAW_DISABLED);

  // Get Expiration Date
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 5, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_Expires", client, strBuff);
  AddMenuItem(menu, "5", strFormat, ITEMDRAW_DISABLED);

  // Get Reason
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 6, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_Reason", client, strBuff);
  AddMenuItem(menu, "6", strFormat, ITEMDRAW_DISABLED);



  // Get Time Issued/When
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 7, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_TimeIssued", client, strBuff);
  AddMenuItem(menu, "7", strFormat, ITEMDRAW_DISABLED);

  // Get Banning Admin
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 8, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_BannedBy", client, strBuff);
  AddMenuItem(menu, "8", strFormat, ITEMDRAW_DISABLED);

  // Get Admin Note
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 9, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_Note", client, strBuff);
  AddMenuItem(menu, "9", strFormat, ITEMDRAW_DISABLED);

  // Get Last Modified Date
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 10, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_TimeModified", client, strBuff);
  AddMenuItem(menu, "10", strFormat, ITEMDRAW_DISABLED);

  // Get Last Modified Date
  if(!DB_LogFetchString(strBuff, sizeof(strBuff), result, 11, "Callback_BrowseBans"))
    error = true;
  Format(strFormat, sizeof(strFormat), "%T: %s", "SM_BROWSEDETAILS_ModifiedBy", client, strBuff);
  AddMenuItem(menu, "11", strFormat, ITEMDRAW_DISABLED);


  if(error)
    delete menu;
  else
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int DetailsHandler(Handle menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_End:
      delete menu;

    case MenuAction_Cancel:
    {
      if(param2 == MenuCancel_ExitBack)
      {
        if(g_iBrowseMenuType[param1] == Ban_SteamId)
          BrowseBans_SteamId(param1);
        else
          BrowseBans_IpAddress(param1);
      }
    }

    case MenuAction_Display:
    {
      // Client Translation: p1 = client, p2 = menu
      char buffer[32];
      Format(buffer, sizeof(buffer), "%T", "SM_BROWSEBANS_Details_Title", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }
  }
  return 0;
}




/**
 * Completely Reset the ban database. With confirmation check.
 * This command is useful if the database table changes format.
 *
 * sm_sfp_bans_full_reset FOLLOWED BY sm_sfp_bans_full_reset <Unknown Integer>
 */
public Action CMD_FullReset(int client, int args)
{
  // Prevent Multiple Users during repeat-prompt
  if(g_bFullResetInUse && g_iFullResetClient != -1 && client != g_iFullResetClient)
  {
    TagReply(client, "%t", "SM_FULLRESET_InUse");
    return Plugin_Handled;
  }

  // Set Current User
  g_bFullResetInUse   = true;
  g_iFullResetClient  = client;

  if(g_iFullResetPendingNum < 0)
  {
    // First run, prompt client to repeat command for confirmation
    g_iFullResetPendingNum = GetURandomInt();

    int printTarget = 0;
    if(client > 0 && client <= MaxClients)
      printTarget = GetClientUserId(client);

    TagReply(client, "%t", "SM_FULLRESET_Repeat", g_iFullResetPendingNum);
    h_iFullResetTimer = CreateTimer(FULLRESET_TIMEOUT, Reset_Timeout, printTarget);
  }
  else
  {
    // Command was repeated, validate arg
    if(args != 1)
    {
      ClearFullReset();
      TagReply(client, "%t", "SM_FULLRESET_BadArgs");
      return Plugin_Handled;
    }

    char arg1[INT_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    // Check that arg is the correct number
    if(StringToInt(arg1) != g_iFullResetPendingNum)
      TagReply(client, "%t", "SM_FULLRESET_Invalid");
    else
    {
      SQL_LockDatabase(h_Database); // Non-threaded to prevent access during this
      SQL_FastQuery(h_Database, "DROP TABLE bannedusers;");
      CreateDatabaseTable();
      SQL_UnlockDatabase(h_Database);
      TagReply(client, "%t", "SM_FULLRESET_Done");
      LogGeneric("%t", "SM_FULLRESET_Done");
    }
    ClearFullReset();
  }
  return Plugin_Handled;
}

/**
 * Reset sm_sfp_bans_full_reset.
 */
stock void ClearFullReset()
{
  g_iFullResetPendingNum  = -1;
  g_bFullResetInUse       = false;
  g_iFullResetClient      = -1;
  delete h_iFullResetTimer;
  return;
}

public Action Reset_Timeout(Handle timer, any data)
{
  if(g_iFullResetPendingNum >= 0)
  {
    int client = (data == 0) ? 0 : GetClientOfUserId(data); // Defaults to server
    // Cant GetCmdReplySource
    if(client)
      TagPrintChat(client, "%t", "SM_FULLRESET_Canceled");
    else
      TagPrintServer("%t", "SM_FULLRESET_Canceled");
  }

  g_iFullResetPendingNum  = -1;
  g_bFullResetInUse       = false;
  g_iFullResetClient      = -1;
  h_iFullResetTimer       = null;
  return Plugin_Stop;
}



/**
 * Test each of the stock functions to verify their output
 *
 * sm_sfp_bans_runtests
 */
#if defined _TESTCOMMAND
public Action CMD_RunTests(int client, int args)
{
  /**
   * Count Char
   */
  PrintToConsole(client, "******* Start Tests *******\n===== CountChar =====");

  int number = CountChar('a', "aaaB_B;'[A]\"BBaBCC");
  PrintTestResultAsInt(client, "CountChar('a', \"aaaB_B;'[A]\\\"BBaBCC\")", 4, number);

  number = CountChar('A', "aaaB_B;'[A]\"BBaBCC");
  PrintTestResultAsInt(client, "CountChar('A', \"aaaB_B;'[A]\\\"BBaBCC\")", 1, number);

  number = CountChar('3', "aaaB_B;'[A]\"BBaBCC");
  PrintTestResultAsInt(client, "CountChar('3', \"aaaB_B;'[A]\\\"BBaBCC\")", 0, number);

  number = CountChar('\"', "aaaB_B;'[A]\"BBaBCC");
  PrintTestResultAsInt(client, "CountChar('\\\"', \"aaaB_B;'[A]\\\"BBaBCC\")", 1, number);

  PrintToConsole(client, "===== CountChar Done =====\n");


  /**
   * GetBanIdType
   */
  PrintToConsole(client, "===== GetBanIdType =====");
  IDType type = GetBanIdType("[U:1:12345]");
  PrintTestResultAsInt(client, "GetBanIdType(\"[U:1:12345]\")", Steam_3, type);

  type = GetBanIdType("STEAM_0:1:234567");
  PrintTestResultAsInt(client, "GetBanIdType(\"STEAM_0:1:234567\")", Steam_2, type);

  type = GetBanIdType("STEAM_0_1_234567");
  PrintTestResultAsInt(client, "GetBanIdType(\"STEAM_0_1_234567\")", Steam_2_Uscore, type);

  type = GetBanIdType("123.123.123.123");
  PrintTestResultAsInt(client, "GetBanIdType(\"123.123.123.123\")", Ip_Addr, type);

  type = GetBanIdType("Totally Valid ID");
  PrintTestResultAsInt(client, "GetBanIdType(\"Totally Valid ID\")", Invalid_Id, type);

  PrintToConsole(client, "-----\n");

  type = GetBanIdType("[U:1:12345");
  PrintTestResultAsInt(client, "GetBanIdType(\"[U:1:12345\")", Invalid_Id, type);

  type = GetBanIdType("U:1:12345]");
  PrintTestResultAsInt(client, "GetBanIdType(\"U:1:12345]\")", Invalid_Id, type);

  type = GetBanIdType("U:1:12345");
  PrintTestResultAsInt(client, "GetBanIdType(\"U:1:12345\")", Invalid_Id, type);

  type = GetBanIdType("[U:112345]");
  PrintTestResultAsInt(client, "GetBanIdType(\"[U:112345]\")", Invalid_Id, type);

  type = GetBanIdType("[U:1:1:2345]");
  PrintTestResultAsInt(client, "GetBanIdType(\"[U:1:1:2345]\")", Invalid_Id, type);

  PrintToConsole(client, "-----\n");

  type = GetBanIdType("STEAM:0:1:234567");
  PrintTestResultAsInt(client, "GetBanIdType(\"STEAM:0:1:234567\")", Invalid_Id, type);

  type = GetBanIdType("STEAM_0_1:234567");
  PrintTestResultAsInt(client, "GetBanIdType(\"STEAM_0_1:234567\")", Invalid_Id, type);

  type = GetBanIdType("STEAM_0_1234567");
  PrintTestResultAsInt(client, "GetBanIdType(\"STEAM_0_1234567\")", Invalid_Id, type);

  PrintToConsole(client, "-----\n");

  type = GetBanIdType("0.0.0.0");
  PrintTestResultAsInt(client, "GetBanIdType(\"0.0.0.0\")", Ip_Addr, type);

  type = GetBanIdType("255.255.255.255");
  PrintTestResultAsInt(client, "GetBanIdType(\"255.255.255.255\")", Ip_Addr, type);

  type = GetBanIdType("256.255.255.255");
  PrintTestResultAsInt(client, "GetBanIdType(\"256.255.255.255\")", Invalid_Id, type);

  type = GetBanIdType("-255.255.255.255");
  PrintTestResultAsInt(client, "GetBanIdType(\"-255.255.255.255\")", Invalid_Id, type);

  type = GetBanIdType("255.255.255.255.0");
  PrintTestResultAsInt(client, "GetBanIdType(\"255.255.255.255.0\")", Invalid_Id, type);

  type = GetBanIdType("255.255.255");
  PrintTestResultAsInt(client, "GetBanIdType(\"255.255.255\")", Invalid_Id, type);

  PrintToConsole(client, "===== GetBanIdType Done =====\n");


  /**
   * SteamID Conversion
   */
  PrintToConsole(client, "===== SteamID Conversion =====");

  char id[AUTH_MAX] = "STEAM_0_1_2345678";

  FixUnderscoredId2(id);
  PrintTestResultAsString(
    client,
    "FixUnderscoredId2 (STEAM_0_1_2345678)",
    "STEAM_0:1:2345678",
    id);

  id = "STEAM_0:1:2345678";
  FixUnderscoredId2(id);
  PrintTestResultAsString(
    client,
    "FixUnderscoredId2 (STEAM_0:1:2345678)",
    "STEAM_0:1:2345678",
    id);

  PrintToConsole(client, "-----\n");

  // Even ID2 to ID3, Odd ID2 to ID3
  id = "";
  SteamID2ToID3("STEAM_0:1:2345678", id, sizeof(id));
  PrintTestResultAsString(
    client,
    "ID2ToID3 (STEAM_0:1:2345678)",
    "[U:1:4691357]",
    id);

  id = "";
  SteamID2ToID3("STEAM_0:0:2345679", id, sizeof(id));
  PrintTestResultAsString(
    client,
    "ID2ToID3 (STEAM_0:0:2345679)",
    "[U:1:4691358]",
    id);

  // Odd ID3 to ID2, Even ID3 to ID2
  id = "";
  SteamID3ToID2("[U:1:4691357]", id, sizeof(id));
  PrintTestResultAsString(
    client,
    "ID3ToID2 ([U:1:4691357])",
    "STEAM_0:1:2345678",
    id);

  id = "";
  SteamID3ToID2("[U:1:4691358]", id, sizeof(id));
  PrintTestResultAsString(
    client,
    "ID3ToID2 ([U:1:4691358])",
    "STEAM_0:0:2345679",
    id);

  PrintToConsole(client, "===== SteamID Conversion Done =====\n******* Tests Done *******");
  return Plugin_Handled;
}
#endif



//=================================
// Stock Functions

/**
 * LogToFile Wrapper for daily log file
 */
stock void LogGeneric(const char[] msg, any ...)
{
  SetGlobalTransTarget(LANG_SERVER);

  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 2);

  LogToFile(g_szLogFile, "%s", outStr);
  return;
}

/**
 * Get type of ID of a string, out of both SteamID2s, SteamdID3 or IPv4
 */
stock IDType GetBanIdType(const char[] str)
{
  if(MatchRegex(h_RegexSteam3, str))
    return Steam_3;
  else if(MatchRegex(h_RegexSteam2, str))
    return Steam_2;
  else if(MatchRegex(h_RegexSteam2US, str))
    return Steam_2_Uscore;
  else if(IsValidIPv4(str))
    return Ip_Addr;
  else
    return Invalid_Id;
}

/**
 * Is a string in a valid IPv4 Format:
 * 4 octects of 0-255 (incl.), separated by 3 '.'
 */
stock bool IsValidIPv4(const char[] addr)
{
  if(strlen(addr) > 15 || strlen(addr) < 7) // Size between "255.255.255.255" and "0.0.0.0"
    return false;

  if(CountChar('.', addr) != 3)
    return false;

  bool valid = true;
  char bytes[4][4];
  ExplodeString(addr, ".", bytes, sizeof(bytes), sizeof(bytes[])); // Get octects
  for(int i = 0; i < sizeof(bytes); ++i)
  {
    // Check octet is a valid decimal integer
    int len = strlen(bytes[i]);
    for(int j = 0; j < len; ++j)
    {
      if(!IsCharNumeric(bytes[i][j]))
      {
        valid = false;
        break;
      }
    }

    // Check octet integer is in range
    int num = StringToInt(bytes[i]);
    if(num < 0 || num > 255)
    {
      valid = false;
      break;
    }
  }
  return valid;
}

/**
 * Count the number of occurences of ch in str
 */
stock int CountChar(const char ch, const char[] str)
{
  int count = 0, index = 0;
  while(count <= strlen(str))
  {
    int buff = FindCharInString(str[index], ch);
    if(buff > -1)
    {
      ++count;
      index += buff + 1;
    }
    else
      break;
  }
  return count;
}

/**
 * Convert Sourcemod's ID2 STEAM_0_1_2345678 to STEAM_0:1:2345678
 */
stock void FixUnderscoredId2(char[] auth)
{
  int first = FindCharInString(auth, '_');
  if(first > -1)
  {
    // Replace all '_' with ':', then fix the first one
    ReplaceString(auth, strlen(auth)+1, "_", ":", true);
    auth[first] = '_';
  }
  return;
}


/**
 * Convert ID2 STEAM_0:1:2345678 to ID3 [U:1:4691357]
 */
stock void SteamID2ToID3(const char[] id2, char[] id3, const int maxLength)
{
  // Break into components 'STEAM_0', '1', '2345678' (X,Y,Z)
  char explode[3][INT_LENGTH];
  ExplodeString(id2, ":", explode, sizeof(explode), sizeof(explode[]), true);

  // Do STEAM_X:Y:Z = [U:1:(Z*2 + Y)]
  int accountNum  = StringToInt(explode[2]);
  int idPart      = StringToInt(explode[1]);
  Format(id3, maxLength, "[U:1:%i]", (accountNum*2) + idPart);
  return;
}

/**
 * Convert ID3 [U:1:4691357] to ID2 STEAM_0:1:2345678
 */
stock void SteamID3ToID2(const char[] id3, char[] id2, const int maxLength)
{
  // Break into components '[U', '1', '4691357]'
  char explode[3][INT_LENGTH + 1]; // 11 + ']'
  ExplodeString(id3, ":", explode, sizeof(explode), sizeof(explode[]), true);

  // Copy '4691357]' into buff, trimming ']'
  int len = strlen(explode[2]);
  char[] buff = new char[len];
  strcopy(buff, len, explode[2]); // strlen is sizeof - 1, this trims ']'

  // Reverse STEAM_X:Y:Z = [U:1:(Z*2 + Y)]
  int id3AccountNum = StringToInt(buff);
  int accountNum = id3AccountNum / 2;     // Get Z
  int idPart =  id3AccountNum % 2;        // Get Y

  Format(id2, maxLength, "STEAM_0:%i:%i", idPart, accountNum);
  return;
}

/**
 * SQL_Fetch* wrappers that log any DBResult errors
 * None of the integer fields can be null so this doesn't check.
 */
stock bool DB_LogFetchInt(int &val, Handle &query, int field, const char[] func)
{
  DBResult result;
  val = SQL_FetchInt(query, field, result);
  if(result != DBVal_Data)
  {
    LogGeneric("%t", "SM_BANS_FetchFail", func, field);
    return false;
  }
  return true;
}

stock bool DB_LogFetchString(char[] str, int maxLength, Handle &query, int field, const char[] func)
{
  DBResult result;
  SQL_FetchString(query, field, str, maxLength, result);
  if(result == DBVal_Null)
    strcopy(str, maxLength, ""); // For safety, zero out
  else if(result != DBVal_Data)
  {
    LogGeneric("%t", "SM_BANS_FetchFail", func, field);
    return false;
  }
  return true;
}

/**
 * Maximum Possible time (in mins) to fit inside 32-bit unix epoch
 * Due to integer division/rounding this will never be consistent.
 */
stock int GetPermabanMinutes()
{
  return (INT_MAX_32 - GetTime() - 5) / 60; // -5 to prevent overflow from rounding errors
}

/**
 * PrintToConsole wrappers for CMD_RunTests
 * Indicates whether expected and result match
 */
stock void PrintTestResultAsInt(int client, const char[] func, any expected, any result)
{
  PrintToConsole(client, "%s: %s\n -- Expected %i\n -- Got      %i\n",
  func,
  (view_as<int>(expected) == view_as<int>(result)) ? "[PASS]" : "<<FAIL>>",
  view_as<int>(expected),
  view_as<int>(result));
  return;
}

stock void PrintTestResultAsString(
  int client,
  const char[] func,
  const char[] expected,
  const char[] result)
{
  PrintToConsole(client, "%s: %s\n -- Expected '%s'\n -- Got      '%s'\n",
  func,
  (StrEqual(expected, result, true)) ? "[PASS]" : "<<FAIL>>",
  expected,
  result);
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
