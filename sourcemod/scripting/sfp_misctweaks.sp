#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/misctweaks_update.txt"

#define MAX_BUTTONS         26 // Total # of IN_ definitions in entity_prop_stocks.inc
#define TEMP_PARTICLE_TIME  5.0
#define KNIFE_YER_ID        225

#define HEADSHOT_LEVEL      SNDLEVEL_SCREAMING
#define BACKSTAB_LEVEL      SNDLEVEL_DISHWASHER

#define _INCLUDE_MEDIGUNSHIELD
#define _INCLUDE_TAUNTCANCEL
#define _INCLUDE_KILLEFFECT

//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;

int     g_fbLastButtons[MAXPLAYERS + 1];

#if defined _INCLUDE_MEDIGUNSHIELD
Handle  h_iShieldEnabled = null;
int     g_iShieldEnabled;
Handle  h_bShieldStockOnly = null;
bool    g_bShieldStockOnly;
Handle  h_flShieldDmg = null;
float   g_flShieldDmg;
#endif

#if defined _INCLUDE_TAUNTCANCEL
Handle  h_SDKStopTaunt = null;
Handle  h_bTauntCancelEnabled = null;
bool    g_bTauntCancelEnabled;
Handle  h_iTauntCancelCooldown = null;
int     g_iTauntCancelCooldown;
int     g_iLastTauntCancel[MAXPLAYERS + 1]; // Cooldown. Some taunts can spam effects.
#endif

#if defined _INCLUDE_KILLEFFECT
enum KillEffects
{
  Effect_Headshot = 0,
  Effect_Backstab,
  Effect_Max
};
Handle  h_szConfig = null;
char    g_szConfig[PLATFORM_MAX_PATH];
char    g_szKillEffectSound[Effect_Max][PLATFORM_MAX_PATH];
char    g_szKillEffectParticle[Effect_Max][50];           // Longest is 47 chars I think
Handle  h_iKillEffectSoundMode = null;
int     g_iKillEffectSoundMode;
Handle  h_bKillEffectParticleMode = null;
int     g_bKillEffectParticleMode;
#endif

