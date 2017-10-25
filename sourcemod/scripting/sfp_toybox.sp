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
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
Handle  h_flResizeUpper;
float   g_flResizeUpper;
Handle  h_flResizeLower;
float   g_flResizeLower;


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/toybox_update.txt"


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


  RegAdminCmd("sm_colourweapon",    CMD_ColourWeapon, ADMFLAG_GENERIC, "Colour Your Weapons");
  RegAdminCmd("sm_colorweapon",     CMD_ColourWeapon, ADMFLAG_GENERIC, "Color Your Guns");
  RegAdminCmd("sm_cw",              CMD_ColourWeapon, ADMFLAG_GENERIC, "Colour Your Weapons");

  RegAdminCmd("sm_resizeweapon",    CMD_ResizeWeapon, ADMFLAG_GENERIC, "Resize Your Weapons");
  RegAdminCmd("sm_rw",              CMD_ResizeWeapon, ADMFLAG_GENERIC, "Resize Your Weapons");

  RegAdminCmd("sm_fov",             CMD_Fov, ADMFLAG_GENERIC, "Set your Field of View");
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
   * sm_scream_target
   * sm_pitch_target
   * sm_colour_target
   * sm_friendlysentry_target
   */

  /*** Handle Late Loads ***/
  if(g_bLateLoad)
    PrintToServer("Lateload Warning temp fix.");

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
  return;
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
 * TODO Correct range. Use CVar.
 * sm_fov [Target] <0 to 180>
 */
public Action CMD_Fov(int client, int args)
{
  return Plugin_Handled;
}



/**
 * AAAAAAAAAAAAAAAAAAHH!
 *
 * sm_scream [Target]
 */
public Action CMD_Scream(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Toggle Server-wide Access to sm_scream.
 * TODO Use CVar to set default state.
 * sm_screamtogle <1/0>
 */
public Action CMD_ScreamToggle(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Change the pitch of a player's voicelines
 * TODO Use cvar to set range.
 * sm_pitch [Target] <1-255 or 0/default/off/reset>
 */
public Action CMD_Pitch(int client, int args)
{
  return Plugin_Handled;
}



/**
 * Toggle Server-wide Access to sm_pitch
 * TODO Use CVar to set default state.
 * sm_pitchtoggle <1/0>
 */
public Action CMD_PitchToggle(int client, int args)
{
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
