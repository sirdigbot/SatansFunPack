#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <ccc>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/namecolour_update.txt"

#define MAX_TAG_LENGTH  17    // 16 + \0
#define MAX_COLOURS     1024  // Arbitrary safe cap on stringmap
#define MAX_COLOUR_NAME 32
#define IDX_SIZE        6
#define NAME_PREFIX     'N'   // Arbitrary single character
#define TAG_PREFIX      'T'   // Arbitrary single character

//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
bool    g_bLateLoad;
Handle  h_szColourCfg = null;
char    g_szColourCfg[PLATFORM_MAX_PATH];

Handle h_ckNameColour = null;
Handle h_ckTagColour  = null;
Handle h_ckTagText    = null;

StringMap g_iColours;
StringMap g_szColourNames;
int       g_iColourCount;

bool      g_bWaitingForCustomTag[MAXPLAYERS + 1];
Handle    h_ConnectTimers[MAXPLAYERS + 1] = {null, ...};

/**
 * Known Bugs
 * TODO Team-tinted chat text option (cvar)
 * TODO Random colour option
 * TODO Admin-only tag border styles
 * TODO Add translation to main menu items
 * TODO CVar controlled tag size limit
 * TODO Add 'test colours' option to main menu
 */
public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Name Colour",
  author =      "SirDigby",
  description = "Making Text Chat Fabulous Since 2017",
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
  LoadTranslations("sfp.namecolour.phrases");

  h_bUpdate = CreateConVar("sm_sfp_namecolour_update", "1", "Update Satan's Fun Pack - Name Colour Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_szColourCfg = CreateConVar("sm_satansfunpack_colourconfig", "satansfunpack_colours.cfg", "Config File used for List of Colours (Relative to Sourcemod/Configs)\n(Default: satansfunpack_colours.cfg)", FCVAR_SPONLY);

  char buff[PLATFORM_MAX_PATH], formatBuff[PLATFORM_MAX_PATH+13];
  GetConVarString(h_szColourCfg, buff, sizeof(buff));
  Format(formatBuff, sizeof(formatBuff), "configs/%s", buff);
  BuildPath(Path_SM, g_szColourCfg, sizeof(g_szColourCfg), formatBuff);
  HookConVarChange(h_szColourCfg, UpdateCvars);


  RegAdminCmd("sm_namecolour",  CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Colour, and Name Colour");
  RegAdminCmd("sm_namecolor",   CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Color, and Name Color");

  RegAdminCmd("sm_tagcolour",  CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Colour, and Name Colour");
  RegAdminCmd("sm_tagcolor",   CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Color, and Name Color");

  RegAdminCmd("sm_setnamecolour", CMD_SetNameColour,  ADMFLAG_GENERIC, "Set Name Colour Directly");
  RegAdminCmd("sm_setnamecolor",  CMD_SetNameColour,  ADMFLAG_GENERIC, "Set Name Color Directly");
  RegAdminCmd("sm_settagcolour",  CMD_SetTagColour,   ADMFLAG_GENERIC, "Set Tag Colour Directly");
  RegAdminCmd("sm_settagcolor",   CMD_SetTagColour,   ADMFLAG_GENERIC, "Set Tag Color Directly");
  RegAdminCmd("sm_settag",        CMD_SetTag,         ADMFLAG_GENERIC, "Set Tag Text Directly");


  RegAdminCmd("sm_namecolour_reloadcfg", CMD_ReloadCfg, ADMFLAG_ROOT, "Reload Name Colour Config");

  g_iColours      = new StringMap();
  g_szColourNames = new StringMap();
  LoadConfig();


  h_ckNameColour = RegClientCookie(
    "satansfunpack_namecolour",
    "Name Colour (6-Digit Hex Code in Base 10)",
    CookieAccess_Protected);

  h_ckTagColour = RegClientCookie(
    "satansfunpack_tagcolour",
    "Tag Colour (6-Digit Hex Code in Base 10)",
    CookieAccess_Protected);

  h_ckTagText = RegClientCookie(
    "satansfunpack_tagtext",
    "Tag Text",
    CookieAccess_Protected);

  if(g_bLateLoad)
  {
    for(int i = 1; i <= MaxClients; ++i)
    {
      if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
      {
        if(AreClientCookiesCached(i))
          LoadClientCookies(i);
      }
    }
  }

  /**
   * Overrides
   * Commands determine their equivalent menu access.
   * sm_resetcolour_access  - Can reset their own colours and tag
   */
  PrintToServer("%T", "SFP_NameColourLoaded", LANG_SERVER);
}



public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_szColourCfg)
  {
    char formatBuff[PLATFORM_MAX_PATH+13];
    Format(formatBuff, sizeof(formatBuff), "configs/%s", newValue);
    BuildPath(Path_SM, g_szColourCfg, sizeof(g_szColourCfg), formatBuff);
    LoadConfig();
  }
  return;
}


public void OnClientPostAdminCheck(int client)
{
  if(client < 1 || client > MaxClients || IsFakeClient(client))
    return;

  if(IsClientInGame(client) && AreClientCookiesCached(client))
    LoadClientCookies(client);
  else
    h_ConnectTimers[client] = CreateTimer(30.0, Timer_DelayLoad, client); // 30 is arbitrary
  return;
}

public Action Timer_DelayLoad(Handle timer, any client)
{
  if(IsClientInGame(client) && AreClientCookiesCached(client))
  {
    LoadClientCookies(client);
    TagPrintChat(client, "%T", "SM_NAMECOLOUR_DelayLoad", client);
  }
  else
  {
    char authID[64];
    GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID), true);
    LogError("%T", "SM_NAMECOLOUR_CookieFail", LANG_SERVER, authID);
  }
  h_ConnectTimers[client] = null;
  return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
  g_bWaitingForCustomTag[client] = false;
  SafeClearTimer(h_ConnectTimers[client]);
  return;
}