/**
 * Known Bugs
 * TODO sm_forceshield cant actually forcibly spawn the shield.
 *  You need to either switch weapons and back, or press +attack3.
 * TODO add targeting to sm_forceshield
 * TODO sm_stoptaunt was meant to detect a keypress while taunting,
 *  but taunting blocks OnPlayerRunCmd button events.
 * Bonk Drink causes a lot of 'miss' texts which might cause lag/a crash if too many fire.
 * TODO More options in the kill effect config:
 *  - Flag to play sound to attacker/victim/all
 *  - Volume Control
 *  - Pitch Control
 *  - Effect Scaling
 *  - Multiple sounds and particles
 *  - TODO SoundLevel control
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Miscellaneous Tweaks",
  author =      "SirDigby",
  description = "A Set of Miscellaneous Game Tweaks",
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
  LoadTranslations("sfp.misctweaks.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");


  h_bUpdate = CreateConVar("sm_sfp_misctweaks_update", "1", "Update Satan's Fun Pack - Miscellaneous Tweaks Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

#if defined _INCLUDE_TAUNTCANCEL
  Handle gameData = LoadGameConfigFile("tf2.satansfunpack_misctweaks");
  if(gameData == INVALID_HANDLE)
  {
    SetFailState("%T", "SFP_NoGameData", LANG_SERVER, "tf2.satansfunpack_misctweaks");
    return;
  }
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFPlayer::StopTaunt");
  h_SDKStopTaunt = EndPrepSDKCall();
  if(h_SDKStopTaunt == INVALID_HANDLE)
  {
    CloseHandle(gameData);
    SetFailState("%T", "SM_MISCTWEAKS_SDKToolsInitFail", LANG_SERVER, "CTFPlayer::StopTaunt");
    return;
  }
  CloseHandle(gameData);

  h_bTauntCancelEnabled = CreateConVar("sm_sfp_misctweaks_tauntcancel", "1", "Allow Taunt Cancelling\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bTauntCancelEnabled = GetConVarBool(h_bTauntCancelEnabled);
  HookConVarChange(h_bTauntCancelEnabled, UpdateCvars);

  h_iTauntCancelCooldown = CreateConVar("sm_sfp_misctweaks_tauntcancel_cooldown", "5", "Cooldown for sm_stoptaunt\n(Default: 5)", FCVAR_NONE, true, 0.0);
  g_iTauntCancelCooldown = GetConVarInt(h_iTauntCancelCooldown);
  HookConVarChange(h_iTauntCancelCooldown, UpdateCvars);
#endif

#if defined _INCLUDE_MEDIGUNSHIELD
  h_iShieldEnabled = CreateConVar("sm_sfp_misctweaks_shield", "1", "Allow The Medigun Shield\n-1 = Disabled\n0 = sm_forceshield Only\n1 = Enabled\n(Default: 1)", FCVAR_NONE, true, -1.0, true, 1.0);
  g_iShieldEnabled = GetConVarInt(h_iShieldEnabled);
  HookConVarChange(h_iShieldEnabled, UpdateCvars);

  h_bShieldStockOnly = CreateConVar("sm_sfp_misctweaks_shield_stock", "1", "Only Allow Stock Mediguns (and variants) to create Shields\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bShieldStockOnly = GetConVarBool(h_bShieldStockOnly);
  HookConVarChange(h_bShieldStockOnly, UpdateCvars);

  h_flShieldDmg = CreateConVar("sm_sfp_misctweaks_shield_dmg", "1.0", "Damage Amount For Contact with Medigun Shield Per Frame\n(Default: 1.0)", FCVAR_NONE, true, 0.0, true, 99999.0);
  g_flShieldDmg = GetConVarFloat(h_flShieldDmg);
  HookConVarChange(h_flShieldDmg, UpdateCvars);
#endif

#if defined _INCLUDE_KILLEFFECT
  h_iKillEffectSoundMode = CreateConVar("sm_sfp_misctweaks_killeffect_sound", "2", "Kill Effect Sound Mode\n0 - No Sound\n1 - Enabled (Sound to Killer)\n2 - Enabled (Sound to All)\n(Default: 2)", FCVAR_NONE, true, 0.0, true, 2.0);
  g_iKillEffectSoundMode = GetConVarInt(h_iKillEffectSoundMode);
  HookConVarChange(h_iKillEffectSoundMode, UpdateCvars);

  h_bKillEffectParticleMode = CreateConVar("sm_sfp_misctweaks_killeffect_particle", "1", "Kill Effect Particle Mode\n0 - Disabled\n1 - Enabled\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bKillEffectParticleMode = GetConVarBool(h_bKillEffectParticleMode);
  HookConVarChange(h_bKillEffectParticleMode, UpdateCvars);

  h_szConfig = CreateConVar("sm_satansfunpack_tweakconfig", "satansfunpack_tweaks.cfg", "Config File used for Satan's Fun Pack Misc. Tweaks (Relative to Sourcemod/Configs)\n(Default: satansfunpack_tweaks.cfg)", FCVAR_SPONLY);

  char cvarBuffer[PLATFORM_MAX_PATH], pathBuffer[CONFIG_SIZE];
  GetConVarString(h_szConfig, cvarBuffer, sizeof(cvarBuffer));
  Format(pathBuffer, sizeof(pathBuffer), "configs/%s", cvarBuffer);
  BuildPath(Path_SM, g_szConfig, sizeof(g_szConfig), pathBuffer);
  HookConVarChange(h_szConfig, UpdateCvars);

  LoadConfig();
  // Call PrecacheKillSounds() in OnMapStart(). Happens after OnPluginStart()
#endif


#if defined _INCLUDE_MEDIGUNSHIELD
  RegAdminCmd("sm_forceshield", CMD_ForceShield,  ADMFLAG_BAN,  "Force Medic's Medigun Shield");
  RegAdminCmd("sm_filluber",    CMD_FillUber,     ADMFLAG_SLAY, "Give a Player Max Ubercharge");
#endif
#if defined _INCLUDE_TAUNTCANCEL
  RegConsoleCmd("sm_stoptaunt", CMD_TauntCancel, "Cancel Any Active Taunt");
#endif
#if defined _INCLUDE_KILLEFFECT
RegAdminCmd("sm_misctweaks_reloadcfg", CMD_ConfigReload, ADMFLAG_ROOT, "Reload Config for Satan's Fun Pack - Miscellaneous Tweaks");
#endif


#if defined _INCLUDE_MEDIGUNSHIELD
  HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
#endif
#if defined _INCLUDE_KILLEFFECT
  HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
#endif

  /*** Handle Lateloads ***/
  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; ++i)
    {
      if(IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
      {
#if defined _INCLUDE_MEDIGUNSHIELD
        if(TF2_GetPlayerClass(i) == TFClass_Medic)
          ResetShieldMeter(i); // This doesn't really need to be handled in lateload
        SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
#endif
      }
    }
  }

  /**
   * Overrides
   * sm_filluber_target - Can target with sm_filluber
   * sm_stoptaunt_target - "  "  sm_stoptaunt
   */

  PrintToServer("%T", "SFP_MiscTweaksLoaded", LANG_SERVER);
  return;
}

