#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/toybox_update.txt"
#define PITCH_DEFAULT   100


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;

Handle  h_flResizeUpper = null;
float   g_flResizeUpper;
Handle  h_flResizeLower = null;
float   g_flResizeLower;

Handle  h_iFOVUpper = null;
int     g_iFOVUpper;
Handle  h_iFOVLower = null;
int     g_iFOVLower;
int     g_iFOVDesired[MAXPLAYERS + 1]; // Don't reset on disconnect, set OnClientPutInServer.

Handle  h_bScreamDefault = null; // Default state for g_bScreamEnabled
bool    g_bScreamEnabled;

Handle  h_bPitchDefault = null;  // Default state for g_bPitchEnabled
bool    g_bPitchEnabled;
Handle  h_iPitchUpper = null;
int     g_iPitchUpper;
Handle  h_iPitchLower = null;
int     g_iPitchLower;
int     g_iPitch[MAXPLAYERS + 1] = {PITCH_DEFAULT, ...}; // Value is a percentage, 100 default


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Toy Box",
  author =      "SirDigby",
  description = "What's a Fun Pack Without Toys?",
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
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases.txt");

  // Cvars
  h_bUpdate = FindConVar("sm_satansfunpack_update");
  if(h_bUpdate == null)
    SetFailState("%T", "SFP_UpdateCvarFail", LANG_SERVER);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);


  h_flResizeUpper = CreateConVar("sm_resizeweapon_upper", "3.0", "Upper Limits of Weapon Resize\n(Default: 3.0)", FCVAR_NONE);
  g_flResizeUpper = GetConVarFloat(h_flResizeUpper);
  HookConVarChange(h_flResizeUpper, UpdateCvars);

  h_flResizeLower = CreateConVar("sm_resizeweapon_lower", "-3.0", "Lower Limits of Weapon Resize\n(Default: -3.0)", FCVAR_NONE);
  g_flResizeLower = GetConVarFloat(h_flResizeLower);
  HookConVarChange(h_flResizeLower, UpdateCvars);


  h_iFOVUpper = CreateConVar("sm_fov_upper", "160", "Upper Limits of FOV\n(Default: 160)", FCVAR_NONE, true, 1.0, true, 179.0);
  g_iFOVUpper = GetConVarInt(h_iFOVUpper);
  HookConVarChange(h_iFOVUpper, UpdateCvars);

  h_iFOVLower = CreateConVar("sm_fov_lower", "30", "Lower Limits of FOV\n(Default: 30)", FCVAR_NONE, true, 1.0, true, 179.0);
  g_iFOVLower = GetConVarInt(h_iFOVLower);
  HookConVarChange(h_iFOVLower, UpdateCvars);


  h_bScreamDefault = CreateConVar("sm_scream_enable_default", "1", "Is sm_scream Enabled by Default (1/0)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bScreamEnabled = GetConVarBool(h_bScreamDefault);
  HookConVarChange(h_bScreamDefault, UpdateCvars);

  h_bPitchDefault = CreateConVar("sm_pitch_enable_default", "1", "Is sm_pitch Enabled by Default (1/0)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bPitchEnabled = GetConVarBool(h_bPitchDefault);
  HookConVarChange(h_bPitchDefault, UpdateCvars);

  h_iPitchUpper = CreateConVar("sm_pitch_upper", "200", "Upper Limits of Voice Pitch\n(Default: 200)", FCVAR_NONE, true, 1.0, true, 255.0);
  g_iPitchUpper = GetConVarInt(h_iPitchUpper);
  HookConVarChange(h_iPitchUpper, UpdateCvars);

  h_iPitchLower = CreateConVar("sm_pitch_lower", "50", "Lower Limits of Voice Pitch\n(Default: 50)", FCVAR_NONE, true, 1.0, true, 255.0);
  g_iPitchLower = GetConVarInt(h_iPitchLower);
  HookConVarChange(h_iPitchLower, UpdateCvars);



  RegAdminCmd("sm_colourweapon",    CMD_ColourWeapon, ADMFLAG_GENERIC, "Colour Your Weapons");
  RegAdminCmd("sm_colorweapon",     CMD_ColourWeapon, ADMFLAG_GENERIC, "Color Your Guns");
  RegAdminCmd("sm_cw",              CMD_ColourWeapon, ADMFLAG_GENERIC, "Colour Your Weapons");

  RegAdminCmd("sm_resizeweapon",    CMD_ResizeWeapon, ADMFLAG_GENERIC, "Resize Your Weapons");
  RegAdminCmd("sm_rw",              CMD_ResizeWeapon, ADMFLAG_GENERIC, "Resize Your Weapons");

  RegAdminCmd("sm_fov",             CMD_FieldOfView, ADMFLAG_GENERIC, "Set your Field of View");
  RegAdminCmd("sm_scream",          CMD_Scream, ADMFLAG_GENERIC, "Do it for the ice cream");
  RegAdminCmd("sm_screamtoggle",    CMD_ScreamToggle, ADMFLAG_GENERIC, "Toggle the sm_scream Command");
  RegAdminCmd("sm_pitch",           CMD_Pitch, ADMFLAG_GENERIC, "Make the Big Burly Men Sound Like Mice");
  RegAdminCmd("sm_pitchtoggle",     CMD_PitchToggle, ADMFLAG_GENERIC, "Toggle the sm_pitch Command");
  RegAdminCmd("sm_taunt",           CMD_TauntMenu, ADMFLAG_GENERIC, "Perform Any Taunt");
  RegAdminCmd("sm_taunts",          CMD_TauntMenu, ADMFLAG_GENERIC, "Perform Any Taunt");
  RegAdminCmd("sm_splay",           CMD_StealthPlay, ADMFLAG_GENERIC, "Play Sounds Stealthily");
  RegAdminCmd("sm_colour",          CMD_ColourPlayer, ADMFLAG_GENERIC, "Slap on Some Cheap Paint");
  RegAdminCmd("sm_color",           CMD_ColourPlayer, ADMFLAG_GENERIC, "Slap on Some Cheap, Patriotic Paint");
  RegAdminCmd("sm_friendlysentry",  CMD_FriendlySentry, ADMFLAG_GENERIC, "Load Your Sentry Full of Friendliness Pellets");
  RegAdminCmd("sm_lslap",           CMD_ListenSlap, ADMFLAG_GENERIC, "Navi's Sick of Your Crap");

  /**
   * Overrides
   * sm_colourweapon_target
   * sm_resizeweapon_target
   * sm_resizeweapon_nolimit
   * sm_fov_target
   * sm_fov_nolimit
   * sm_scream_target
   * sm_scream_nolock   - Player ignores sm_scream being disabled
   * sm_pitch_target
   * sm_pitch_nolock    - Player ignores sm_pitch being disabled
   * sm_pitch_nolimit
   * sm_colour_target
   * sm_friendlysentry_target
   */

  AddNormalSoundHook(view_as<NormalSHook>(Hook_NormalSound)); // Sourcemod, why?

  /*** Handle Late Loads ***/
  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; i++)
    {
      if(IsClientInGame(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        QueryClientConVar(i, "fov_desired", OnGetDesiredFOV);
    }
  }

  PrintToServer("%T", "SFP_ToyBoxLoaded", LANG_SERVER);
}


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_flResizeUpper)
    g_flResizeUpper = StringToFloat(newValue);
  else if(cvar == h_flResizeLower)
    g_flResizeLower = StringToFloat(newValue);
  else if(cvar == h_iFOVUpper)
    g_iFOVUpper = StringToInt(newValue);
  else if(cvar == h_iFOVLower)
    g_iFOVLower = StringToInt(newValue);
  else if(cvar == h_bScreamDefault)
    g_bScreamEnabled = GetConVarBool(h_bScreamDefault);
  else if(cvar == h_bPitchDefault)
    g_bPitchEnabled = GetConVarBool(h_bPitchDefault);
  else if(cvar == h_iPitchUpper)
    g_iPitchUpper = StringToInt(newValue);
  else if(cvar == h_iPitchLower)
    g_iPitchLower = StringToInt(newValue);
  return;
}