public Action OnRoundEnd(Handle event, char[] name, bool dontBroadcast)
{
  for(int i = 1; i <= MaxClients; ++i)
    SafeClearTimer(h_ConnectTimers[i]);
  return Plugin_Continue;
}


public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
  if(g_bWaitingForCustomTag[client])
  {
    g_bWaitingForCustomTag[client] = false;
    char buff[MAX_TAG_LENGTH]; // Enforce max
    strcopy(buff, sizeof(buff), sArgs);
    SetPlayerTag(client, buff);
    TagPrintChat(client, "%T", "SM_SETTAG_Done", client, buff);
    return Plugin_Stop;
  }
  return Plugin_Continue;
}




/**
 * Show a list of options to customise name colour, tag colour and tag text
 *
 * sm_namecolour
 * The command is a little ambiguously named, but most people will want the name colour
 * itself so it makes sense.
 */
public Action CMD_ColourMenu(int client, int args)
{
  if(!IsClientPlaying(client, true))
  {
    TagReply(client, "%T", "SFP_InGameOnly", client);
    return Plugin_Handled;
  }

  OpenMainMenu(client);
  return Plugin_Handled;
}

void OpenMainMenu(int client)
{
  Menu menu = new Menu(MainMenuHandler,
    MenuAction_End|MenuAction_Display|MenuAction_DrawItem|MenuAction_Select);
  SetMenuTitle(menu, "Menu"); // Translated in handler

  AddMenuItem(menu, "0", "Name Colour");
  AddMenuItem(menu, "1", "Tag Colour");
  AddMenuItem(menu, "2", "Set Tag Text");
  AddMenuItem(menu, "3", "Reset All to Default");

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int MainMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_End:
    {
      delete menu;
    }

    case MenuAction_Display:
    {
      // Client Translation: p1 = client, p2 = menu
      char buffer[64];
      Format(buffer, sizeof(buffer), "%T", "SM_MAINMENU_Title", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }

    case MenuAction_DrawItem:
    {
      // Disable Inaccessible Options: p1 = client, p2 = menuitem
      int style;
      char info[4];
      GetMenuItem(menu, param2, info, sizeof(info), style);

      if(StrEqual(info, "0", true) &&
        !CheckCommandAccess(param1, "sm_setnamecolour", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }
      else if(StrEqual(info, "1", true) &&
        !CheckCommandAccess(param1, "sm_settagcolour", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }
      else if(StrEqual(info, "2", true) &&
        !CheckCommandAccess(param1, "sm_settag", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }
      else if(StrEqual(info, "3", true) &&
        !CheckCommandAccess(param1, "sm_resetcolour_access", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[4];
      GetMenuItem(menu, param2, info, sizeof(info));

      if(StrEqual(info, "0", true))
        OpenColourMenu(param1, true);
      else if(StrEqual(info, "1", true))
        OpenColourMenu(param1, false);
      else if(StrEqual(info, "2", true))
      {
        g_bWaitingForCustomTag[param1] = true;
        TagPrintChat(param1, "%T", "SM_NAMECOLOUR_TagRequest", param1);
      }
      else if(StrEqual(info, "3", true))
      {
        SetPlayerNameColour(param1, -1); // -1 = reset
        SetPlayerTagColour(param1, -1);
        SetPlayerTag(param1, "", true); // true = reset;
        TagPrintChat(param1, "%T", "SM_NAMECOLOUR_ResetAll", param1);
        OpenMainMenu(param1);
      }
    }
  }
  return 0;
}



/**
 * Set custom name colour directly
 *
 * sm_setnamecolour <6-Digit Hex Colour>
 */
public Action CMD_SetNameColour(int client, int args)
{
  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_SETNAMECOLOUR_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  if(!IsValid6DigitHex(arg1))
  {
    TagReply(client, "%T", "SFP_BadHexColour", client);
    return Plugin_Handled;
  }

  int hexVal = StringToInt(arg1, 16);
  SetPlayerNameColour(client, hexVal);
  TagReply(client, "%T", "SM_SETNAMECOLOUR_Done", client);
  return Plugin_Handled;
}



/**
 * Set custom tag colour directly
 *
 * sm_settagcolour <6-Digit Hex Colour>
 */
public Action CMD_SetTagColour(int client, int args)
{
  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_SETTAGCOLOUR_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  if(!IsValid6DigitHex(arg1))
  {
    TagReply(client, "%T", "SFP_BadHexColour", client);
    return Plugin_Handled;
  }

  int hexVal = StringToInt(arg1, 16);
  SetPlayerTagColour(client, hexVal);
  TagReply(client, "%T", "SM_SETTAGCOLOUR_Done", client);
  return Plugin_Handled;
}



/**
 * Set custom tag directly
 *
 * sm_settag <Text>
 */
public Action CMD_SetTag(int client, int args)
{
  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_SETTAG_Usage", client);
    return Plugin_Handled;
  }

  char argString[MAX_TAG_LENGTH];
  GetCmdArgString(argString, sizeof(argString));

  SetPlayerTag(client, argString);
  TagReply(client, "%T", "SM_SETTAG_Done", client, argString);
  return Plugin_Handled;
}



/**
 * Colour Submenu
 */
void OpenColourMenu(int client, bool IsNameColour)
{
  Menu menu = new Menu(ColourHandler,
    MenuAction_End|MenuAction_Cancel|MenuAction_Display|MenuAction_Select);
  SetMenuTitle(menu, "Colour");
  SetMenuExitBackButton(menu, true);

  char reset[32];
  Format(reset, sizeof(reset), "%T", "SM_COLOURMENU_Reset", client);

  if(IsNameColour)
    AddMenuItem(menu, "RN", reset); // "RN" must be shorter than IDX_SIZE
  else
    AddMenuItem(menu, "RT", reset);

  for(int i = 0; i < g_iColourCount; ++i)
  {
    char idx[IDX_SIZE+1]; // + 1 for prefix
    IntToString(i, idx, sizeof(idx));

    char buff[MAX_COLOUR_NAME];
    g_szColourNames.GetString(idx, buff, sizeof(buff));

    Format(idx, sizeof(idx), "%s%i", (IsNameColour) ? NAME_PREFIX : TAG_PREFIX, i);
    AddMenuItem(menu, idx, buff);
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int ColourHandler(Handle menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_End:
    {
      delete menu;
    }

    case MenuAction_Cancel:
    {
      if(param2 == MenuCancel_ExitBack)
        OpenMainMenu(param1);
    }

    case MenuAction_Display:
    {
      // Client Translation: p1 = client, p2 = menu
      char buffer[64];
      Format(buffer, sizeof(buffer), "%T", "SM_COLOURMENU_Title", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[IDX_SIZE+1];
      GetMenuItem(menu, param2, info, sizeof(info));

      // Check if Reset
      if(StrEqual(info, "RN", true))
      {
        SetPlayerNameColour(param1, -1); // -1 = reset
        TagPrintChat(param1, "%T", "SM_SETNAMECOLOUR_Reset", param1);
        OpenMainMenu(param1);
        return 0;
      }
      else if(StrEqual(info, "RT", true))
      {
        SetPlayerTagColour(param1, -1);
        TagPrintChat(param1, "%T", "SM_SETTAGCOLOUR_Reset", param1);
        OpenMainMenu(param1);
        return 0;
      }

      // Not reset, get StringMap index
      bool IsNameColour = (info[0] == NAME_PREFIX) ? true : false;
      char mapIdx[IDX_SIZE];
      strcopy(mapIdx, sizeof(mapIdx), info[1]); // Remove single char prefix

      int hexColour;
      g_iColours.GetValue(mapIdx, hexColour);

      if(IsNameColour)
      {
        SetPlayerNameColour(param1, hexColour);
        TagPrintChat(param1, "%T", "SM_SETNAMECOLOUR_Done", param1);
        OpenMainMenu(param1);
      }
      else
      {
        SetPlayerTagColour(param1, hexColour);
        TagPrintChat(param1, "%T", "SM_SETTAGCOLOUR_Done", param1);
        OpenMainMenu(param1);
      }
    }
  }
  return 0;
}



/**
 * Reload the colour config file
 *
 * sm_namecolour_reloadcfg
 */
public Action CMD_ReloadCfg(int client, int args)
{
  LoadConfig();
  TagReply(client, "%T", "SFP_ConfigReload_Success", client);
  return Plugin_Handled;
}

stock bool LoadConfig()
{
  if(!FileExists(g_szColourCfg))
  {
    SetFailState("%T", "SFP_NoConfig", LANG_SERVER, g_szColourCfg);
    return false;
  }

  // Create and Check KeyValues
  KeyValues hKeys = CreateKeyValues("SatansFunColours");
  if(!FileToKeyValues(hKeys, g_szColourCfg))
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfig", LANG_SERVER, g_szColourCfg);
    return false;
  }

  if(!hKeys.GotoFirstSubKey())
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfigSubKey", LANG_SERVER, g_szColourCfg);
    return false;
  }

  // Zero Out
  g_iColours.Clear();
  g_szColourNames.Clear();
  g_iColourCount = 0;

  int skipCount = 0;
  do
  {
    char nameBuff[MAX_COLOUR_NAME], hexBuff[7];
    hKeys.GetString("name", nameBuff, sizeof(nameBuff));
    if(StrEqual(nameBuff, "", true))
    {
      ++skipCount;
      continue;
    }

    hKeys.GetString("hex", hexBuff, sizeof(hexBuff));
    if(!IsValid6DigitHex(hexBuff))
    {
      ++skipCount;
      continue;
    }

    char idx[IDX_SIZE];
    IntToString(g_iColourCount, idx, sizeof(idx));
    g_iColours.SetValue(idx, StringToInt(hexBuff, 16));
    g_szColourNames.SetString(idx, nameBuff);
    ++g_iColourCount;
  }
  while(hKeys.GotoNextKey() && g_iColourCount < MAX_COLOURS);

  PrintToServer("%T", "SM_NAMECOLOUR_ConfigLoad", LANG_SERVER, g_iColourCount, skipCount);
  delete hKeys;
  return true;
}


/**
 * Set a player's CCC Tag and cookie
 */
stock void SetPlayerTag(int client, const char[] tag, bool reset=false)
{
  char buff[MAX_TAG_LENGTH+3] = ""; // Adding "[", "]" and " "

  if(reset)
    CCC_ResetTag(client);
  else
  {
    Format(buff, sizeof(buff), "[%s] ", tag);
    CCC_SetTag(client, buff);
  }

  if(AreClientCookiesCached(client))
    SetClientCookie(client, h_ckTagText, buff);
  return;
}

/**
 * Set a player's CCC Tag Colour and cookie
 * Pass -1 as colour to reset.
 */
stock void SetPlayerTagColour(int client, int colour)
{
  if(colour > 0)
    CCC_SetColor(client, CCC_TagColor, colour, false);
  else
    CCC_ResetColor(client, CCC_TagColor);

  if(AreClientCookiesCached(client))
  {
    char buff[16];
    IntToString(colour, buff, sizeof(buff));
    SetClientCookie(client, h_ckTagColour, buff);
  }
  return;
}


/**
 * Set a player's CCC Name Colour and cookie
 * Pass -1 as colour to reset.
 */
stock void SetPlayerNameColour(int client, int colour)
{
  if(colour > 0)
    CCC_SetColor(client, CCC_NameColor, colour, false);
  else
    CCC_ResetColor(client, CCC_NameColor);

  if(AreClientCookiesCached(client))
  {
    char buff[16];
    IntToString(colour, buff, sizeof(buff));
    SetClientCookie(client, h_ckNameColour, buff);
  }
  return;
}

/**
 * Read a client's cookies and set their CCC Values directly
 */
stock void LoadClientCookies(int client)
{
  char buff[MAX_TAG_LENGTH+3]; // Account for "[", "]" and " "
  GetClientCookie(client, h_ckNameColour, buff, sizeof(buff));
  if(!StrEqual(buff, "", true))
    CCC_SetColor(client, CCC_NameColor, StringToInt(buff), false);

  GetClientCookie(client, h_ckTagColour, buff, sizeof(buff));
  if(!StrEqual(buff, "", true))
    CCC_SetColor(client, CCC_TagColor, StringToInt(buff), false);

  GetClientCookie(client, h_ckTagText, buff, sizeof(buff));
  if(!StrEqual(buff, "", true))
    CCC_SetTag(client, buff); // Don't use SetPlayerTag, Cookies store "[", "]" and " "
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