#if defined _INCLUDE_KILLEFFECT
public void OnMapStart() // Also called on lateload
{
  PrecacheKillSounds();
  return;
}
#endif


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
#if defined _INCLUDE_MEDIGUNSHIELD
  else if(cvar == h_iShieldEnabled)
    g_iShieldEnabled = StringToInt(newValue);
  else if(cvar == h_flShieldDmg)
    g_flShieldDmg = GetConVarFloat(h_flShieldDmg);
  else if(cvar == h_bShieldStockOnly)
    g_bShieldStockOnly = GetConVarBool(h_bShieldStockOnly);
#endif
#if defined _INCLUDE_TAUNTCANCEL
  else if(cvar == h_bTauntCancelEnabled)
    g_bTauntCancelEnabled = GetConVarBool(h_bTauntCancelEnabled);
  else if(cvar == h_iTauntCancelCooldown)
    g_iTauntCancelCooldown = StringToInt(newValue);
#endif
#if defined _INCLUDE_KILLEFFECT
  else if(cvar == h_szConfig)
  {
    char pathBuffer[CONFIG_SIZE];
    Format(pathBuffer, sizeof(pathBuffer), "configs/%s", newValue);
    BuildPath(Path_SM, g_szConfig, sizeof(g_szConfig), pathBuffer);
    LoadConfig();
    PrecacheKillSounds();
  }
  else if(cvar == h_bKillEffectParticleMode)
    g_bKillEffectParticleMode = GetConVarBool(h_bKillEffectParticleMode);
  else if(cvar == h_iKillEffectSoundMode)
    g_iKillEffectSoundMode = StringToInt(newValue);
#endif
  return;
}



/**
 * Create Kill Effects under correct conditions
 */
#if defined _INCLUDE_KILLEFFECT
public Action OnPlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
  int victim    = GetClientOfUserId(GetEventInt(event, "userid", 0));
  int attacker  = GetClientOfUserId(GetEventInt(event, "attacker", 0));
  if(victim > 0 && attacker > 0) // GetClientOfUserId returns 0 on fail
  {
    switch(GetEventInt(event, "customkill", -1))
    {
      case TF_CUSTOM_HEADSHOT, TF_CUSTOM_HEADSHOT_DECAPITATION:
        CreateKillEffect(attacker, victim, view_as<int>(Effect_Headshot), HEADSHOT_LEVEL);
      case TF_CUSTOM_BACKSTAB:
      {
        int weaponEnt = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
        if(weaponEnt > MaxClients && IsValidEntity(weaponEnt))
        {
          if(GetEntProp(weaponEnt, Prop_Send, "m_iItemDefinitionIndex") == KNIFE_YER_ID)
            CreateKillEffect(attacker, victim, view_as<int>(Effect_Backstab), BACKSTAB_LEVEL);
        }
      }
    }
  }
  return Plugin_Continue;
}
#endif


