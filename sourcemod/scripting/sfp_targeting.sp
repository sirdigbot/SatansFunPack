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
#define UPDATE_URL  "https://sirdigbot.github.io/SatansFunPack/sourcemod/targeting_update.txt"

// Comment out to stop the excessive random1-31 filters from compiling.
#define _TARGET_RANDOM_VARIATION

#define FILTERLOOP_MINIMUM  5.0

//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
Handle  h_iRandomBias = null;
int     g_iRandomBias;

// Unicode Filter
Handle  h_NameCheckTimer = null;
Handle  h_bFilterEnabled = null;
bool    g_bFilterEnabled;
Handle  h_bFilterNotify = null;
bool    g_bFilterNotify;
Handle  h_flFilterInterval = null;
float   g_flFilterInterval;
Handle  h_iFilterMode = null;
int     g_iFilterMode;
bool    g_bHasUserIDPrefix[MAXPLAYERS + 1];


/**
 * Known Bugs:
 * - Random can sometimes target no-one, this returns a failed target error.
 * - RandomX did not work because MAXPLAYERS was larger than the MaxClients array.
 *   - This has probably been fixed.
 * - Late loading causes g_bHasUserIDPrefix to reset despite prefixes being applied.
 *   this doubles them up on the next filter loop.
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Targeting",
  author =      "SirDigby",
  description = "Useful Targeting Stuff for All Commands",
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
    Format(err, err_max, "%T", "SFP_Incompatible", LANG_SERVER);
    return APLRes_Failure;
  }
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  LoadTranslations("sfp.targeting.phrases");

  h_bUpdate = CreateConVar("sm_sfp_targeting_update", "1", "Update Satan's Fun Pack - Targeting Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_iRandomBias = CreateConVar("sm_random_target_bias", "127", "Chance bias of random target selection from 1 to 254\n(Default: 127)", FCVAR_NONE, true, 1.0, true, 254.0);
  g_iRandomBias = GetConVarInt(h_iRandomBias);
  HookConVarChange(h_iRandomBias, UpdateCvars);


  h_bFilterEnabled = CreateConVar("sm_unicodefilter_enabled", "1", "Is Unicode Name Filtering enabled\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bFilterEnabled = GetConVarBool(h_bFilterEnabled);
  HookConVarChange(h_bFilterEnabled, UpdateCvars);

  h_bFilterNotify = CreateConVar("sm_unicodefilter_notify", "1", "Notify when name is filtered\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bFilterNotify = GetConVarBool(h_bFilterNotify);
  HookConVarChange(h_bFilterNotify, UpdateCvars);

  h_flFilterInterval = CreateConVar("sm_unicodefilter_interval", "20.0", "Interval (in seconds) to check all names\n(Default: 20.0)", FCVAR_NONE, true, FILTERLOOP_MINIMUM);
  g_flFilterInterval = GetConVarFloat(h_flFilterInterval);
  HookConVarChange(h_flFilterInterval, UpdateCvars);

  h_iFilterMode = CreateConVar("sm_unicodefilter_mode", "4", "Minimum Amount of ASCII charcters required in a row to not be filtered. 0 = Filter if any Unicode is in name.\n(Default: 4)", FCVAR_NONE, true, 0.0, true, 20.0);
  g_iFilterMode = GetConVarInt(h_iFilterMode);
  HookConVarChange(h_iFilterMode, UpdateCvars);


  AddMultiTargetFilter("@admins", Filter_Admins, "All Admins", false);
  AddMultiTargetFilter("@!admins", Filter_NotAdmins, "All Non-Admins", false);
  AddMultiTargetFilter("@mods", Filter_Mods, "All Moderators", false);
  AddMultiTargetFilter("@!mods", Filter_NotMods, "All Non-Moderators", false);
  AddMultiTargetFilter("@staff", Filter_Staff, "All Staff", false);
  AddMultiTargetFilter("@!staff", Filter_NotStaff, "All Non-Staff", false);

  // Random
  AddMultiTargetFilter("@random", Filter_Random, "Random Players", false);
  #if defined _TARGET_RANDOM_VARIATION
  AddMultiTargetFilter("@random1", Filter_RandomMulti, "1 Random Player", false);
  AddMultiTargetFilter("@random2", Filter_RandomMulti, "2 Random Players", false);
  AddMultiTargetFilter("@random3", Filter_RandomMulti, "3 Random Players", false);
  AddMultiTargetFilter("@random4", Filter_RandomMulti, "4 Random Players", false);
  AddMultiTargetFilter("@random5", Filter_RandomMulti, "5 Random Players", false);
  AddMultiTargetFilter("@random6", Filter_RandomMulti, "6 Random Players", false);
  AddMultiTargetFilter("@random7", Filter_RandomMulti, "7 Random Players", false);
  AddMultiTargetFilter("@random8", Filter_RandomMulti, "8 Random Players", false);
  AddMultiTargetFilter("@random9", Filter_RandomMulti, "9 Random Players", false);
  AddMultiTargetFilter("@random10", Filter_RandomMulti, "10 Random Players", false);

  AddMultiTargetFilter("@random11", Filter_RandomMulti, "11 Random Players", false);
  AddMultiTargetFilter("@random12", Filter_RandomMulti, "12 Random Players", false);
  AddMultiTargetFilter("@random13", Filter_RandomMulti, "13 Random Players", false);
  AddMultiTargetFilter("@random14", Filter_RandomMulti, "14 Random Players", false);
  AddMultiTargetFilter("@random15", Filter_RandomMulti, "15 Random Players", false);
  AddMultiTargetFilter("@random16", Filter_RandomMulti, "16 Random Players", false);
  AddMultiTargetFilter("@random17", Filter_RandomMulti, "17 Random Players", false);
  AddMultiTargetFilter("@random18", Filter_RandomMulti, "18 Random Players", false);
  AddMultiTargetFilter("@random19", Filter_RandomMulti, "19 Random Players", false);
  AddMultiTargetFilter("@random20", Filter_RandomMulti, "20 Random Players", false);

  AddMultiTargetFilter("@random21", Filter_RandomMulti, "21 Random Players", false);
  AddMultiTargetFilter("@random22", Filter_RandomMulti, "22 Random Players", false);
  AddMultiTargetFilter("@random23", Filter_RandomMulti, "23 Random Players", false);
  AddMultiTargetFilter("@random24", Filter_RandomMulti, "24 Random Players", false);
  AddMultiTargetFilter("@random25", Filter_RandomMulti, "25 Random Players", false);
  AddMultiTargetFilter("@random26", Filter_RandomMulti, "26 Random Players", false);
  AddMultiTargetFilter("@random27", Filter_RandomMulti, "27 Random Players", false);
  AddMultiTargetFilter("@random28", Filter_RandomMulti, "28 Random Players", false);
  AddMultiTargetFilter("@random29", Filter_RandomMulti, "29 Random Players", false);
  AddMultiTargetFilter("@random30", Filter_RandomMulti, "30 Random Players", false);

  AddMultiTargetFilter("@random31", Filter_RandomMulti, "31 Random Players", false);
  #endif

  // Classes
  AddMultiTargetFilter("@scouts",      Filter_Scout, "All Scouts", false);
  AddMultiTargetFilter("@!scouts",     Filter_NotScout, "All Non-Scouts", false);

  AddMultiTargetFilter("@soldiers",    Filter_Soldier, "All Soldiers", false);
  AddMultiTargetFilter("@!soldiers",   Filter_NotSoldier, "All Non-Soldiers", false);

  AddMultiTargetFilter("@pyros",       Filter_Pyro, "All Pyros", false);
  AddMultiTargetFilter("@!pyros",      Filter_NotPyro, "All Non-Pyros", false);

  AddMultiTargetFilter("@demomen",     Filter_Demo, "All Demomen", false);
  AddMultiTargetFilter("@!demomen",    Filter_NotDemo, "All Non-Demomen", false);

  AddMultiTargetFilter("@heavies",     Filter_Heavy, "All Heavies", false); // TODO Heavys?
  AddMultiTargetFilter("@!heavies",    Filter_NotHeavy, "All Non-Heavies", false);

  AddMultiTargetFilter("@engineers",   Filter_Engie, "All Engineers", false);
  AddMultiTargetFilter("@!engineers",  Filter_NotEngie, "All Non-Engineers", false);

  AddMultiTargetFilter("@medics",      Filter_Medic, "All Medics", false);
  AddMultiTargetFilter("@!medics",     Filter_NotMedic, "All Non-Medics", false);

  AddMultiTargetFilter("@snipers",     Filter_Sniper, "All Snipers", false);
  AddMultiTargetFilter("@!snipers",    Filter_NotSniper, "All Non-Snipers", false);

  AddMultiTargetFilter("@spies",       Filter_Spy, "All Spies", false);
  AddMultiTargetFilter("@!spies",      Filter_NotSpy, "All Non-Spies", false);


  HookEvent("player_changename", Event_ChangeName);

  if(g_bLateLoad)
  {
    SetFailState("%T", "SM_TARGETING_NoLateLoad", LANG_SERVER);
    return;
  }


  /**
   * Overrides
   * sm_targetgroup_admin
   * sm_targetgroup_mod
   * sm_unicodefilter_ignore
   */

  PrintToServer("%T", "SFP_TargetingLoaded", LANG_SERVER);
  return;
}