public void OnClientPutInServer(int client)
{
  if(!IsClientReplay(client) && !IsClientSourceTV(client))
  {
    QueryClientConVar(client, "fov_desired", OnGetDesiredFOV);
  }
  return;
}

public void OnClientDisconnect_Post(int client)
{
  // Do not put g_iFOVDesired here.
  g_iPitch[client] = PITCH_DEFAULT;
  return;
}


public Action Hook_NormalSound(
  int clients[MAXPLAYERS],
  int &numClients,
  char sample[PLATFORM_MAX_PATH],
  int &entity,
  int &channel,
  float &volume,
  int &level,
  int &pitch,
  int &flags)
{
  // entity = client
  if(channel == SNDCHAN_VOICE && entity >= 1 && entity <= MaxClients)
  {
    if(g_iPitch[entity] != PITCH_DEFAULT)
    {
      pitch = g_iPitch[entity];
      flags |= SND_CHANGEPITCH;
      return Plugin_Changed;
    }
  }
  return Plugin_Continue;
}



//=================================
// Commands

/**
 * Change the colour of a player's weapon
 *
 * sm_colourweapon [Target] <Slot 1/2/3/All> <Hex Colour/RGB Colour>
 * [Target] <Slot> <Hex> or [Target] <Slot> <R> <G> <B> (4 Arg Combos: 2,3,4 & 5)
 *
 * Slot must be mandatory or you can't easily distinguish these 3-arg commands:
 * [Target]+[Slot]+<Hex> vs <R>+<G>+<B>
 * TODO Add alpha support.
 */