public void OnClientPutInServer(int client)
{
  if(!IsClientReplay(client) && !IsClientSourceTV(client))
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
  return;
}

/**
 * Drain Shield Meter on Spawn to prevent weird issues
 */
public Action OnPlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
  if(client > 0)
  {
    if(TF2_GetPlayerClass(client) == TFClass_Medic)
      ResetShieldMeter(client);
  }
  return Plugin_Continue;
}

public void OnClientDisconnect_Post(int client)
{
  SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
  g_fbLastButtons[client] = 0;
  return;
}


/**
 * Create KeyPress/KeyRelease Events
 */
public Action OnPlayerRunCmd(
  int client,
  int &buttons,
  int &impulse,
  float vel[3],
  float angles[3],
  int &weapon,      // Is only set when switching weapons. Don't use.
  int &subtype,
  int &cmdnum,
  int &tickcount,
  int &seed,
  int mouse[2])
{
  if(client < 1 || client > MaxClients)
    return Plugin_Continue;

  for(int i = 0; i < MAX_BUTTONS; ++i)
  {
    int button = (1 << i);
    if(buttons & button) // If button is pressed and wasnt pressed before
    {
      if(!HasFlag(g_fbLastButtons[client], button))
        OnButtonPress(client, button);
    }
    else if(HasFlag(g_fbLastButtons[client], button)) // If button is not pressed but was before
      OnButtonRelease(client, button);
  }

  g_fbLastButtons[client] = buttons;
  return Plugin_Continue;
}

/**
 * Handle KeyPress Events
 *
 * MEDIGUN SHIELD: Create shield if +attack3 is triggered and player meets conditions.
 *  Only allow attack3 to be triggered once until key is released.
 */
stock void OnButtonPress(int client, int button)
{
  if(button == IN_ATTACK3)
  {
#if defined _INCLUDE_MEDIGUNSHIELD
    if(g_iShieldEnabled != 1)
      return;

    if(!IsClientPlaying(client)) // Only allow alive, actual players
      return;


    // Filter by Class, Active Weapon, Medigun Skin,
    // Shield Charge, Uber Charge Level and Ubered State
    if(TF2_GetPlayerClass(client) != TFClass_Medic)
      return;

    int weaponEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(weaponEnt < MaxClients+1 || !IsValidEntity(weaponEnt))
      return;

    if(g_bShieldStockOnly && !IsStockMedigun(weaponEnt))
      return;

    // Check that Shield is completely drained
    if(FloatCompare(GetEntPropFloat(client, Prop_Send, "m_flRageMeter"), 0.0) != 0)
      return;

    // Check that uber is full and undeployed
    if(FloatCompare(GetEntPropFloat(weaponEnt, Prop_Send, "m_flChargeLevel"), 1.0) < 0)
      return;

    if(GetEntProp(weaponEnt, Prop_Send, "m_bChargeRelease") != 0)
      return;

    StartMedigunShield(client, weaponEnt);
#endif
  }
  return;
}

// Unused for now.
stock void OnButtonRelease(int client, int button)
{
  return;
}



/**
 * Reduce damage dealt by Medigun Shields
 */
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
  if(!IsValidEntity(inflictor))
    return Plugin_Continue;

  char classname[22];
  GetEdictClassname(inflictor, classname, sizeof(classname));
  if(StrEqual(classname, "entity_medigun_shield", true))
  {
    damage = g_flShieldDmg;
    return Plugin_Changed;
  }
  return Plugin_Continue;
}