public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_iRandomBias)
    g_iRandomBias = StringToInt(newValue);
  else if(cvar == h_bFilterEnabled)
    g_bFilterEnabled = GetConVarBool(h_bFilterEnabled);
  else if(cvar == h_bFilterNotify)
    g_bFilterNotify = GetConVarBool(h_bFilterNotify);
  else if(cvar == h_flFilterInterval)
  {
    g_flFilterInterval = StringToFloat(newValue);
    if(FloatCompare(g_flFilterInterval, FILTERLOOP_MINIMUM) > -1) // Precaution
    {
      SafeClearTimer(h_NameCheckTimer);
      h_NameCheckTimer = CreateTimer(
        g_flFilterInterval,
        Timer_NameFilter,
        _,
        TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
  }
  else if(cvar == h_iFilterMode)
    g_iFilterMode = StringToInt(newValue);
  return;
}


public void OnMapStart()
{
  h_NameCheckTimer = CreateTimer(
    g_flFilterInterval,
    Timer_NameFilter,
    _,
    TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
  return;
}

public void OnMapEnd()
{
  SafeClearTimer(h_NameCheckTimer);
  return;
}

public void OnClientDisconnect_Post(int client)
{
  g_bHasUserIDPrefix[client] = false;
  return;
}

// Check every player's name
public Action Timer_NameFilter(Handle hTimer)
{
  if(!g_bFilterEnabled)
    return Plugin_Continue;

  for(int i = 1; i <= MaxClients; ++i)
  {
    if(g_bHasUserIDPrefix[i])
      continue;

    // Filter clients that wont work with CheckCommandAccess and GetClientName
    if(!IsClientInGame(i) || IsFakeClient(i) || IsClientSourceTV(i) || IsClientReplay(i))
      continue;

    if(CheckCommandAccess(i, "sm_unicodefilter_ignore", ADMFLAG_BAN, true))
      continue;

    char nameBuff[MAX_NAME_LENGTH];
    GetClientName(i, nameBuff, sizeof(nameBuff));
    FilterUnicodeName(i, nameBuff);
  }
  return Plugin_Continue;
}

// Allow name to be re-scanned if it changes
public Action Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if(client > 0 && client <= MaxClients)
    g_bHasUserIDPrefix[client] = false;
}

/**
 * Add Client UserID prefix to a name if it has less than
 * a certain amount of ASCII characters in a row.
 * If g_iFilterMode is 0, Add prefix if name contains ANY non-valid-ASCII characters
 */
stock void FilterUnicodeName(int client, char[] name)
{
  int validCharsInRow = 0;
  bool unicodeFound = false;

  for(int i = 0; i < strlen(name); ++i)
  {
    if(IsCharTypeable(name[i]))
      ++validCharsInRow;
    else
    {
      if(g_iFilterMode == 0)
      {
        unicodeFound = true;
        break;
      }
      else
        validCharsInRow = 0;
    }

    // If name meets minimum, cancel filter.
    if(g_iFilterMode > 0 && validCharsInRow == g_iFilterMode)
      return;
  }

  // Mode 0 and no unicode, cancel filter
  if(g_iFilterMode == 0 && !unicodeFound)
    return;

  // Name did not reach minimum, or contained unicode with mode = 0. Filter Name.
  char nameOut[MAX_NAME_LENGTH];
  int userId = GetClientUserId(client);
  Format(nameOut, sizeof(nameOut), "(#%i) %s", userId, name);

  SetClientName(client, nameOut);
  g_bHasUserIDPrefix[client] = true; // Ignore client in Timer_NameFilter

  if(g_bFilterNotify)
    TagPrintChat(client, "%T", "SM_UNICODEFILTER_Applied", client);
  return;
}

/**
 * If character is Typeable-ASCII, not Percentage-Sign-Inivisble-Name Exploit
 * and not SourceMod Admin Broadcast character
 */
stock bool IsCharTypeable(char ch)
{
  if(ch >= 0x20 && ch <= 0x7F && ch != '%' && ch != '@')
    return true;
  return false;
}



//=================================
// Staff Selectors

public bool Filter_Admins(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true)) // TODO: Is IsClientPlaying appropriate here?
    {
      if(CheckCommandAccess(i, "sm_targetgroup_admin", ADMFLAG_BAN, true))
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotAdmins(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(!CheckCommandAccess(i, "sm_targetgroup_admin", ADMFLAG_BAN, true))
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}



public bool Filter_Mods(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(CheckCommandAccess(i, "sm_targetgroup_mod", ADMFLAG_KICK, true))
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotMods(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(!CheckCommandAccess(i, "sm_targetgroup_mod", ADMFLAG_KICK, true))
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}



public bool Filter_Staff(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      bool isMod = CheckCommandAccess(i, "sm_targetgroup_mod", ADMFLAG_KICK, true);
      bool isAdmin = CheckCommandAccess(i, "sm_targetgroup_admin", ADMFLAG_BAN, true);
      if(isMod || isAdmin)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotStaff(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      bool isMod = CheckCommandAccess(i, "sm_targetgroup_mod", ADMFLAG_KICK, true);
      bool isAdmin = CheckCommandAccess(i, "sm_targetgroup_admin", ADMFLAG_BAN, true);
      if(!isMod && !isAdmin)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}



//=================================
// Random filters

public bool Filter_Random(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(GetRandomInt(0, 255) > g_iRandomBias)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


#if defined _TARGET_RANDOM_VARIATION
public bool Filter_RandomMulti(char[] pattern, Handle clients)
{
  // Bit dodgy but it should be better than StrEquals.
  char numString[3];
  BreakString(pattern[7], numString, sizeof(numString)); // 7 = "random", gives us the number.
  int randCount = StringToInt(numString);

  if(randCount < 1 || randCount > 31)
    return false; // Target fail.

  // Create Array of valid client indexes, sort randomly, count X people in order.
  int[] indexes = new int[MaxClients + 1];
  for(int i = 0; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
      indexes[i] = i;
    else
      indexes[i] = 0;
  }

  SortIntegers(indexes, MaxClients + 1, Sort_Random); // Dynamic Array, manually set size.

  bool found = false;
  int limit = (randCount < MaxClients) ? randCount : MaxClients;
  int count = 0;
  for(int i = 0; i <= MaxClients; ++i) // Count MaxClients; unknown number of blank spaces.
  {
    if(indexes[i] == 0) // The above for-loop sets 0 for all invalid clients.
      continue;

    PushArrayCell(clients, indexes[i]);
    found = true;
    count++;

    if(count >= limit)
      break;
  }
  return found;
}
#endif



//=================================
// Class Filters

/**
 * Scout
 */
public bool Filter_Scout(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Scout)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotScout(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Scout)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Soldier
 */
public bool Filter_Soldier(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Soldier)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotSoldier(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Soldier)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Pyro
 */
public bool Filter_Pyro(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Pyro)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotPyro(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Pyro)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Demoman
 */
public bool Filter_Demo(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_DemoMan)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotDemo(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_DemoMan)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Heavy
 */
public bool Filter_Heavy(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Heavy)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotHeavy(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Heavy)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Engineer
 */
public bool Filter_Engie(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Engineer)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotEngie(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Engineer)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Medic
 */
public bool Filter_Medic(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Medic)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotMedic(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Medic)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Sniper
 */
public bool Filter_Sniper(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Sniper)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotSniper(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Sniper)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}


/**
 * Spy
 */
public bool Filter_Spy(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) == TFClass_Spy)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
}

public bool Filter_NotSpy(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true))
    {
      if(TF2_GetPlayerClass(i) != TFClass_Spy)
      {
        PushArrayCell(clients, i);
        found = true;
      }
    }
  }
  return found;
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
