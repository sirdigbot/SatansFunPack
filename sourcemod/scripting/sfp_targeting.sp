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
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL  "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL  "https://sirdigbot.github.io/SatansFunPack/sourcemod/targeting_update.txt"

// Comment out to stop the excessive random filters from compiling.
#define _TARGET_RANDOM_VARIATION



public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Targeting",
  author =      "SirDigby",
  description = "Useful Target Selectors for All Commands",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};



public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");

  h_bUpdate = FindConVar("sm_satansfunpack_update");
  if(h_bUpdate == null)
    SetFailState("%T", "SFP_UpdateCvarFail", LANG_SERVER);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  AddMultiTargetFilter("admins", Filter_Admins, "All Admins", false);
  AddMultiTargetFilter("!admins", Filter_NotAdmins, "All Non-Admins", false);
  AddMultiTargetFilter("mods", Filter_Mods, "All Moderators", false);
  AddMultiTargetFilter("!mods", Filter_NotMods, "All Non-Moderators", false);
  AddMultiTargetFilter("staff", Filter_Staff, "All Staff", false);
  AddMultiTargetFilter("!staff", Filter_NotStaff, "All Non-Staff", false);

  // Random
  AddMultiTargetFilter("random", Filter_Random, "Random Players", false);
  #if defined _TARGET_RANDOM_VARIATION
  AddMultiTargetFilter("random1", Filter_Random, "1 Random Player", false);
  AddMultiTargetFilter("random2", Filter_Random, "2 Random Players", false);
  AddMultiTargetFilter("random3", Filter_Random, "3 Random Players", false);
  AddMultiTargetFilter("random4", Filter_Random, "4 Random Players", false);
  AddMultiTargetFilter("random5", Filter_Random, "5 Random Players", false);
  AddMultiTargetFilter("random6", Filter_Random, "6 Random Players", false);
  AddMultiTargetFilter("random7", Filter_Random, "7 Random Players", false);
  AddMultiTargetFilter("random8", Filter_Random, "8 Random Players", false);
  AddMultiTargetFilter("random9", Filter_Random, "9 Random Players", false);
  AddMultiTargetFilter("random10", Filter_Random, "10 Random Players", false);

  AddMultiTargetFilter("random11", Filter_Random, "11 Random Players", false);
  AddMultiTargetFilter("random12", Filter_Random, "12 Random Players", false);
  AddMultiTargetFilter("random13", Filter_Random, "13 Random Players", false);
  AddMultiTargetFilter("random14", Filter_Random, "14 Random Players", false);
  AddMultiTargetFilter("random15", Filter_Random, "15 Random Players", false);
  AddMultiTargetFilter("random16", Filter_Random, "16 Random Players", false);
  AddMultiTargetFilter("random17", Filter_Random, "17 Random Players", false);
  AddMultiTargetFilter("random18", Filter_Random, "18 Random Players", false);
  AddMultiTargetFilter("random19", Filter_Random, "19 Random Players", false);
  AddMultiTargetFilter("random20", Filter_Random, "20 Random Players", false);

  AddMultiTargetFilter("random21", Filter_Random, "21 Random Players", false);
  AddMultiTargetFilter("random22", Filter_Random, "22 Random Players", false);
  AddMultiTargetFilter("random23", Filter_Random, "23 Random Players", false);
  AddMultiTargetFilter("random24", Filter_Random, "24 Random Players", false);
  AddMultiTargetFilter("random25", Filter_Random, "25 Random Players", false);
  AddMultiTargetFilter("random26", Filter_Random, "26 Random Players", false);
  AddMultiTargetFilter("random27", Filter_Random, "27 Random Players", false);
  AddMultiTargetFilter("random28", Filter_Random, "28 Random Players", false);
  AddMultiTargetFilter("random29", Filter_Random, "29 Random Players", false);
  AddMultiTargetFilter("random30", Filter_Random, "30 Random Players", false);

  AddMultiTargetFilter("random31", Filter_Random, "31 Random Players", false);
  #endif

  // Classes
  AddMultiTargetFilter("scouts",      Filter_Scout, "All Scouts", false);
  AddMultiTargetFilter("!scouts",     Filter_NotScout, "All Non-Scouts", false);

  AddMultiTargetFilter("soldiers",    Filter_Soldier, "All Soldiers", false);
  AddMultiTargetFilter("!soldiers",   Filter_NotSoldier, "All Non-Soldiers", false);

  AddMultiTargetFilter("pyros",       Filter_Pyro, "All Pyros", false);
  AddMultiTargetFilter("!pyros",      Filter_NotPyro, "All Non-Pyros", false);

  AddMultiTargetFilter("demomen",     Filter_Demo, "All Demomen", false);
  AddMultiTargetFilter("!demomen",    Filter_NotDemo, "All Non-Demomen", false);

  AddMultiTargetFilter("heavies",     Filter_Heavy, "All Heavies", false); // TODO Heavys?
  AddMultiTargetFilter("!heavies",    Filter_NotHeavy, "All Non-Heavies", false);

  AddMultiTargetFilter("engineers",   Filter_Engie, "All Engineers", false);
  AddMultiTargetFilter("!engineers",  Filter_NotEngie, "All Non-Engineers", false);

  AddMultiTargetFilter("medics",      Filter_Medic, "All Medics", false);
  AddMultiTargetFilter("!medics",     Filter_NotMedic, "All Non-Medics", false);

  AddMultiTargetFilter("snipers",     Filter_Sniper, "All Snipers", false);
  AddMultiTargetFilter("!snipers",    Filter_NotSniper, "All Non-Snipers", false);

  AddMultiTargetFilter("spies",       Filter_Spy, "All Spies", false);
  AddMultiTargetFilter("!spies",      Filter_NotSpy, "All Non-Spies", false);

  /**
   * Overrides
   * sm_targetgroup_admin
   * sm_targetgroup_mod
   */

  PrintToServer("%T", "SFP_TargetingLoaded", LANG_SERVER);
}