/**
 * Force the medigun shield regardless of ubercharge.
 *
 * sm_forceshield
 */
#if defined _INCLUDE_MEDIGUNSHIELD
public Action CMD_ForceShield(int client, int args)
{
  if(g_iShieldEnabled == -1)
  {
    TagReply(client, "%T", "SM_FORCESHIELD_Disabled", client);
    return Plugin_Handled;
  }

  if(!IsClientPlaying(client))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }

  // Verify player can use shield
  // TODO Check if this is necessary when used with giveweapon
  if(TF2_GetPlayerClass(client) != TFClass_Medic)
  {
    TagReply(client, "%T", "SM_MISCTWEAKS_MedicOnly", client);
    return Plugin_Handled;
  }

  int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if(weapon < MaxClients+1 || !IsValidEntity(weapon))
  {
    TagReply(client, "%T", "SM_MISCTWEAKS_MedigunOnly", client);
    return Plugin_Handled;
  }

  // No need to check item index, just check it's actually a medigun.
  char classname[18];
  GetEntityClassname(weapon, classname, sizeof(classname));
  if(!StrEqual(classname, "tf_weapon_medigun", true))
  {
    TagReply(client, "%T", "SM_MISCTWEAKS_MedigunOnly", client);
    return Plugin_Handled;
  }

  StartMedigunShield(client, weapon, true); // Dont drain uber
  TagReply(client, "%T", "SM_FORCESHIELD_Deployed", client);
  return Plugin_Handled;
}

/**
 * Give a player full ubercharge
 * This was a testing command I decided to keep in.
 *
 * sm_filluber [Target]
 */
public Action CMD_FillUber(int client, int args)
{
  if(args < 1)
  {
    // Self Target
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(TF2_GetPlayerClass(client) != TFClass_Medic)
    {
      TagReply(client, "%T", "SM_MISCTWEAKS_MedicOnly", client);
      return Plugin_Handled;
    }

    int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if(medigun < MaxClients+1 || !IsValidEntity(medigun))
    {
      TagReply(client, "%T", "SM_MISCTWEAKS_MedigunOnly", client);
      return Plugin_Handled;
    }

    // Apply
    SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 1.0);
    TagReply(client, "%T", "SM_FILLUBER_Done_Self", client);
    return Plugin_Handled;
  }

  // Non-self target
  if(!CheckCommandAccess(client, "sm_filluber_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]) && TF2_GetPlayerClass(targ_list[i]) == TFClass_Medic)
    {
      int medigun = GetPlayerWeaponSlot(targ_list[i], TFWeaponSlot_Secondary);
      if(medigun > MaxClients && IsValidEntity(medigun))
        SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 1.0);
    }
  }

  TagActivity(client, "%T", "SM_FILLUBER_Done", LANG_SERVER, targ_name);
  return Plugin_Handled;
}
#endif



/**
 * Stop any active taunt.
 *
 * sm_stoptaunt [Target]
 * or stoptaunt [Target]
 */