public Action CMD_ColourWeapon(int client, int args)
{
  if(args < 2 && args > 5)
  {
    TagReplyUsage(client, "%T", "SM_COLWEAPON_Usage", client);
    return Plugin_Handled;
  }

  // Get first 2 required args
  char arg1[MAX_NAME_LENGTH], arg2[MAX_SLOTSTRING_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));


  // Get Target. Default to client.
  bool bSelfTarget = false;
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if(args == 3 || args == 5) // Either Hex or RGB, but with target specified
  {
    if(!CheckCommandAccess(client, "sm_colourweapon_target", ADMFLAG_BAN, true))
    {
      TagReply(client, "%T", "SFP_NoTargeting", client);
      return Plugin_Handled;
    }

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
  }
  else // No target, set to client.
  {
    if(!IsClientPlaying(client))
    {
      TagReplyUsage(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    targ_count = 1;
    targ_list[0] = client;
    GetClientName(client, targ_name, sizeof(targ_name));
    bSelfTarget = true;
  }


  // Get Slot
  TF_Slot_Index slotIndex = TF_Slot_Invalid;
  if(args == 2 || args == 4)
    slotIndex = GetWeaponSlotIndex(arg1);
  else if(args == 3 || args == 5)
    slotIndex = GetWeaponSlotIndex(arg2);
  if(slotIndex == TF_Slot_Invalid)
  {
    TagReplyUsage(client, "%T", "SFP_BadWeaponSlot", client);
    return Plugin_Handled;
  }


  // Get Colour. Check for Hex then RGB.
  int iRed, iGreen, iBlue;
  char arg3[7], arg4[4], arg5[4]; // Arg3 can be 6 or 3-digits, 4 and 5 can only be 3.

  if(args == 2)       // arg1:Slot, arg2:Hex
  {
    if(!HexToRGB(arg2, iRed, iGreen, iBlue))
    {
      TagReplyUsage(client, "%T", "SFP_BadHexColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 3)  // arg2:Slot, arg3:Hex
  {
    GetCmdArg(3, arg3, sizeof(arg3));

    if(!HexToRGB(arg3, iRed, iGreen, iBlue))
    {
      TagReplyUsage(client, "%T", "SFP_BadHexColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 4)  // arg1:Slot, arg2-4:RGB
  {
    GetCmdArg(3, arg3, sizeof(arg3));
    GetCmdArg(4, arg4, sizeof(arg4));

    iRed    = StringToInt(arg2);
    iGreen  = StringToInt(arg3);
    iBlue   = StringToInt(arg4);
    if(!IsColourRGB(iRed, iGreen, iBlue))
    {
      TagReplyUsage(client, "%T", "SFP_BadRGBColour", client);
      return Plugin_Handled;
    }
  }
  else if(args == 5)  // arg2:Slot, arg3-5:RGB
  {
    GetCmdArg(3, arg3, sizeof(arg3));
    GetCmdArg(4, arg4, sizeof(arg4));
    GetCmdArg(5, arg5, sizeof(arg5));

    iRed    = StringToInt(arg3);
    iGreen  = StringToInt(arg4);
    iBlue   = StringToInt(arg5);
    if(!IsColourRGB(iRed, iGreen, iBlue))
    {
      TagReplyUsage(client, "%T", "SFP_BadRGBColour", client);
      return Plugin_Handled;
    }
  }


  // Target, Colour and Slot ready. Apply.
  for(int i = 0; i < targ_count; ++i)
  {
    int weapon;
    switch(slotIndex)
    {
      case TF_Slot_AllWeapons:
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Primary));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Secondary));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Melee));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);
      }

      default: // Assuming index is only primary, secondary, melee or All.
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(slotIndex));
        if(weapon != -1)
          SetEntityRenderColor(weapon, iRed, iGreen, iBlue, 255);
      }
    }
  }

  if(bSelfTarget)
    TagReply(client, "%T", "SM_COLWEAPON_Done", client, iRed, iGreen, iBlue);
  else
    TagActivity(client, "%T", "SM_COLWEAPON_Done_Server", LANG_SERVER, targ_name, iRed, iGreen, iBlue);
  return Plugin_Handled;
}



