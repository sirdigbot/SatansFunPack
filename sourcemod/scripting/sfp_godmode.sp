#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/godmode_update.txt"

#define ENTPROP_MORTAL  2
#define ENTPROP_BUDDHA  1
#define ENTPROP_GOD     0

enum GodMode
{
  State_Mortal = 0,
  State_Buddha,
  State_God
};

//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
bool    g_bAllowNoteCreation;
GodMode g_GodModeState[MAXPLAYERS + 1] = {State_Mortal, ...};
bool    g_bNoteActive[MAXPLAYERS + 1];
Handle  h_NoteCooldownTimer[MAXPLAYERS + 1] = {null, ...};



/**
 * Known Bugs
 * - Max Health still drains with the eviction notice
 * - Immortal Note can only be displayed to one person at a time.
 * - TODO Immortal Note does not display if you damage a pyro.
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - God Mode",
  author =      "SirDigby",
  description = "Shrug Off Bullets Like Your Responsibilities",
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
  LoadTranslations("sfp.godmode.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");

  h_bUpdate = CreateConVar("sm_sfp_godmode_update", "1", "Update Satan's Fun Pack - God Mode Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  RegAdminCmd("sm_god",     CMD_God,    ADMFLAG_BAN, "Toggle God Mode");
  RegAdminCmd("sm_buddha",  CMD_Buddha, ADMFLAG_BAN, "Toggle Buddha Mode");
  RegAdminCmd("sm_mortal",  CMD_Mortal, ADMFLAG_BAN, "Disable Buddha or God Mode");

  HookEvent("player_spawn",         OnPlayerSpawn,  EventHookMode_Post);
  HookEvent("teamplay_round_win",   OnRoundEnd,     EventHookMode_PostNoCopy);
  HookEvent("teamplay_round_start", OnRoundStart,   EventHookMode_PostNoCopy);

  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; ++i)
    {
      if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        SDKHook(i, SDKHook_TraceAttack, TraceAttack);
    }
  }

  g_bAllowNoteCreation = true;

  /**
   * Overrides
   * sm_godmode_target - Shared with buddha
   * sm_mortal_target
   */

  PrintToServer("%T", "SFP_GodModeLoaded", LANG_SERVER);
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
  if(!IsFakeClient(client) && !IsClientReplay(client) && !IsClientSourceTV(client))
    SDKHook(client, SDKHook_TraceAttack, TraceAttack);
  return;
}

public void OnClientDisconnect(int client)
{
  SDKUnhook(client, SDKHook_TraceAttack, TraceAttack);
  SafeClearTimer(h_NoteCooldownTimer[client]);
  g_GodModeState[client]  = State_Mortal;
  g_bNoteActive[client]   = false;
  return;
}

public Action OnPlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
  if(client >= 1)
  {
    if(g_GodModeState[client] == State_God)
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_GOD);
      if(!IsFakeClient(client))
        TagPrintChat(client, "%T", "SM_GOD_Spawn", client);
    }
    else if(g_GodModeState[client] == State_Buddha)
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_BUDDHA);
      if(!IsFakeClient(client))
        TagPrintChat(client, "%T", "SM_BUDDHA_Spawn", client);
    }
  }
  return Plugin_Continue;
}


public Action TraceAttack(
  int client,
  int &attacker,
  int &inflictor,
  float &damage,
  int &damagetype,
  int &ammotype,
  int hitbox,
  int hitgroup)
{
  if(!g_bAllowNoteCreation || client < 1 || attacker < 1)
    return Plugin_Continue;

  if(TF2_GetPlayerClass(client) == TF2_GetPlayerClass(attacker))
    return Plugin_Continue;

  if(GetEntProp(client, Prop_Data, "m_takedamage") != ENTPROP_MORTAL)
  {
    if(!g_bNoteActive[attacker] && IsClientInGame(attacker) && !IsFakeClient(attacker))
    {
      char noteText[32];
      Format(noteText, sizeof(noteText), "%T", "SM_GODMODE_Note", attacker);

      Handle event = CreateEvent("show_annotation", false);
      if(event != null)
      {
        SetEventInt(event,    "follow_entindex",    client);
        SetEventInt(event,    "visibilityBitfield", (1 << attacker));
        SetEventFloat(event,  "lifetime",           1.1);
        SetEventString(event, "play_sound",         "misc/null.wav");
        SetEventString(event, "text",               noteText);
        FireEvent(event, false); // FireEvent deletes handle. TODO What does broadcast do?

        g_bNoteActive[attacker]       = true;
        h_NoteCooldownTimer[attacker] = CreateTimer(2.5, Timer_ResetGlobals, attacker);
        // Dont put nomapchange flag on one-time timers.
      }
    }
  }
  return Plugin_Continue;
}

public Action Timer_ResetGlobals(Handle timer, any client)
{
  g_bNoteActive[client]       = false;
  h_NoteCooldownTimer[client] = null;
  return Plugin_Stop;
}

public Action OnRoundStart(Handle event, char[] name, bool dontBroadcast)
{
  g_bAllowNoteCreation = true;
  return Plugin_Continue;
}