#if defined _INCLUDE_TAUNTCANCEL
public Action CMD_TauntCancel(int client, int args)
{
  if(!g_bTauntCancelEnabled)
  {
    TagReply(client, "%T", "SM_TAUNTCANCEL_Disabled", client);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    // Self Target
    if(!IsClientPlaying(client))
    {
      TagReply(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    int now = GetTime();
    int remaining = (g_iTauntCancelCooldown - now) + g_iLastTauntCancel[client];
    if(remaining > 0)
    {
      TagReply(client, "%T", "SM_TAUNTCANCEL_Cooldown", client, remaining);
      return Plugin_Handled;
    }

    // Apply
    if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
    {
      SDKCall(h_SDKStopTaunt, client);
      g_iLastTauntCancel[client] = now;
      TagReply(client, "%T", "SM_TAUNTCANCEL_Done_Self", client);
    }
    // Don't say anything if taunt wasnt stopped.
    // This makes the command friendlier to bind.
    return Plugin_Handled;
  }

  // Non-self target
  if(!CheckCommandAccess(client, "sm_stoptaunt_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
    {
      if(TF2_IsPlayerInCondition(targ_list[i], TFCond_Taunting))
        SDKCall(h_SDKStopTaunt, targ_list[i]);
    }
  }

  TagActivity(client, "%T", "SM_TAUNTCANCEL_Done", LANG_SERVER, targ_name);
  return Plugin_Handled;
}
#endif




/**
 * Reload the config file manually
 *
 * sm_misctweaks_reloadcfg
 */
#if defined _INCLUDE_KILLEFFECT
public Action CMD_ConfigReload(int client, int args)
{
  bool result = LoadConfig();
  if(result)
  {
    PrecacheKillSounds();
    TagReply(client, "%T", "SFP_ConfigReload_Success", client);
  }
  else
    TagReply(client, "%T", "SFP_ConfigReload_Fail", client, "sfp_misctweaks");
  return Plugin_Handled;
}

stock bool LoadConfig()
{
  if(!FileExists(g_szConfig))
  {
    SetFailState("%T", "SFP_NoConfig", LANG_SERVER, g_szConfig);
    return false;
  }

  // Create and check KeyValues
  KeyValues hKeys = CreateKeyValues("SatansKillEffects");
  if(!FileToKeyValues(hKeys, g_szConfig))
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfig", LANG_SERVER, g_szConfig);
    return false;
  }

  if(!hKeys.GotoFirstSubKey())
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfigSubKey", LANG_SERVER, g_szConfig);
    return false;
  }

  hKeys.Rewind();

  for(int i = 0; i < view_as<int>(Effect_Max); ++i)
  {
    g_szKillEffectSound[i] = "";
    g_szKillEffectParticle[i] = "";
  }
  int count = 0, skipCount = 0;

  char buff[PLATFORM_MAX_PATH], fullPath[PLATFORM_MAX_PATH + 7];
  if(hKeys.JumpToKey("Headshot", false))
  {
    hKeys.GetString("sound", buff, sizeof(buff), "");
    Format(fullPath, sizeof(fullPath), "sound/%s", buff);
    if(FileExists(fullPath, true, NULL_STRING))
      g_szKillEffectSound[Effect_Headshot] = buff;
    else
      g_szKillEffectSound[Effect_Headshot] = "";

    hKeys.GetString("particle",
      g_szKillEffectParticle[Effect_Headshot],
      sizeof(g_szKillEffectParticle[]),
      "");
    ++count;
    buff = "";
    hKeys.Rewind();
  }
  else
    ++skipCount;

  if(hKeys.JumpToKey("StealthBackstab", false))
  {
    hKeys.GetString("sound", buff, sizeof(buff), "");
    Format(fullPath, sizeof(fullPath), "sound/%s", buff);
    if(FileExists(fullPath, true, NULL_STRING))
      g_szKillEffectSound[Effect_Backstab] = buff;
    else
      g_szKillEffectSound[Effect_Backstab] = "";

    hKeys.GetString("particle",
      g_szKillEffectParticle[Effect_Backstab],
      sizeof(g_szKillEffectParticle[]),
      "");
    ++count;
    buff = "";
    hKeys.Rewind();
  }
  else
    ++skipCount;

  PrintToServer("%T", "SM_KILLEFFECTS_ConfigLoad", LANG_SERVER, count, skipCount);
  delete hKeys;
  return true;
}

stock void PrecacheKillSounds()
{
  for(int i = 0; i < view_as<int>(Effect_Max); ++i)
  {
    char fullPath[PLATFORM_MAX_PATH + 7];
    Format(fullPath, sizeof(fullPath), "sound/%s", g_szKillEffectSound[i]);

    // String is only not-empty if file exists (LoadConfig())
    if(!StrEqual(g_szKillEffectSound[i], "", true))
    {
      PrecacheSound(g_szKillEffectSound[i], true);
      AddFileToDownloadsTable(fullPath); // TODO Do built-in sounds cause issues here?
    }
  }
  return;
}

// Credit to TheUnderTaker on AlliedModders
stock void CreateKillEffect(int attacker, int victim, int effectIndex, int soundLevel)
{
  if(!StrEqual(g_szKillEffectParticle[effectIndex], "", true)
    && g_bKillEffectParticleMode)
  {
    CreateTempParticle(victim, effectIndex);
  }

  // If g_iKillEffectSoundMode is 0 the switch will do nothing.
  if(!StrEqual(g_szKillEffectSound[effectIndex], "", true))
    PlayKillEffectSound(attacker, victim, effectIndex, soundLevel);
  return;
}

stock void PlayKillEffectSound(int attacker, int victim, int effectIndex, int soundLevel)
{
  switch(g_iKillEffectSoundMode)
  {
    case 1:
    {
      EmitSoundToClient(
        attacker,
        g_szKillEffectSound[effectIndex],
        SOUND_FROM_PLAYER,
        SNDCHAN_AUTO,
        SNDLEVEL_NORMAL);
    }
    case 2:
    {
      EmitSoundToAll(
        g_szKillEffectSound[effectIndex],
        victim,
        SNDCHAN_AUTO,
        soundLevel); // Defaults are SNDLEVEL_SCREAMING for Headshot, DISHWASHER for backstab
    }
  }
  return;
}

stock void CreateTempParticle(int client, int effectIndex)
{
  int particle = CreateEntityByName("info_particle_system");

  if(IsValidEdict(particle))
  {
    float position[3];
    //GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
    GetClientEyePosition(client, position);
    TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

    char name[MAX_NAME_LENGTH];
    GetEntPropString(client, Prop_Data, "m_iName", name, sizeof(name));
    DispatchKeyValue(particle, "targetname", "tf2particle");
    DispatchKeyValue(particle, "parentname", name);
    DispatchKeyValue(particle, "effect_name", g_szKillEffectParticle[effectIndex]);
    DispatchSpawn(particle);

    SetVariantString(name);
    AcceptEntityInput(particle, "SetParent", particle, particle, 0);
    ActivateEntity(particle);
    AcceptEntityInput(particle, "start");

    CreateTimer(TEMP_PARTICLE_TIME, DeleteParticle, particle);
  }
  return;
}

public Action DeleteParticle(Handle timer, any particle)
{
  if(IsValidEdict(particle))
  {
    char classname[32];
    GetEntityClassname(particle, classname, sizeof(classname));
    if(StrEqual(classname, "info_particle_system", true))
      RemoveEdict(particle);
  }
  return Plugin_Stop;
}
#endif


/**
 * Check if weapon is stock medigun or reskin by its entity index
 */
stock bool IsStockMedigun(int entity)
{
  int itemIndex = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
  switch(itemIndex)
  {
    // Every Stock Medigun Skin as of 23/11/2017
    case 29, 211, 663, 796, 805, 885, 894, 903, 912, 961, 970, 15008, 15010, 15025, 15039, 15050, 15078, 15097, 15121, 15122, 15123, 15145, 15146:
      return true;
  }
  return false;
}

/**
 * Create the Medigun Shield for a given client and medigun entity index
 */
stock void StartMedigunShield(int client, int medigun, bool noDrain=false)
{
  SetEntPropFloat(client,   Prop_Send, "m_flRageMeter",   100.0); // Allow Shield Creation
  SetEntProp(client,        Prop_Send, "m_bRageDraining", 1);     // This is redundant ingame
  if(!noDrain)
    SetEntPropFloat(medigun,  Prop_Send, "m_flChargeLevel", 0.0); // Deplete Uber fully
  return;
}

/**
 * Descriptive wrapper for shield meter reset.
 */
stock void ResetShieldMeter(int client)
{
  SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 0.0);
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