/**
 * Resize a player's weapon
 *
 * sm_resizeweapon [Target] <Slot> <Scale>
 * Slot is required so self-targeting to change a specific slot isn't.
 */
public Action CMD_ResizeWeapon(int client, int args)
{
  if(args < 2)
  {
    TagReplyUsage(client, "%T", "SM_SIZEWEAPON_Usage", client);
    return Plugin_Handled;
  }

  // Get Required Args
  char arg1[MAX_NAME_LENGTH], arg2[8];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));


  // Get Scale
  float flScale;
  if(args == 2)
    flScale = StringToFloat(arg2);
  else
  {
    char arg3[8];
    GetCmdArg(3, arg3, sizeof(arg3));
    flScale = StringToFloat(arg3);
  }
  if((FloatCompare(flScale, g_flResizeLower) == -1
  || FloatCompare(flScale, g_flResizeUpper) == 1)
  && !CheckCommandAccess(client, "sm_resizeweapon_nolimit", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SM_SIZEWEAPON_Scale", client, g_flResizeLower, g_flResizeUpper);
    return Plugin_Handled;
  }


  // Get Slot
  TF_Slot_Index slotIndex = TF_Slot_Invalid;
  if(args == 2)
    slotIndex = GetWeaponSlotIndex(arg1);
  else // if(args == 3)
    slotIndex = GetWeaponSlotIndex(arg2);
  if(slotIndex == TF_Slot_Invalid)
  {
    TagReplyUsage(client, "%T", "SFP_BadWeaponSlot", client);
    return Plugin_Handled;
  }


  // Get Target. Default to client.
  bool bSelfTarget = false;
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;


  if(args == 2) // No target, set to client.
  {
    if(!IsClientPlaying(client)) // TODO: Does this need to be applied to targeted cmds?
    {
      TagReplyUsage(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    targ_count = 1;
    targ_list[0] = client;
    GetClientName(client, targ_name, sizeof(targ_name));
    bSelfTarget = true;
  }
  else // if args == 3
  {
    if(!CheckCommandAccess(client, "sm_resizeweapon_target", ADMFLAG_BAN, true))
    {
      TagReply(client, "%T", "SFP_NoTargeting", client);
      return Plugin_Handled;
    }

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
  }



  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    int weapon;
    switch(slotIndex)
    {
      case TF_Slot_AllWeapons:
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Primary));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Secondary));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);

        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(TF_Slot_Melee));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);
      }

      default: // Assuming index is only primary, secondary, melee or All.
      {
        weapon = GetPlayerWeaponSlot(targ_list[i], view_as<int>(slotIndex));
        if(weapon != -1)
          SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", flScale);
      }
    }
  }

  if(bSelfTarget)
    TagReply(client, "%T", "SM_SIZEWEAPON_Done", client, flScale);
  else
    TagActivity(client, "%T", "SM_SIZEWEAPON_Done_Server", LANG_SERVER, targ_name, flScale);
  return Plugin_Handled;
}



/**
 * Set a player's Field of View
 *
 * sm_fov [Target] <1 to 179 or Reset/Default>
 * Range is default 30-160
 */
