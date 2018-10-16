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
#include <ccc>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>
#include <sfh_chatlib>


//=================================
// Constants
#define PLUGIN_VERSION  "1.2.0"
#define PLUGIN_URL      "https://sirdigbot.github.io/SatansFunPack/"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/namecolour_update.txt"

#define MAX_TAG_TEXT_LENGTH  17                 // Maximum length of tag text. (16 + \0)
#define MAX_TAG_LENGTH  MAX_TAG_TEXT_LENGTH + 3 // Maximum length of tag text + formatting (MAX_TAG_TEXT_LENGTH + '[' + ']' + ' ')
#define MAX_COLOURS     1024                    // Arbitrary safety cap on stringmap
#define MAX_COLOUR_NAME 32                      // Max Length of colour name
#define IDX_SIZE        6                 
#define RETRY_TIMER     30.0                    // Arbitrary time to retry loading colours on connect

// Arbitrary unique chars/prefixes for sub-menu handling (Must be manually synced in Colour Menu)
#define NAME_PREFIX       'N'   
#define CHAT_PREFIX       'C'
#define TAG_PREFIX        'T'
#define BORDER_PREFIX     'B'
#define NAME_RESET_STRING "RN"          // Length MUST be smaller than IDX_SIZE to buffer in Colour Handler.
#define CHAT_RESET_STRING "RC"
#define TAG_RESET_STRING  "RT"

// Main Menu Item Numbers
#define MAINMENUITEM_NAMECOLOUR         "0"
#define MAINMENUITEM_CHATCOLOUR         "1"
#define MAINMENUITEM_TAGCOLOUR          "2"
#define MAINMENUITEM_SETTAGTEXT         "3"
#define MAINMENUITEM_TOGGLEADMINBORDER  "4"
#define MAINMENUITEM_RESETTAGTEXT       "5"
#define MAINMENUITEM_RESETALL           "6"

#define MAINMENUITEM_SIZE               2   // Max sizeof() MAINMENUITEM_* Strings

#define TAGBORDER_CHARS 10    // 8 characters + space + \0.
#define TAGBORDERSIDE_CHARS 5  // Half of non-space characters in TAGBORDER_CHARS + \0


//=================================
// Global
ConVar  h_bUpdate;
bool    g_bLateLoad;
ConVar  h_szColourCfg;
char    g_szColourCfg[PLATFORM_MAX_PATH];
ConVar  h_szTagBorderDefault;
char    g_szTagBorderDefault[TAGBORDER_CHARS];
ConVar  h_szTagBorderAdmin;
char    g_szTagBorderAdmin[TAGBORDER_CHARS];
ConVar  h_szTagBorderMod;
char    g_szTagBorderMod[TAGBORDER_CHARS];

Handle h_ckNameColour   = null; // Base-10 Integer of 6-digit Hex Colour
Handle h_ckChatColour   = null;
Handle h_ckTagColour    = null;
Handle h_ckTagText      = null; // String of the inner text of the tag
Handle h_ckTagBorder    = null; // Strings of the border characters (separated by space)


ArrayList g_iColours;
ArrayList g_szColourNames;

bool      g_bWaitingForCustomTag[MAXPLAYERS + 1];
Handle    h_ConnectTimers[MAXPLAYERS + 1] = {null, ...}; // Retry failed colour loading on connect