public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  return;
}



//=================================
// Staff Selectors

public bool Filter_Admins(char[] pattern, Handle clients)
{
  bool found = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
// Random Filter

public bool Filter_Random(char[] pattern, Handle clients)
{
  int randCount = 0;
  if(StrEqual(pattern, "random", true))
    randCount = MAXPLAYERS;
  else
  {
    #if defined _TARGET_RANDOM_VARIATION
    // Bit dodgy but it should be better than StrEquals.
    char numString[3]; // TODO: This should be fine but idk, check.
    BreakString(pattern[6], numString, sizeof(numString)); // 6 = "random", gives us the number.
    int numInt = StringToInt(numString);

    if(numInt > 0 && numInt < 32)
      randCount = numInt;
    else
      randCount = 0; // Count fail.
    #endif
  }

  if(randCount == 0)
    return false;

  // Create Array of valid client indexes, sort randomly, count X people in order.
  int indexes[MAXPLAYERS + 1];
  for(int i = 0; i <= MaxClients; ++i)
  {
    if(IsClientPlaying(i, true, true))
      indexes[i] = i;
    else
      indexes[i] = 0;
  }

  SortIntegers(indexes, sizeof(indexes), Sort_Random);

  bool found = false;
  int limit = (randCount < MaxClients) ? randCount : MaxClients;
  int count = 0;
  for(int i = 0; i <= MaxClients; ++i) // Count MaxClients; unknown number of blank spaces.
  {
    if(count >= limit)
      break;

    if(indexes[i] == 0) // The above for-loop sets 0 for all invalid clients.
      continue;

    PushArrayCell(clients, indexes[i]);
    found = true;
    count++;
  }
  return found;
}



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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
    if(IsClientPlaying(i, true, true))
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
