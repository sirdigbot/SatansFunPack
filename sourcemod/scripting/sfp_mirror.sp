#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>

//=================================
// Constants
#define PLUGIN_VERSION  "1.0.1"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/mirror_update.txt"


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
bool    g_bIsMirrored[MAXPLAYERS + 1];


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Mirror",
  author =      "SirDigby",
  description = "Stop Hitting Yourself",
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
  LoadTranslations("sfp.mirror.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");

  h_bUpdate = CreateConVar("sm_sfp_mirror_update", "1", "Update Satan's Fun Pack - Mirror Damage Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  RegAdminCmd("sm_mirror", CMD_MirrorDamage, ADMFLAG_KICK, "Redirect a player's damage to themself");

  /*** Handle Late Loads ***/
  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; ++i)
    {
      if(IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
    }

    // Find Active Buildings and Hook OnTakeDamage
    int idx = MaxClients+1;
    while((idx = FindEntityByClassname(idx, "obj_sentrygun")) != INVALID_ENT_REFERENCE)
    {
      if(IsValidEdict(idx))
        SDKHook(idx, SDKHook_OnTakeDamage, OnTakeDamage);
    }

    idx = MaxClients+1;
    while((idx = FindEntityByClassname(idx, "obj_dispenser")) != INVALID_ENT_REFERENCE)
    {
      if(IsValidEdict(idx))
        SDKHook(idx, SDKHook_OnTakeDamage, OnTakeDamage);
    }

    idx = MaxClients+1;
    while((idx = FindEntityByClassname(idx, "obj_teleporter")) != INVALID_ENT_REFERENCE)
    {
      if(IsValidEdict(idx))
        SDKHook(idx, SDKHook_OnTakeDamage, OnTakeDamage);
    }
  }

  PrintToServer("%T", "SFP_MirrorLoaded", LANG_SERVER);
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


public void OnClientPutInServer(int client)
{
  if(!IsClientReplay(client) && !IsClientSourceTV(client))
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
  return;
}

public void OnClientDisconnect(int client)
{
  g_bIsMirrored[client] = false;
  SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
  return;
}

// Hooks Normal Builds and spawns from something like RTD or ent_create
public void OnEntityCreated(int entity, const char[] classname)
{
  if(IsBuilding(classname))
    SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
  return;
}

// Triggers when Removed, Destroyed or Detonated
public void OnEntityDestroyed(int entity)
{
  if(IsValidEdict(entity)) // Limit string usage
  {
    char classname[15]; // "obj_teleporter" + \0
    GetEdictClassname(entity, classname, sizeof(classname));
    if(IsBuilding(classname))
      SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
  }
  return;
}

stock bool IsBuilding(const char[] classname)
{
  if(StrEqual(classname, "obj_sentrygun", true))
    return true;
  else if(StrEqual(classname, "obj_dispenser", true))
    return true;
  else if(StrEqual(classname, "obj_teleporter", true))
    return true;
  return false;
}


public Action OnTakeDamage(
  int victim,
  int &attacker,
  int &inflictor,
  float &damage,
  int &damagetype,
  int &weapon,
  float damageForce[3],
  float damagePosition[3])
{
  if(attacker > 0 && attacker <= MaxClients)
  {
    if(g_bIsMirrored[attacker] && attacker != victim) // Victim can also be a building
    {
      int hp  = GetClientHealth(attacker);
      int dmg = RoundFloat(damage);
      if(hp > 0 && hp > dmg)
        TF2_SetHealth(attacker, hp - dmg);
      else
        ForcePlayerSuicide(attacker);

      damage = 0.0;
      return Plugin_Changed;
    }
  }
  return Plugin_Continue;
}


/**
 * Toggle Mirror Damage on a player
 *
 * sm_mirror <Target> <1/0>
 */
public Action CMD_MirrorDamage(int client, int args)
{
  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_MIRROR_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[MAX_BOOLSTRING_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));

  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    0,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  int iState = GetStringBool(arg2, false, true, true, true);
  if(iState == -1)
  {
    TagReplyUsage(client, "%T", "SM_MIRROR_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i <= MaxClients; ++i)
    g_bIsMirrored[targ_list[i]] = view_as<bool>(iState);

  if(iState)
    TagActivity(client, "%T", "SM_MIRROR_Enable", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_MIRROR_Disable", LANG_SERVER, targ_name);
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