/**
 * Known Bugs & Notes
 * TODO Team-tinted chat text option (cvar)
 * TODO Random colour option
 * TODO CVar controlled tag size limit
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
    Format(err, err_max, "Satan's Fun Pack is only compatible with Team Fortress 2.");
    return APLRes_Failure;
  }
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  LoadTranslations("sfp.namecolour.phrases");

  h_bUpdate = CreateConVar("sm_sfp_namecolour_update", "1", "Update Satan's Fun Pack - Name Colour Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  h_bUpdate.AddChangeHook(OnCvarChanged);

  h_szColourCfg = CreateConVar("sm_satansfunpack_colourconfig", "satansfunpack_colours.cfg", "Config File used for List of Colours (Relative to Sourcemod/Configs)\n(Default: satansfunpack_colours.cfg)", FCVAR_SPONLY);

  char buff[PLATFORM_MAX_PATH], formatBuff[PLATFORM_MAX_PATH+13];
  h_szColourCfg.GetString(buff, sizeof(buff));
  Format(formatBuff, sizeof(formatBuff), "configs/%s", buff);
  BuildPath(Path_SM, g_szColourCfg, sizeof(g_szColourCfg), formatBuff);
  h_szColourCfg.AddChangeHook(OnCvarChanged);
  
  
  h_szTagBorderDefault = CreateConVar("sm_sfp_namecolour_defaultborder", "[ ]", "Default Characters used on either side of a Player's Tag text\nString must be separated by space.\nMax Bytes/Characters 9 (Incl. Space)\n(Default: \"[ ]\")", FCVAR_SPONLY);
  h_szTagBorderDefault.GetString(g_szTagBorderDefault, sizeof(g_szTagBorderDefault));
  h_szTagBorderDefault.AddChangeHook(OnCvarChanged);
  
  h_szTagBorderAdmin = CreateConVar("sm_sfp_namecolour_adminborder", "< >", "Characters used on either side of an Admin's Tag text (sm_tagborder_admin)\nString must be separated by space.\nMax Bytes/Characters 9 (Incl. Space)\n(Default: \"< >\")", FCVAR_SPONLY);
  h_szTagBorderAdmin.GetString(g_szTagBorderAdmin, sizeof(g_szTagBorderAdmin));
  h_szTagBorderAdmin.AddChangeHook(OnCvarChanged);
  
  h_szTagBorderMod = CreateConVar("sm_sfp_namecolour_modborder", "( )", "Characters used on either side of a Moderators's Tag text (sm_tagborder_mod)\nString must be separated by space.\nMax Bytes/Characters 9 (Incl. Space)\n(Default: \"< >\")", FCVAR_SPONLY);
  h_szTagBorderMod.GetString(g_szTagBorderMod, sizeof(g_szTagBorderMod));
  h_szTagBorderMod.AddChangeHook(OnCvarChanged);


  RegAdminCmd("sm_namecolour",  CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Colour, and Name Colour");
  RegAdminCmd("sm_namecolor",   CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Color, and Name Color");

  RegAdminCmd("sm_tagcolour",  CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Colour, and Name Colour");
  RegAdminCmd("sm_tagcolor",   CMD_ColourMenu, ADMFLAG_GENERIC, "Set Tag, Tag Color, and Name Color");

  // Direct Setter Commands. Only the "colour" versions are checked for override access.
  RegAdminCmd("sm_setnamecolour", CMD_SetNameColour,  ADMFLAG_GENERIC, "Set Name Colour Directly");
  RegAdminCmd("sm_setnamecolor",  CMD_SetNameColour,  ADMFLAG_GENERIC, "Set Name Color Directly");
  RegAdminCmd("sm_setchatcolour", CMD_SetChatColour,  ADMFLAG_GENERIC, "Set Chat Colour Directly");
  RegAdminCmd("sm_setchatcolor",  CMD_SetChatColour,  ADMFLAG_GENERIC, "Set Chat Color Directly");
  RegAdminCmd("sm_settagcolour",  CMD_SetTagColour,   ADMFLAG_GENERIC, "Set Tag Colour Directly");
  RegAdminCmd("sm_settagcolor",   CMD_SetTagColour,   ADMFLAG_GENERIC, "Set Tag Color Directly");
  RegAdminCmd("sm_settag",        CMD_SetTag,         ADMFLAG_GENERIC, "Set Tag Text Directly");
  
  RegAdminCmd("sm_settagborder",  CMD_SetTagBorder,     ADMFLAG_BAN, "Set a Player's Tag Border");
  RegAdminCmd("sm_resettagborder",  CMD_ResetTagBorder, ADMFLAG_BAN, "Reset a Player's Tag Border");
  RegAdminCmd("sm_namecolour_reloadcfg", CMD_ReloadCfg, ADMFLAG_ROOT, "Reload Name Colour Config");

  g_iColours      = new ArrayList();
  g_szColourNames = new ArrayList(ByteCountToCells(MAX_COLOUR_NAME));
  LoadConfig();


  h_ckNameColour = RegClientCookie(
    "satansfunpack_namecolour",
    "Name Colour (6-Digit Hex Code in Base 10)",
    CookieAccess_Protected);

  h_ckChatColour = RegClientCookie(
    "satansfunpack_chatcolour",
    "Chat Colour (6-Digit Hex Code in Base 10)",
    CookieAccess_Protected);

  h_ckTagColour = RegClientCookie(
    "satansfunpack_tagcolour",
    "Tag Colour (6-Digit Hex Code in Base 10)",
    CookieAccess_Protected);

  h_ckTagBorder = RegClientCookie(
    "satansfunpack_tagborder",
    "Tag Side Border Strings (separated by space)",
    CookieAccess_Protected);
    
  h_ckTagText = RegClientCookie(
    "satansfunpack_tagtext",
    "Tag Inner Text",
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
   * sm_tagborder_admin     - Client can use 'Admin' tag border (will prevent from using 'Mod' border)
   * sm_tagborder_mod       - Client can use 'Moderator' tag border
   */
  PrintToServer("%T", "SFP_NameColourLoaded", LANG_SERVER);
}