public Action CMD_FieldOfView(int client, int args)
{
  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_FOV_Usage", client, g_iFOVLower, g_iFOVUpper);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  int val = 0;

  if(args == 1)
  {
    if(!IsClientPlaying(client, true)) // Allow Spectators to use on self.
    {
      TagReplyUsage(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(StrEqual(arg1, "reset", false) || StrEqual(arg1, "default", false))
    {
      SetFOV(client, 0, true);
      TagReply(client, "%T", "SM_FOV_Done_Default", client);
      return Plugin_Handled;
    }

    val = StringToInt(arg1);
    if((val < g_iFOVLower || val > g_iFOVUpper)
    && !CheckCommandAccess(client, "sm_fov_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_FOV_Usage", client, g_iFOVLower, g_iFOVUpper);
      return Plugin_Handled;
    }

    SetFOV(client, val, false);
    TagReply(client, "%T", "SM_FOV_Done", client, val);
    return Plugin_Handled;
  }


  // Get Target
  if(!CheckCommandAccess(client, "sm_fov_target", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SFP_NoTargeting", client);
    return Plugin_Handled;
  }

  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if ((targ_count = ProcessTargetString(
    arg1,
    client,
    targ_list,
    MAXPLAYERS,
    COMMAND_FILTER_NO_BOTS,
    targ_name,
    sizeof(targ_name),
    tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, targ_count);
    return Plugin_Handled;
  }

  // Get Value
  char arg2[16];
  bool isDefault = false;
  GetCmdArg(2, arg2, sizeof(arg2));

  if(StrEqual(arg2, "reset", false) || StrEqual(arg2, "default", false))
    isDefault = true;
  else
  {
    val = StringToInt(arg2);
    if((val < g_iFOVLower || val > g_iFOVUpper)
    && !CheckCommandAccess(client, "sm_fov_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_FOV_Usage", client, g_iFOVLower, g_iFOVUpper);
      return Plugin_Handled;
    }
  }

  // Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i], true)) // Allow Spectator, Not Replay/SourceTV
      SetFOV(targ_list[i], val, isDefault);
  }

  if(isDefault)
    TagActivity(client, "%T", "SM_FOV_Done_Server_Default", LANG_SERVER, targ_name);
  else
    TagActivity(client, "%T", "SM_FOV_Done_Server", LANG_SERVER, targ_name, val);
  return Plugin_Handled;
}

// TODO Is there a better way to do this?
void SetFOV(int iClient, int iVal, bool bDefault)
{
  if(bDefault)
  {
    // Safe to use value immediately, it's set OnClientPutInServer
    SetEntProp(iClient, Prop_Send, "m_iFOV", g_iFOVDesired[iClient]);
    SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", g_iFOVDesired[iClient]);
  }
  else
  {
    QueryClientConVar(iClient, "fov_desired", OnGetDesiredFOV);
    SetEntProp(iClient, Prop_Send, "m_iFOV", iVal);
    SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iVal);
    // TODO What is defaultfov for? Is it used when spawning?
  }
  return;
}

public void OnGetDesiredFOV(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
  g_iFOVDesired[client] = StringToInt(cvarValue);
  return;
}



/**
 * AAAAAAAAAAAAAAAAAAHH!
 *
 * sm_scream [Target]
 */
public Action CMD_Scream(int client, int args)
{
  if(!g_bScreamEnabled && !CheckCommandAccess(client, "sm_scream_nolock", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SM_SCREAM_Disabled", client);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    if(IsClientPlaying(client))
      PlayerScream(client);
    return Plugin_Handled;
  }

  //Get Target
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
      PlayerScream(targ_list[i]);
  }

  return Plugin_Handled;
}

void PlayerScream(int client)
{
  SetVariantString("HalloweenLongFall");
  AcceptEntityInput(client, "SpeakResponseConcept", -1, -1, 0);
}



/**
 * Toggle Server-wide Access to sm_scream.
 *
 * sm_screamtoggle [1/0]
 */
public Action CMD_ScreamToggle(int client, int args)
{
  if(args < 1)
    g_bScreamEnabled = !g_bScreamEnabled;
  else
  {
    char arg1[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_SCREAMTOGGLE_Usage", client);
      return Plugin_Handled;
    }
    g_bScreamEnabled = view_as<bool>(state);
  }

  if(g_bScreamEnabled)
    TagActivity(client, "%T", "SM_SCREAMTOGGLE_Enable", LANG_SERVER);
  else
    TagActivity(client, "%T", "SM_SCREAMTOGGLE_Disable", LANG_SERVER);

  return Plugin_Handled;
}



/**
 * Change the pitch of a player's voicelines
 *
 * sm_pitch [Target] <1-255 or 100/default/reset>
 */
public Action CMD_Pitch(int client, int args)
{
  if(!g_bPitchEnabled && !CheckCommandAccess(client, "sm_pitch_nolock", ADMFLAG_BAN, true))
  {
    TagReply(client, "%T", "SM_PITCH_Disabled", client);
    return Plugin_Handled;
  }

  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_PITCH_Usage", client, g_iPitchLower, g_iPitchUpper);
    return Plugin_Handled;
  }

  int val;
  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));
  
  if(args == 1)
  {
    if(!IsClientPlaying(client))
    {
      TagReplyUsage(client, "%T", "SFP_InGameOnly", client);
      return Plugin_Handled;
    }

    if(StrEqual(arg1, "reset", false)
    || StrEqual(arg1, "default", false)
    || StrEqual(arg1, "100", true))
    {
      g_iPitch[client] = PITCH_DEFAULT;
      TagReply(client, "%T", "SM_PITCH_Done_Default", client);
      return Plugin_Handled;
    }

    val = StringToInt(arg1);
    if((val < g_iPitchLower || val > g_iPitchUpper)
    && !CheckCommandAccess(client, "sm_pitch_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_PITCH_Usage", client, g_iPitchLower, g_iPitchUpper);
      return Plugin_Handled;
    }

    if(val < 1 || val > 255)
    {
      TagReply(client, "%T", "SM_PITCH_Limit", client);
      return Plugin_Handled;
    }

    g_iPitch[client] = val;
    TagReply(client, "%T", "SM_PITCH_Done", client, val);
    return Plugin_Handled;
  }

  // Get Value
  bool isDefault = false;
  char arg2[5];
  GetCmdArg(2, arg2, sizeof(arg2));

  if(StrEqual(arg2, "reset", false)
  || StrEqual(arg2, "default", false)
  || StrEqual(arg2, "100", true))
  {
    val = PITCH_DEFAULT;
    isDefault = true;
  }
  else
  {
    val = StringToInt(arg2);
    if((val < g_iPitchLower || val > g_iPitchUpper)
    && !CheckCommandAccess(client, "sm_pitch_nolimit", ADMFLAG_BAN, true))
    {
      TagReplyUsage(client, "%T", "SM_PITCH_Usage", client, g_iPitchLower, g_iPitchUpper);
      return Plugin_Handled;
    }

    if(val < 1 || val > 255)
    {
      TagReply(client, "%T", "SM_PITCH_Limit", client);
      return Plugin_Handled;
    }
  }


  // Get Target
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

  // Target and Val ready, Apply
  for(int i = 0; i < targ_count; ++i)
  {
    if(IsClientPlaying(targ_list[i]))
      g_iPitch[targ_list[i]] = val;
  }

  if(isDefault)
    TagActivity(client, "%T", "SM_PITCH_Done_Server", LANG_SERVER);
  else
    TagActivity(client, "%T", "SM_PITCH_Done_Server_Default", LANG_SERVER);

  return Plugin_Handled;
}