public Action OnRoundEnd(Handle event, char[] name, bool dontBroadcast)
{
  g_bAllowNoteCreation = false;
  for(int i = 1; i <= MaxClients; ++i)
  {
    SafeClearTimer(h_NoteCooldownTimer[i]);
    g_bNoteActive[i] = false;
  }
  return Plugin_Continue;
}



/**
 * Take no damage.
 *
 * sm_god <[Target] [1/0]>
 * Both args are required at once to prevent chaotic toggling
 */
public Action CMD_God(int client, int args)
{
  if(args == 0)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(g_GodModeState[client] == State_Mortal)
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_GOD);
      g_GodModeState[client] = State_God;
      TagReply(client, "%T", "SM_GOD_Enabled_Self", client);
    }
    else if(g_GodModeState[client] == State_Buddha)
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_GOD);
      g_GodModeState[client] = State_God;
      TagReply(client, "%T", "SM_GOD_Switched_Self", client);
    }
    else
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_MORTAL);
      g_GodModeState[client] = State_Mortal;
      TagReply(client, "%T", "SM_GOD_Disabled_Self", client);
    }
    return Plugin_Handled;
  }


  // To prevent annoying flip-flop situations, both args are mandatory at once.
  if(args == 1)
  {
    TagReplyUsage(client, "%T", "SM_GOD_Usage", client);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_godmode_target", ADMFLAG_BAN, true))
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
    0,
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
    TagReplyUsage(client, "%T", "SM_GOD_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow spectators and dead
    {
      if(state)
      {
        if(IsPlayerAlive(targ_list[i]))
          SetEntProp(targ_list[i], Prop_Data, "m_takedamage", ENTPROP_GOD);
        g_GodModeState[targ_list[i]] = State_God;
      }
      else
      {
        if(IsPlayerAlive(targ_list[i]))
          SetEntProp(targ_list[i], Prop_Data, "m_takedamage", ENTPROP_MORTAL);
        g_GodModeState[targ_list[i]] = State_Mortal;
      }
    }
  }

  if(state)
    TagActivity(client, "%T", "SM_GOD_Enabled", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_GOD_Disabled", LANG_SERVER, targ_name);
  return Plugin_Handled;
}


/**
 * Godmode but with knockback/damage forces
 *
 * sm_buddha <[Target] [1/0]>
 * Both args are required at once to prevent chaotic toggling
 */
public Action CMD_Buddha(int client, int args)
{
  if(args == 0)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(g_GodModeState[client] == State_Mortal)
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_BUDDHA);
      g_GodModeState[client] = State_Buddha;
      TagReply(client, "%T", "SM_BUDDHA_Enabled_Self", client);
    }
    else if(g_GodModeState[client] == State_God)
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_BUDDHA);
      g_GodModeState[client] = State_Buddha;
      TagReply(client, "%T", "SM_BUDDHA_Switched_Self", client);
    }
    else
    {
      SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_MORTAL);
      g_GodModeState[client] = State_Mortal;
      TagReply(client, "%T", "SM_BUDDHA_Disabled_Self", client);
    }
    return Plugin_Handled;
  }

  // To prevent annoying flip-flop situations, both args are mandatory at once.
  if(args == 1)
  {
    TagReplyUsage(client, "%T", "SM_BUDDHA_Usage", client);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_godmode_target", ADMFLAG_BAN, true))
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
    0,
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
    TagReplyUsage(client, "%T", "SM_BUDDHA_Usage", client);
    return Plugin_Handled;
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow spectators and dead
    {
      if(state)
      {
        if(IsPlayerAlive(targ_list[i]))
          SetEntProp(targ_list[i], Prop_Data, "m_takedamage", ENTPROP_BUDDHA);
        g_GodModeState[targ_list[i]] = State_Buddha;
      }
      else
      {
        if(IsPlayerAlive(targ_list[i]))
          SetEntProp(targ_list[i], Prop_Data, "m_takedamage", ENTPROP_MORTAL);
        g_GodModeState[targ_list[i]] = State_Mortal;
      }
    }
  }

  if(state)
    TagActivity(client, "%T", "SM_BUDDHA_Enabled", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_BUDDHA_Disabled", LANG_SERVER, targ_name);
  return Plugin_Handled;
}


public Action CMD_Mortal(int client, int args)
{
  if(args == 0)
  {
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    SetEntProp(client, Prop_Data, "m_takedamage", ENTPROP_MORTAL);
    g_GodModeState[client] = State_Mortal;
    TagReply(client, "%T", "SM_MORTAL_Done_Self", client);
    return Plugin_Handled;
  }

  if(!CheckCommandAccess(client, "sm_mortal_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  // Get Target
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

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow spectators and dead
    {
      if(IsPlayerAlive(targ_list[i]))
        SetEntProp(targ_list[i], Prop_Data, "m_takedamage", ENTPROP_MORTAL);
      g_GodModeState[targ_list[i]] = State_Mortal;
    }
  }

  TagActivity(client, "%T", "SM_MORTAL_Done", LANG_SERVER, targ_name);
  return Plugin_Handled;
}


stock void SafeClearTimer(Handle &timer)
{
  if(timer != null)
    KillTimer(timer);
  timer = null;
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