public void OnPluginEnd()
{
  // Free data (might be unnecessary)
  delete g_iColours;
  delete g_szColourNames;
}



public void OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
    (h_bUpdate.BoolValue) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
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
    h_ConnectTimers[client] = CreateTimer(RETRY_TIMER, Timer_DelayLoad, client);
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
  delete h_ConnectTimers[client];
  return;
}

public Action OnRoundEnd(Handle event, char[] name, bool dontBroadcast)
{
  for(int i = 1; i <= MaxClients; ++i)
    delete h_ConnectTimers[i];
  return Plugin_Continue;
}

/**
 * Handle Custom Tag entry in chat
 **/
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
  if(g_bWaitingForCustomTag[client])
  {
    g_bWaitingForCustomTag[client] = false;
    char buff[MAX_TAG_TEXT_LENGTH]; // Enforce max
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

void OpenMainMenu(const int client)
{
  Menu menu = new Menu(MainMenuHandler,
    MenuAction_End|MenuAction_Display|MenuAction_DisplayItem|MenuAction_DrawItem|MenuAction_Select);
  SetMenuTitle(menu, "Menu"); // Translated in handler

  AddMenuItem(menu, MAINMENUITEM_NAMECOLOUR, "Name Colour");
  AddMenuItem(menu, MAINMENUITEM_CHATCOLOUR, "Chat Colour");
  AddMenuItem(menu, MAINMENUITEM_TAGCOLOUR, "Tag Colour");
  AddMenuItem(menu, MAINMENUITEM_SETTAGTEXT, "Set Tag Text");
  
  // To toggle between default and admin border
  AddMenuItem(menu, MAINMENUITEM_TOGGLEADMINBORDER, "Toggle Admin Border");
  
  AddMenuItem(menu, MAINMENUITEM_RESETTAGTEXT, "Reset Tag Text");
  AddMenuItem(menu, MAINMENUITEM_RESETALL, "Reset All to Default");

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
      // Client Translation: p1 = client, p2 = menu handle int
      char buffer[64];
      Format(buffer, sizeof(buffer), "%T", "SM_MAINMENU_Title", param1);

      SetPanelTitle(view_as<Handle>(param2), buffer);
    }
    
    case MenuAction_DisplayItem:
    {
      int style;
      char info[MAINMENUITEM_SIZE];
      GetMenuItem(menu, param2, info, sizeof(info), style);

      char display[64];

      if(StrEqual(info, MAINMENUITEM_NAMECOLOUR, true))
        Format(display, sizeof(display), "%T", "SM_MAINMENU_NameColour", param1); 
      else if(StrEqual(info, MAINMENUITEM_CHATCOLOUR, true))
        Format(display, sizeof(display), "%T", "SM_MAINMENU_ChatColour", param1);
      else if(StrEqual(info, MAINMENUITEM_TAGCOLOUR, true))
        Format(display, sizeof(display), "%T", "SM_MAINMENU_TagColour", param1);
      else if(StrEqual(info, MAINMENUITEM_TOGGLEADMINBORDER, true))
      {
        // Only mods should see the mod text
        if(CheckCommandAccess(param1, "sm_tagborder_mod", ADMFLAG_GENERIC, false)
         && !CheckCommandAccess(param1, "sm_tagborder_admin", ADMFLAG_GENERIC, false))
        {
          Format(display, sizeof(display), "%T", "SM_MAINMENU_TagBorder_Mod", param1);
        }
        else
          Format(display, sizeof(display), "%T", "SM_MAINMENU_TagBorder_Admin", param1);
      }
      else if(StrEqual(info, MAINMENUITEM_SETTAGTEXT, true))
        Format(display, sizeof(display), "%T", "SM_MAINMENU_TagText", param1);
      else if(StrEqual(info, MAINMENUITEM_RESETTAGTEXT, true))
        Format(display, sizeof(display), "%T", "SM_MAINMENU_ResetTagText", param1);
      else if(StrEqual(info, MAINMENUITEM_RESETALL, true))
        Format(display, sizeof(display), "%T", "SM_MAINMENU_ResetAll", param1);
          
      return RedrawMenuItem(display); // Only static items in menu, so this is fine to call every time
    }

    case MenuAction_DrawItem:
    {
      // Disable Inaccessible Options: p1 = client, p2 = menuitem
      int style;
      char info[MAINMENUITEM_SIZE];
      GetMenuItem(menu, param2, info, sizeof(info), style);

      // Name Colour
      if(StrEqual(info, MAINMENUITEM_NAMECOLOUR, true)
        && !CheckCommandAccess(param1, "sm_setnamecolour", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }

      // Chat Colour
      else if(StrEqual(info, MAINMENUITEM_CHATCOLOUR, true)
        && !CheckCommandAccess(param1, "sm_setchatcolour", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }

      // Tag Colour
      else if(StrEqual(info, MAINMENUITEM_TAGCOLOUR, true)
        && !CheckCommandAccess(param1, "sm_settagcolour", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }
      
      // Admin/Mod Tag Border 
      else if(StrEqual(info, MAINMENUITEM_TOGGLEADMINBORDER, true)
        && (!CheckCommandAccess(param1, "sm_tagborder_admin", ADMFLAG_GENERIC, false)
        && !CheckCommandAccess(param1, "sm_tagborder_mod", ADMFLAG_GENERIC, false)))
      {
        return ITEMDRAW_DISABLED;
      }

      // Set & Reset Tag Text
      else if((StrEqual(info, MAINMENUITEM_SETTAGTEXT, true) || StrEqual(info, MAINMENUITEM_RESETTAGTEXT, true))
        && !CheckCommandAccess(param1, "sm_settag", ADMFLAG_GENERIC, false))
      {
        return ITEMDRAW_DISABLED;
      }

      // Reset All
      else if(StrEqual(info, MAINMENUITEM_RESETALL, true)
        && !CheckCommandAccess(param1, "sm_resetcolour_access", ADMFLAG_GENERIC, true))
      {
        return ITEMDRAW_DISABLED;
      }
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[MAINMENUITEM_SIZE];
      GetMenuItem(menu, param2, info, sizeof(info));

      if(StrEqual(info, MAINMENUITEM_NAMECOLOUR, true))
        OpenColourMenu(param1, CCC_NameColor);
      else if(StrEqual(info, MAINMENUITEM_CHATCOLOUR, true))
        OpenColourMenu(param1, CCC_ChatColor);
      else if(StrEqual(info, MAINMENUITEM_TAGCOLOUR, true))
        OpenColourMenu(param1, CCC_TagColor);
      else if(StrEqual(info, MAINMENUITEM_SETTAGTEXT, true))
      {
        g_bWaitingForCustomTag[param1] = true;
        TagPrintChat(param1, "%T", "SM_NAMECOLOUR_TagRequest", param1);
        OpenMainMenu(param1);
      }
      else if(StrEqual(info, MAINMENUITEM_TOGGLEADMINBORDER, true))
      {
        ToggleAdminTagBorder(param1);
        if(CheckCommandAccess(param1, "sm_tagborder_admin", ADMFLAG_GENERIC, false))
          TagPrintChat(param1, "%T", "SM_SETTAGBORDER_Toggled_Admin", param1);
        else if(CheckCommandAccess(param1, "sm_tagborder_mod", ADMFLAG_GENERIC, false))
          TagPrintChat(param1, "%T", "SM_SETTAGBORDER_Toggled_Mod", param1);
        OpenMainMenu(param1);
      }
      else if(StrEqual(info, MAINMENUITEM_RESETTAGTEXT, true))
      {
        SetPlayerTag(param1, "", true);   // true = reset;
        TagPrintChat(param1, "%T", "SM_SETTAG_Reset", param1);
        OpenMainMenu(param1);
      }
      else if(StrEqual(info, MAINMENUITEM_RESETALL, true))
      {
        SetPlayerNameColour(param1, -1); // -1 = reset
        SetPlayerChatColour(param1, -1);
        SetPlayerTagColour(param1, -1);
        SetPlayerTag(param1, "", true);
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

  // Get Colour Int
  int hexVal = StringToInt(arg1, 16);
  SetPlayerNameColour(client, hexVal);

  // Get Hex Colour String
  char colourStr[16];
  Format(colourStr, sizeof(colourStr), "\x07%06X%06X\x01", hexVal, hexVal); // %06X = Leading zeros

  TagReply(client, "%T", "SM_SETNAMECOLOUR_Done", client, colourStr);
  return Plugin_Handled;
}



/**
 * Set custom chat colour directly
 *
 * sm_setchatcolour <6-Digit Hex Colour>
 */
public Action CMD_SetChatColour(int client, int args)
{
  if(args < 1)
  {
    TagReplyUsage(client, "%T", "SM_SETCHATCOLOUR_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH];
  GetCmdArg(1, arg1, sizeof(arg1));

  if(!IsValid6DigitHex(arg1))
  {
    TagReply(client, "%T", "SFP_BadHexColour", client);
    return Plugin_Handled;
  }

  // Get Colour Int
  int hexVal = StringToInt(arg1, 16);
  SetPlayerChatColour(client, hexVal);

  // Get Hex Colour String
  char colourStr[16];
  Format(colourStr, sizeof(colourStr), "\x07%06X%06X\x01", hexVal, hexVal); // %06X = Leading zeros

  TagReply(client, "%T", "SM_SETCHATCOLOUR_Done", client, colourStr);
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

  // Get Colour Int
  int hexVal = StringToInt(arg1, 16);
  SetPlayerTagColour(client, hexVal);

  // Get Hex Colour String
  char colourStr[16];
  Format(colourStr, sizeof(colourStr), "\x07%06X%06X\x01", hexVal, hexVal); // %06X = Leading zeros

  TagReply(client, "%T", "SM_SETTAGCOLOUR_Done", client, colourStr);
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

  char argString[MAX_TAG_TEXT_LENGTH];
  GetCmdArgString(argString, sizeof(argString));

  SetPlayerTag(client, argString);
  TagReply(client, "%T", "SM_SETTAG_Done", client, argString);

  return Plugin_Handled;
}



/**
 * Set custom tag border
 * As admins and mods have special borders, this should be restricted in its use to avoid impersonation
 *
 * sm_settagborder [Target] <Left Border> <Right Border>
 */
public Action CMD_SetTagBorder(int client, int args)
{
  if(args < 2 || args > 3)
  {
    TagReplyUsage(client, "%T", "SM_SETTAGBORDER_Usage", client);
    return Plugin_Handled;
  }
  
  char targName[MAX_NAME_LENGTH], leftSide[TAGBORDERSIDE_CHARS], rightSide[TAGBORDERSIDE_CHARS];
  int target = client;
  if(args == 2)
  {
    GetCmdArg(1, leftSide, sizeof(leftSide));
    GetCmdArg(2, rightSide, sizeof(rightSide));
  }
  else if(args == 3)
  {
    GetCmdArg(1, targName, sizeof(targName));
    GetCmdArg(2, leftSide, sizeof(leftSide));
    GetCmdArg(3, rightSide, sizeof(rightSide));
    
    target = FindTarget(client, targName, true); // Single Targets only
    if(target == -1)
      return Plugin_Handled; // FindTarget prints error
  }
  
  // Manually merge together. This method guarantees a single space between 2 valid sides.
  char border[TAGBORDER_CHARS];
  Format(border, sizeof(border), "%s %s", leftSide, rightSide);
  
  if(IsClientInGame(target) && AreClientCookiesCached(target))
  {
    // Update tag
    char text[MAX_TAG_TEXT_LENGTH];
    SetClientCookie(target, h_ckTagBorder, border);
    GetClientCookie(target, h_ckTagText, text, sizeof(text));
    SetPlayerTag(target, text);
    if(target != client)
    {
      GetClientName(target, targName, sizeof(targName));
      TagActivity2(client, "%T", "SM_SETTAGBORDER_Done_Target", LANG_SERVER, targName, leftSide, rightSide);
    }
    else
      TagReply(client, "%T", "SM_SETTAGBORDER_Done", client, leftSide, rightSide);
  }
  else
    TagReply(client, "%T", "SM_SETTAGBORDER_Failed", client);
  return Plugin_Handled;
}

/**
 * Reset a player's custom tag border to default
 *
 * sm_resettagborder [Target]
 */
public Action CMD_ResetTagBorder(int client, int args)
{
  char arg1[MAX_NAME_LENGTH];
  int target = client;
  if(args == 1)
  {
    GetCmdArg(1, arg1, sizeof(arg1));
    target = FindTarget(client, arg1, true);
    if(target == -1)
      return Plugin_Handled; // FindTarget prints error
  }
  
  if(IsClientInGame(target) && AreClientCookiesCached(target))
  {
    // Update tag and reset border
    char text[MAX_TAG_TEXT_LENGTH];
    SetClientCookie(target, h_ckTagBorder, g_szTagBorderDefault);
    GetClientCookie(target, h_ckTagText, text, sizeof(text));
    SetPlayerTag(target, text);
    if(target != client)
    {
      GetClientName(target, arg1, sizeof(arg1));
      TagActivity2(client, "%T", "SM_RESETTAGBORDER_Done_Target", LANG_SERVER, arg1);
    }
    else
      TagReply(client, "%T", "SM_RESETTAGBORDER_Done", client);
  }
  else
    TagReply(client, "%T", "SM_RESETTAGBORDER_Failed", client);
  return Plugin_Handled;
}



/**
 * Colour Selection Submenu
 */
void OpenColourMenu(const int client, const CCC_ColorType colourType)
{
  Menu menu = new Menu(ColourHandler,
    MenuAction_End|MenuAction_Cancel|MenuAction_Display|MenuAction_Select);
  SetMenuTitle(menu, "Colour");
  SetMenuExitBackButton(menu, true);

  char reset[32];
  Format(reset, sizeof(reset), "%T", "SM_COLOURMENU_Reset", client);

  // Add 'Reset Colour' item first, with index/key specifying the type for handler
  char prefix;
  switch(colourType)
  {
    case CCC_NameColor:
    {
      prefix = NAME_PREFIX;
      AddMenuItem(menu, NAME_RESET_STRING, reset);
    }
    case CCC_ChatColor:
    {
      prefix = CHAT_PREFIX;
      AddMenuItem(menu, CHAT_RESET_STRING, reset);
    }
    case CCC_TagColor:
    {
      prefix = TAG_PREFIX;
      AddMenuItem(menu, TAG_RESET_STRING, reset);
    }
  }

  // Add all colours to menu
  for(int i = 0; i < g_szColourNames.Length; ++i)
  {
    char idx[IDX_SIZE+1];                         // + 1 for selection prefix
    char buff[MAX_COLOUR_NAME];
    g_szColourNames.GetString(i, buff, sizeof(buff));

    Format(idx, sizeof(idx), "%s%i", prefix, i);  // Prefix determines which colour type changes
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
      if(StrEqual(info, NAME_RESET_STRING, true))
      {
        SetPlayerNameColour(param1, -1); // -1 = reset
        TagPrintChat(param1, "%T", "SM_SETNAMECOLOUR_Reset", param1);
        OpenMainMenu(param1);
        return 0;
      }
      else if(StrEqual(info, CHAT_RESET_STRING, true))
      {
        SetPlayerChatColour(param1, -1);
        TagPrintChat(param1, "%T", "SM_SETCHATCOLOUR_Reset", param1);
        OpenMainMenu(param1);
        return 0;
      }
      else if(StrEqual(info, TAG_RESET_STRING, true))
      {
        SetPlayerTagColour(param1, -1);
        TagPrintChat(param1, "%T", "SM_SETTAGCOLOUR_Reset", param1);
        OpenMainMenu(param1);
        return 0;
      }

      // Client not resetting, Get colour value by chosen index
      int arrayIndex = StringToInt(info[1]); // Remove single char prefix
      int hexColour  = g_iColours.Get(arrayIndex);

      // Get Colour Hex String (Coloured with that same colour) for demo purposes
      char colourStr[16];
      Format(colourStr, sizeof(colourStr), "\x07%06X%06X\x01", hexColour, hexColour);

      if(info[0] == NAME_PREFIX)
      {
        SetPlayerNameColour(param1, hexColour);
        TagPrintChat(param1, "%T", "SM_SETNAMECOLOUR_Done", param1, colourStr);
      }
      else if(info[0] == CHAT_PREFIX)
      {
        SetPlayerChatColour(param1, hexColour);
        TagPrintChat(param1, "%T", "SM_SETCHATCOLOUR_Done", param1, colourStr);
      }
      else if(info[0] == TAG_PREFIX)
      {
        SetPlayerTagColour(param1, hexColour);
        TagPrintChat(param1, "%T", "SM_SETTAGCOLOUR_Done", param1, colourStr);
      }
      OpenMainMenu(param1);
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

/**
 * Load the g_szColourCfg.
 * Format:
 * "SatansFunColours"
 * {
 *   "Some Colour Name" "<6-Digit-Hex-Code>"
 *   ...
 * }
 */
stock bool LoadConfig()
{
  if(!FileExists(g_szColourCfg))
  {
    SetFailState("%T", "SFP_NoConfig", LANG_SERVER, g_szColourCfg);
    return false;
  }

  // Create and Check KeyValues
  KeyValues hKeys = CreateKeyValues("SatansFunColours");
  if(!hKeys.ImportFromFile(g_szColourCfg))
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfig", LANG_SERVER, g_szColourCfg);
    return false;
  }

  if(!hKeys.GotoFirstSubKey(false)) // false = Traverse values AND sections
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfigSubKey", LANG_SERVER, g_szColourCfg);
    return false;
  }

  // Zero Out
  g_iColours.Clear();
  g_szColourNames.Clear();
  
  int arrayCount  = 0; // Succesfully added colours (for indexing g_iColours)
  int skipCount   = 0; // Failed colours (for logging purposes)
  char colourName[MAX_COLOUR_NAME], hexString[7];
 
  do
  {
    hKeys.GetSectionName(colourName, sizeof(colourName));
    hKeys.GetString(NULL_STRING, hexString, sizeof(hexString), ""); // Default to ""

    if(StrEqual(colourName, "", true) || !IsValid6DigitHex(hexString))
    {
      ++skipCount;
      continue;
    }
    
    g_szColourNames.PushString(colourName);
    g_iColours.Push(StringToInt(hexString, 16));
    ++arrayCount;
  }
  while(hKeys.GotoNextKey(false) && arrayCount < MAX_COLOURS);

  PrintToServer("%T", "SM_NAMECOLOUR_ConfigLoad", LANG_SERVER, arrayCount, skipCount);
  delete hKeys;
  return true;
}


/**
 * Set a player's CCC Tag and set cookie
 */
stock void SetPlayerTag(const int client, const char[] tagInnerText, const bool reset=false)
{
  char buff[MAX_TAG_LENGTH] = ""; // Adding "[", "]" and " " 
  bool cookiesReady         = AreClientCookiesCached(client);
  
  if(reset)
    CCC_ResetTag(client);
  else
  {
    char border[TAGBORDER_CHARS];
    if(cookiesReady)
      GetClientCookie(client, h_ckTagBorder, border, sizeof(border));
    else
      strcopy(border, sizeof(border), g_szTagBorderDefault);
    
    FormatPlayerTag(tagInnerText, border, buff, sizeof(buff));
    CCC_SetTag(client, buff);
  }
  
  if(cookiesReady)
    SetClientCookie(client, h_ckTagText, (reset) ? "" : tagInnerText); // Empty wont be applied on-join
  return;
}

/**
 * Format tag text with tag border and output the final result
 * This result will be ready for use with CCC_SetTag. e.g. "[<Text>] "
 *
 * The border parameter needs to be 2 space-separated strings.
 * If it does not contain a space, g_szTagBorderDefault will be used instead
 */
stock void FormatPlayerTag(const char[] text, const char[] border, char[] buffer, const int maxlength)
{
  char borderSides[2][TAGBORDERSIDE_CHARS];
  if(FindCharInString(border, ' ') != -1)
    ExplodeString(border, " ", borderSides, sizeof(borderSides), sizeof(borderSides[]));
  else
    ExplodeString(g_szTagBorderDefault, " ", borderSides, sizeof(borderSides), sizeof(borderSides[]));
  
  Format(buffer, maxlength, "%s%s%s ", borderSides[0], text, borderSides[1]);
  return;
}

stock void ToggleAdminTagBorder(const int client)
{
  if(AreClientCookiesCached(client))
  {
    char innerText[MAX_TAG_TEXT_LENGTH], border[TAGBORDER_CHARS];
    GetClientCookie(client, h_ckTagText, innerText, sizeof(innerText));
    GetClientCookie(client, h_ckTagBorder, border, sizeof(border));
    
    // If tag is admin or mod, revert to default (can be custom, so must be explicit)
    if(StrEqual(border, g_szTagBorderAdmin, true) || StrEqual(border, g_szTagBorderMod, true))
      SetClientCookie(client, h_ckTagBorder, g_szTagBorderDefault);
    else
    {
      if(CheckCommandAccess(client, "sm_tagborder_admin", ADMFLAG_GENERIC, false)) // Admin has priority
        SetClientCookie(client, h_ckTagBorder, g_szTagBorderAdmin);
      else if(CheckCommandAccess(client, "sm_tagborder_mod", ADMFLAG_GENERIC, false))
        SetClientCookie(client, h_ckTagBorder, g_szTagBorderMod);
      // Else player has no access, leave default
    }
    
    // Force tag update
    SetPlayerTag(client, innerText);
  }
  return;
}



/**
 * Set/Save a player's CCC Tag Colour
 */
stock void SetPlayerTagColour(const int client, const int colour)
{
  SetPlayerColour(client, colour, CCC_TagColor, h_ckTagColour);
  return;
}


/**
 * Set/Save a player's CCC Name Colour
 */
stock void SetPlayerNameColour(const int client, const int colour)
{
  SetPlayerColour(client, colour, CCC_NameColor, h_ckNameColour);
  return;
}


/**
 * Set/Save a player's CCC Chat Colour
 */
stock void SetPlayerChatColour(const int client, const int colour)
{
  SetPlayerColour(client, colour, CCC_ChatColor, h_ckChatColour);
  return;
}

/**
 * Set a player's CCC Colours and set cookie
 * Pass -1 as colour to reset.
 **/
stock void SetPlayerColour(const int client, const int colour, const CCC_ColorType type, Handle &cookie)
{
  if(colour > 0)
    CCC_SetColor(client, type, colour, false); // False = no alpha, 6-digit
  else
    CCC_ResetColor(client, type);

  if(AreClientCookiesCached(client))
  {
    char buff[16];
    IntToString(colour, buff, sizeof(buff));
    SetClientCookie(client, cookie, buff);
  }
  return;
}


/**
 * Read a client's cookies and set their CCC Values directly
 */
stock void LoadClientCookies(const int client)
{
  char buff[MAX_TAG_LENGTH];    // Account for "[", "]" and " " in "[<Tag>] "
  
  // Name
  GetClientCookie(client, h_ckNameColour, buff, sizeof(buff));
  if(!StrEqual(buff, "", true)) // Empty = disabled
    CCC_SetColor(client, CCC_NameColor, StringToInt(buff), false);

  // Chat
  GetClientCookie(client, h_ckChatColour, buff, sizeof(buff));
  if(!StrEqual(buff, "", true))
    CCC_SetColor(client, CCC_ChatColor, StringToInt(buff), false);

  // Tag Colour
  GetClientCookie(client, h_ckTagColour, buff, sizeof(buff));
  if(!StrEqual(buff, "", true))
    CCC_SetColor(client, CCC_TagColor, StringToInt(buff), false);
  
  // Tag Text & Border
  char text[MAX_TAG_TEXT_LENGTH];
  GetClientCookie(client, h_ckTagText, text, sizeof(text));
  if(!StrEqual(text, "", true))
  {
    char border[TAGBORDER_CHARS];
    GetClientCookie(client, h_ckTagBorder, border, sizeof(border));
    FormatPlayerTag(text, border, buff, sizeof(buff));
    CCC_SetTag(client, buff); // Don't use SetPlayerTag
                              // It's already formatted and we dont want to set cookies again
  }
    
  return;
}


//=================================
// Updater
public void OnConfigsExecuted()
{
  if(LibraryExists("updater") && h_bUpdate.BoolValue)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryAdded(const char[] name)
{
  if(StrEqual(name, "updater") && h_bUpdate.BoolValue)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryRemoved(const char[] name)
{
  if(StrEqual(name, "updater"))
    Updater_RemovePlugin();
  return;
}