/**
 * Toggle Server-wide Access to sm_pitch
 *
 * sm_pitchtoggle [1/0]
 */
public Action CMD_PitchToggle(int client, int args)
{
  if(args < 1)
    g_bPitchEnabled = !g_bPitchEnabled;
  else
  {
    char arg1[MAX_BOOLSTRING_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    int state = GetStringBool(arg1, false, true, true, true);
    if(state == -1)
    {
      TagReplyUsage(client, "%T", "SM_PITCHTOGGLE_Usage", client);
      return Plugin_Handled;
    }
    g_bPitchEnabled = view_as<bool>(state);
  }

  if(g_bPitchEnabled)
    TagActivity(client, "%T", "SM_PITCHTOGGLE_Enable", LANG_SERVER);
  else
    TagActivity(client, "%T", "SM_PITCHTOGGLE_Disable", LANG_SERVER);

  return Plugin_Handled;
}



/**
 * Open a menu with a list of taunts, select to use.
 *
 * sm_taunt or sm_taunts
 */
public Action CMD_TauntMenu(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Play sounds identically to sm_play, but do not indicate to players.
 *
 * sm_splay <Target> <File Path>
 */
public Action CMD_StealthPlay(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Set a player's colour.
 *
 * sm_colour [Target] <Hex Colour>
 * OR sm_colour [Target] <Red 0-255> <Green 0-255> <Blue 0-255>
 * You can either have 1/2, or 3/4 args.
 * Both 1 & 3 self target.
 */
public Action CMD_ColourPlayer(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Set a player's sentry to deal no damage.
 * TODO Add godmode too?
 * TODO Add sentry build hook, store index.
 * TODO Add damage hook to players, check if source is sentry and owner has friendlysentry.
 * sm_friendlysentry [Target] <1/0>
 */
public Action CMD_FriendlySentry(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Slap a player and play Navi's "HEY, LISTEN"
 *
 * sm_lslap <Target>
 */
public Action CMD_ListenSlap(int client, int args)
{
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
