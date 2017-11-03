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
#define PLUGIN_VERSION    "1.0.0"
#define PLUGIN_URL        "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL        "https://sirdigbot.github.io/SatansFunPack/sourcemod/help_update.txt"
#define MAX_HELP_STR      64
#define MAX_HELP_SECTIONS 64
#define MAX_HELP_ITEMS    64
#define MAX_ITEM_FLAGS    13  // Maximum number of possible item flags.
#define SECT_IDX_SIZE     3   // "64" +\0
#define ITEM_IDX_SIZE     3

#define _INCLUDE_RULES  // Help command must be included. sm_rules is a shortcut, however.

// Section Flags
#define SECT_HIDDEN   (1<<0) // Section is unlisted. Must use "open:___" to see.
#define SECT_ADMIN    (1<<1) // Section is visible to admins only
#define SECT_SCOUT    (1<<2) // Section is visible to certain classes:
#define SECT_SOLDIER  (1<<3)
#define SECT_PYRO     (1<<4)
#define SECT_DEMO     (1<<5)
#define SECT_HEAVY    (1<<6)
#define SECT_ENGIE    (1<<7)
#define SECT_MEDIC    (1<<8)
#define SECT_SNIPER   (1<<9)
#define SECT_SPY      (1<<10)
#define SECT_ALLCLASS (1<<11)

// Help Item Flags
#define ITEM_STANDARD     (1<<0) // Not ITEMDRAW_DISABLED
#define ITEM_TEXTONLY     (1<<1) // ITEMDRAW_DISABLED. Cannot co-exist with ITEM_STANDARD
#define ITEM_CCOM         (1<<2) // Item has a Client Command String
#define ITEM_REDIRECT     (1<<3) // Item has a redirect when selected.
#define ITEM_ADMIN        (1<<4) // Item is visible to admins only.
#define ITEM_SCOUT        (1<<5) // Item is visible to certain classes:
#define ITEM_SOLDIER      (1<<6)
#define ITEM_PYRO         (1<<7)
#define ITEM_DEMO         (1<<8)
#define ITEM_HEAVY        (1<<9)
#define ITEM_ENGIE        (1<<10)
#define ITEM_MEDIC        (1<<11)
#define ITEM_SNIPER       (1<<12)
#define ITEM_SPY          (1<<13)
#define ITEM_ALLCLASS     (1<<14)
#define ITEM_INVALID      (1<<15) // Used for invalid result in GetItemFlagFromStr()

//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
Handle  h_szHelpCfg = null;
char    g_szHelpCfg[PLATFORM_MAX_PATH];

// Section Key: Sequential Integers from 0 + IntToString
StringMap g_szMapSectName;      // Section Details (All Required per section)
StringMap g_szMapSectTitle;
StringMap g_fbMapSectFlags;     // Only use Set/GetVALUE for Flagbits

// Help Item Key: "0_5" = Section Index 0, String Index 5
StringMap g_szMapItemText;      // Item String (Required per item)
StringMap g_fbMapItemFlags;     // Flagbit for Item (Required per item)
StringMap g_szMapItemCCom;      // String to run as Client Cmd
StringMap g_szMapItemRedirIdx;  // Idx (as str) to load on item select (In inner-menu)
char      g_szFirstGreetIdx[SECT_IDX_SIZE]; // Idx (str) of First-Time Greeting Menu, -1 for none.
char      g_szWelcomeIdx[SECT_IDX_SIZE];    // Idx (str) of Regular Greeting Menu, -1 for none.
char      g_szRulesIdx[SECT_IDX_SIZE];      // Idx (str) of Rules section (to use with sm_rules)
int       g_iSectionCount;
// TODO Cleanly implement a way to go back to previous submenus, which can stack.
// TODO Make FirstGreet and Welcome do something.

public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Help Menu",
  author =      "SirDigby",
  description = "Display Help and Rules Menus",
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
		Format(err, err_max, "%T", "SFP_Incompatible", LANG_SERVER);
		return APLRes_Failure;
	}
	return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");

  h_bUpdate = FindConVar("sm_satansfunpack_update");
  if(h_bUpdate == null)
    SetFailState("%T", "SFP_MainCvarFail", LANG_SERVER, "sm_satansfunpack_update");
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);


  h_szHelpCfg = CreateConVar("sm_satansfunpack_helpconfig", "satansfunpack_help.cfg", "Config File used for Satan's Fun Pack Help Menu (Relative to Sourcemod/Configs)\n(Default: satansfunpack_help.cfg)", FCVAR_SPONLY);

  char buff[PLATFORM_MAX_PATH], formatBuff[PLATFORM_MAX_PATH+13];
  GetConVarString(h_szHelpCfg, buff, sizeof(buff));
  Format(formatBuff, sizeof(formatBuff), "configs/%s", buff);
  BuildPath(Path_SM, g_szHelpCfg, sizeof(g_szHelpCfg), formatBuff);
  LoadConfig();


  RegConsoleCmd("sm_help",  CMD_HelpMenu,   "Displays the Server Help Menu");
  #if defined _INCLUDE_RULES
  RegConsoleCmd("sm_rules", CMD_RulesMenu,  "Display the Server Rules");
  #endif

  /**
   * Overrides
   * sm_helpmenu_admin - Player can see any admin-only sections or text.
   */

  // Create Maps. Must be done in function.
  g_szMapSectName     = new StringMap();
  g_szMapSectTitle    = new StringMap();
  g_fbMapSectFlags    = new StringMap();
  g_szMapItemText     = new StringMap();
  g_fbMapItemFlags    = new StringMap();
  g_szMapItemCCom     = new StringMap();
  g_szMapItemRedirIdx = new StringMap();

  PrintToServer("%T", "SFP_HelpLoaded", LANG_SERVER);
}



public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_szHelpCfg)
  {
    char formatBuff[PLATFORM_MAX_PATH+13];
    Format(formatBuff, sizeof(formatBuff), "configs/%s", newValue);
    BuildPath(Path_SM, g_szHelpCfg, sizeof(g_szHelpCfg), formatBuff);
    LoadConfig();
  }
  return;
}



/**
 * Show the help menu
 *
 * sm_help
 */
public Action CMD_HelpMenu(int client, int args)
{
  OpenHelpMenu(client);
  return Plugin_Handled;
}

stock void OpenHelpMenu(int client)
{
  Menu menu = new Menu(HelpMenuHandler,
    MenuAction_End|MenuAction_Display|MenuAction_DrawItem|MenuAction_Select);
  SetMenuTitle(menu, "Help Menu"); // Translation is in Handler

  for(int i = 0; i < g_szMapSectName.Size; ++i)
  {
    char idxStr[SECT_IDX_SIZE];
    IntToString(i, idxStr, sizeof(idxStr));

    char nameBuff[MAX_HELP_STR];
    int flags;
    g_szMapSectName.GetString(idxStr, nameBuff, sizeof(nameBuff));
    g_fbMapSectFlags.GetValue(idxStr, flags);

    bool bShow = true;
    if(HasFlag(flags, SECT_HIDDEN))
      bShow = false;
    else if(HasFlag(flags, SECT_ADMIN)
      && !CheckCommandAccess(client, "sm_helpmenu_admin", ADMFLAG_BAN, true))
    {
      bShow = false;
    }

    if(bShow)
      AddMenuItem(menu, idxStr, nameBuff);
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int HelpMenuHandler(Handle menu, MenuAction action, int param1, int param2)
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
      Format(buffer, sizeof(buffer), "%T", "SM_HELPMENU_Title", param1);

      Handle panel = view_as<Handle>(param2);
      SetPanelTitle(panel, buffer);
    }

    case MenuAction_DrawItem:
    {
      // Handle Section Flags: p1 = client, p2 = menuitem
      int style;
      char info[SECT_IDX_SIZE]; // The section index (idxStr)
      GetMenuItem(menu, param2, info, sizeof(info), style);
      int flags;
      g_fbMapSectFlags.GetValue(info, flags);

      // Admin and Hidden filtering is done. Check classes.
      if(HasFlag(flags, SECT_ALLCLASS))
        return style;

      switch(TF2_GetPlayerClass(param1))
      {
        case TFClass_Scout:
          return (HasFlag(flags, SECT_SCOUT))   ? style : ITEMDRAW_IGNORE; // TODO verify
        case TFClass_Soldier:
          return (HasFlag(flags, SECT_SOLDIER)) ? style : ITEMDRAW_IGNORE;
        case TFClass_Pyro:
          return (HasFlag(flags, SECT_PYRO))    ? style : ITEMDRAW_IGNORE;
        case TFClass_DemoMan:
          return (HasFlag(flags, SECT_DEMO))    ? style : ITEMDRAW_IGNORE;
        case TFClass_Heavy:
          return (HasFlag(flags, SECT_HEAVY))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Engineer:
          return (HasFlag(flags, SECT_ENGIE))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Medic:
          return (HasFlag(flags, SECT_MEDIC))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Sniper:
          return (HasFlag(flags, SECT_SNIPER))  ? style : ITEMDRAW_IGNORE;
        case TFClass_Spy:
          return (HasFlag(flags, SECT_SPY))     ? style : ITEMDRAW_IGNORE;
        default:
          return style;
      }
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[SECT_IDX_SIZE];
      GetMenuItem(menu, param2, info, sizeof(info));

      OpenSubmenu(param1, info);
    }
  }
  return 0;
}


/**
 * Shortcut to show the "Rules" section of the help menu, if one exists.
 *
 * sm_rules
 */
#if defined _INCLUDE_RULES
public Action CMD_RulesMenu(int client, int args)
{
  if(!StrEqual(g_szRulesIdx, "", true))
    OpenSubmenu(client, g_szRulesIdx);
  else
    TagReply(client, "%T", "SM_HELPMENU_NoRules", client);
  return Plugin_Handled;
}
#endif


void OpenSubmenu(int client, char[] index)
{
  Menu menu = new Menu(SubMenuHandler,
    MenuAction_End|MenuAction_Cancel|MenuAction_DrawItem|MenuAction_Select);

  char titleBuff[MAX_HELP_STR];
  g_szMapSectTitle.GetString(index, titleBuff, sizeof(titleBuff));
  SetMenuTitle(menu, titleBuff);
  SetMenuExitBackButton(menu, true);

  char itemIdx[ITEM_IDX_SIZE * 2]; // "64_64" \0
  int count = 0, flags;
  Format(itemIdx, sizeof(itemIdx), "%s_%i", index, count);
  bool idxExists = g_fbMapItemFlags.GetValue(itemIdx, flags);

  while(idxExists && count < MAX_HELP_ITEMS)
  {
    // Hide Item if Necessary
    bool bShow = true;
    if(HasFlag(flags, ITEM_ADMIN)
      && !CheckCommandAccess(client, "sm_helpmenu_admin", ADMFLAG_BAN, true))
    {
      bShow = false;
    }

    if(bShow)
    {
      char itemText[MAX_HELP_STR];
      g_szMapItemText.GetString(itemIdx, itemText, sizeof(itemText));
      AddMenuItem(menu, itemIdx, itemText);
    }

    count++;
    Format(itemIdx, sizeof(itemIdx), "%s_%i", index, count);
    idxExists = g_fbMapItemFlags.GetValue(itemIdx, flags);
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return;
}

public int SubMenuHandler(Handle menu, MenuAction action, int param1, int param2)
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
        OpenHelpMenu(param1);
    }

    case MenuAction_DrawItem:
    {
      // Handle Section Flags: p1 = client, p2 = menuitem
      int style;
      char info[ITEM_IDX_SIZE]; // The item index (itemIdx)
      GetMenuItem(menu, param2, info, sizeof(info), style);
      int flags;
      g_fbMapItemFlags.GetValue(info, flags);

      // Admin filtering is done. Check classes and text display mode.
      if(HasFlag(flags, ITEM_TEXTONLY)) // Overrides all others.
        return ITEMDRAW_RAWLINE;

      if(HasFlag(flags, SECT_ALLCLASS))
        return style;

      switch(TF2_GetPlayerClass(param1))
      {
        case TFClass_Scout:
          return (HasFlag(flags, ITEM_SCOUT))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Soldier:
          return (HasFlag(flags, ITEM_SOLDIER)) ? style : ITEMDRAW_IGNORE;
        case TFClass_Pyro:
          return (HasFlag(flags, ITEM_PYRO))    ? style : ITEMDRAW_IGNORE;
        case TFClass_DemoMan:
          return (HasFlag(flags, ITEM_DEMO))    ? style : ITEMDRAW_IGNORE;
        case TFClass_Heavy:
          return (HasFlag(flags, ITEM_HEAVY))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Engineer:
          return (HasFlag(flags, ITEM_ENGIE))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Medic:
          return (HasFlag(flags, ITEM_MEDIC))   ? style : ITEMDRAW_IGNORE;
        case TFClass_Sniper:
          return (HasFlag(flags, ITEM_SNIPER))  ? style : ITEMDRAW_IGNORE;
        case TFClass_Spy:
          return (HasFlag(flags, ITEM_SPY))     ? style : ITEMDRAW_IGNORE;
        default:
          return style;
      }
    }

    case MenuAction_Select:
    {
      // Selection Events: p1 = client, p2 = menuitem
      char info[ITEM_IDX_SIZE];
      GetMenuItem(menu, param2, info, sizeof(info));
      int flags;
      g_fbMapItemFlags.GetValue(info, flags);

      // Check item flags to handle CCOM/Redirect Behaviour
      if(HasFlag(flags, ITEM_CCOM))
      {
        char ccomBuff[MAX_HELP_STR];
        g_szMapItemCCom.GetString(info, ccomBuff, sizeof(ccomBuff));

        if(IsClientInGame(param1))
          FakeClientCommandEx(param1, ccomBuff);
      }

      if(HasFlag(flags, ITEM_REDIRECT))
      {
        char sectIdxBuff[MAX_HELP_STR];
        g_szMapItemRedirIdx.GetString(info, sectIdxBuff, sizeof(sectIdxBuff));

        if(IsClientInGame(param1))
          OpenSubmenu(param1, sectIdxBuff);
      }
    }
  }
  return 0;
}



/**
 * Process Config and Cache Menus:
 * - Reset Menu Globals
 * - Jump to section. section-idx for globals must be ready
 * - Store name, title & flags for section-idx
 * - Set/Overwrite welcome/firstgreet index if necessary
 * - Jump to items
 *  - Store text for section + item idx (0_0, 0_1, etc.)
 *  - Explode flags
 *    - For Bools, set flagbit.
 *    - For others: If exploded str starts with "open:", dereference redirect & set flag.
 *      Else, treat as CCom.
 * - Jump back to section, proceed to next section.
 */
stock bool LoadConfig()
{
  if(!FileExists(g_szHelpCfg))
  {
    SetFailState("%T", "SFP_NoConfig", LANG_SERVER, g_szHelpCfg);
    return false;
  }

  // Create and check KeyValues
  KeyValues hKeys = CreateKeyValues("SatansHelpMenu"); // Requires Manual Delete
  if(!FileToKeyValues(hKeys, g_szHelpCfg))
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfig", LANG_SERVER, g_szHelpCfg);
    return false;
  }

  if(!hKeys.GotoFirstSubKey())
  {
    delete hKeys;
    SetFailState("%T", "SFP_BadConfigSubKey", LANG_SERVER, g_szHelpCfg);
    return false;
  }

  g_szMapSectName.Clear();
  g_szMapSectTitle.Clear();
  g_fbMapSectFlags.Clear();
  g_szMapItemText.Clear();
  g_fbMapItemFlags.Clear();
  g_szMapItemCCom.Clear();
  g_szMapItemRedirIdx.Clear();
  g_szFirstGreetIdx = "";
  g_szWelcomeIdx    = "";
  g_szRulesIdx      = "";
  g_iSectionCount   = -1; // We increment at the start to allow skipping.


  // Begin Processing and say prayers.

  do
	{
    char index[SECT_IDX_SIZE], buffer[MAX_HELP_STR];
    ++g_iSectionCount;
    IntToString(g_iSectionCount, index, sizeof(index));

    // Get Name and Title
    hKeys.GetSectionName(buffer, sizeof(buffer));
    g_szMapSectName.SetString(index, buffer, true);
    if(StrEqual(buffer, "Rules", false))
      g_szRulesIdx = index;

    hKeys.GetString("title", buffer, sizeof(buffer), "");   // Defaults to empty
    g_szMapSectTitle.SetString(index, buffer, true);

    // Get Section Flags: Hidden and Filters
    int flags = 0;
    hKeys.GetString("hidden", buffer, sizeof(buffer), "0"); // Defaults to 0/false
    if(StrEqual(buffer, "1", true))
      AddFlag(flags, SECT_HIDDEN);

    // TODO: Optimise this if possible.
    // StrContains is safe here since these are all fixed, non-clashing strings.
    hKeys.GetString("filter", buffer, sizeof(buffer), "");  // Defaults to empty
    if(StrContains(buffer, "admin", true) != -1)
      AddFlag(flags, SECT_ADMIN);

    bool bAllClass = true;
    if(StrContains(buffer, "scout", true) != -1)
    {
      AddFlag(flags, SECT_SCOUT);
      bAllClass = false;
    }
    if(StrContains(buffer, "soldier", true) != -1)
    {
      AddFlag(flags, SECT_SOLDIER);
      bAllClass = false;
    }
    if(StrContains(buffer, "pyro", true) != -1)
    {
      AddFlag(flags, SECT_PYRO);
      bAllClass = false;
    }
    if(StrContains(buffer, "demo", true) != -1)
    {
      AddFlag(flags, SECT_DEMO);
      bAllClass = false;
    }
    if(StrContains(buffer, "heavy", true) != -1)
    {
      AddFlag(flags, SECT_HEAVY);
      bAllClass = false;
    }
    if(StrContains(buffer, "engie", true) != -1)
    {
      AddFlag(flags, SECT_ENGIE);
      bAllClass = false;
    }
    if(StrContains(buffer, "medic", true) != -1)
    {
      AddFlag(flags, SECT_MEDIC);
      bAllClass = false;
    }
    if(StrContains(buffer, "sniper", true) != -1)
    {
      AddFlag(flags, SECT_SNIPER);
      bAllClass = false;
    }
    if(StrContains(buffer, "spy", true) != -1)
    {
      AddFlag(flags, SECT_SPY);
      bAllClass = false;
    }

    if(bAllClass)
      AddFlag(flags, SECT_ALLCLASS);

    g_fbMapSectFlags.SetValue(index, flags);


    // Get/Set First-Greet and Welcome
    hKeys.GetString("firstgreet", buffer, sizeof(buffer), "0"); // Defaults to 0/false
    if(StrEqual(buffer, "1", true))
      g_szFirstGreetIdx = index;

    hKeys.GetString("welcome", buffer, sizeof(buffer), "0");    // Defaults to 0/false
    if(StrEqual(buffer, "1", true))
      g_szWelcomeIdx = index;


    // Process Items
    if(hKeys.JumpToKey("items", false) && hKeys.GotoFirstSubKey())
    {
      int itemCount = -1;

      do
      {
        ++itemCount;
        char itemIndex[ITEM_IDX_SIZE * 2]; // "64_64" + \0
        Format(itemIndex, sizeof(itemIndex), "%i_%i", g_iSectionCount, itemCount);

        hKeys.GetString("text", buffer, sizeof(buffer), ""); // Defaults to empty
        g_szMapItemText.SetString(itemIndex, buffer, true);

        // Check Item Flags
        hKeys.GetString("flags", buffer, sizeof(buffer), ""); // Defaults to empty
        if(strlen(buffer) > 0)
        {
          flags = GetItemFlags(itemIndex, buffer); // Holy abuse-of-nested-while-loops, batman.
          g_fbMapItemFlags.SetValue(itemIndex, flags);
        }
        else
          g_fbMapItemFlags.SetValue(itemIndex, 0);

      } while(hKeys.GotoNextKey() && itemCount < MAX_HELP_ITEMS);

      hKeys.GoBack(); // GotoNextKey doesn't add to traversal stack. This jumps back to items.
    }

    hKeys.GoBack();   // Jump back to top-level section.

	} while(hKeys.GotoNextKey() && g_iSectionCount < MAX_HELP_SECTIONS);

  delete hKeys;
  return true;
}

/**
 * Returns Flagbit with Item Flags from a [potentially mixed] string.
 *
 * e.g: "admin|open: a menu|scout|spy" returns STANDARD|ADMIN|REDIRECT|SCOUT|SPY
 *      "admin" returns ADMIN
 */
stock int GetItemFlags(char[] itemIdx, char[] str)
{
  int   display = ITEM_STANDARD; // Cannot exist with ITEM_TEXTONLY. So both occupy this value.
  int   flags = 0, flagBuff = 0;
  char  splitBuff[MAX_HELP_STR];
  int   splitIdx;

  splitIdx = SplitString(str, "|", splitBuff, sizeof(splitBuff));

  if(splitIdx == -1) // Only 1 flag in string
  {
    ProcessItemStringEffect(itemIdx, str, flags, flagBuff, display);

    if(flags == ITEM_INVALID)
      return display|ITEM_ALLCLASS; // Exactly 1 of the 2 display modes must be returned.
    else if(flags == ITEM_TEXTONLY)
      return flags|ITEM_ALLCLASS; // We know flags != a class filter so we need a default.
  }
  else // More than 1 flag in string.
  {
    // Process first arg and pipe-idx before loop, so we always end on last arg (without a pipe)
    int safety, splitTotal;
    splitTotal = splitIdx; // Counts as processing pipe by giving us the next arg idx
    ProcessItemStringEffect(itemIdx, splitBuff, flags, flagBuff, display);

    while(splitIdx != -1 && safety < MAX_ITEM_FLAGS)
    {
      // splitTotal = splitIdx at first, otherwise this gets the new idx.
      splitIdx = SplitString(str[splitTotal], "|", splitBuff, sizeof(splitBuff));

      // Process Arg/Flag
      if(splitIdx == -1)
        ProcessItemStringEffect(itemIdx, str[splitTotal], flags, flagBuff, display); // To str end
      else
        ProcessItemStringEffect(itemIdx, splitBuff, flags, flagBuff, display);

      splitTotal += splitIdx;
      ++safety;
    }
  }

  if(!HasClassFilter(flags))
    AddFlag(flags, ITEM_ALLCLASS);

  return display|flags;
}

/**
 * Reads a string, gets the flagbit, then handles side effects.
 */
void ProcessItemStringEffect(
  char[]  itemIdx,
  char[]  flagString,
  int     &flags,
  int     &flagBuff,
  int     &display)
{
  flagBuff = GetItemFlagFromStr(flagString);

  // Set Flags and Handle Side Effects
  if(flagBuff == ITEM_TEXTONLY)
    display = ITEM_TEXTONLY;
  else if(flagBuff == ITEM_CCOM)
  {
    // Get CCom String
    char buff[MAX_HELP_STR];
    strcopy(buff, sizeof(buff), flagString[4]); // Trim "cmd:"
    g_szMapItemCCom.SetString(itemIdx, buff, true);

    AddFlag(flags, flagBuff);
  }
  else if(flagBuff == ITEM_REDIRECT)
  {
    // Dereference Menu Index to Redirect To
    char buff[MAX_HELP_STR];
    strcopy(buff, sizeof(buff), flagString[5]); // Trim "open:"

    for(int i = 0; i < g_szMapSectName.Size; ++i)
    {
      char name[MAX_HELP_STR], sectIdx[SECT_IDX_SIZE];
      IntToString(i, sectIdx, sizeof(sectIdx));

      g_szMapSectName.GetString(sectIdx, name, sizeof(name));
      if(StrEqual(name, buff, true))
      {
        g_szMapItemRedirIdx.SetString(itemIdx, sectIdx, true);
        break;
      }
    }

    AddFlag(flags, flagBuff);
  }
  else if(flagBuff != ITEM_INVALID)
    AddFlag(flags, flagBuff);

  return;
}

/**
 * Gets Item Flagbit from a single string.
 */
stock int GetItemFlagFromStr(char[] str)
{
  if(StrEqual(str, "", true))
    return ITEM_STANDARD;
  else if(StrEqual(str, "text", true))
    return ITEM_TEXTONLY;
  else if(StrContains(str, "cmd:", true) == 0)
    return ITEM_CCOM;
  else if(StrContains(str, "open:", true) == 0)
    return ITEM_REDIRECT;
  else if(StrEqual(str, "admin", true))
    return ITEM_ADMIN;

  else if(StrEqual(str, "scout", true))
    return ITEM_SCOUT;
  else if(StrEqual(str, "soldier", true))
    return ITEM_SOLDIER;
  else if(StrEqual(str, "pyro", true))
    return ITEM_PYRO;
  else if(StrEqual(str, "demo", true))
    return ITEM_DEMO;
  else if(StrEqual(str, "heavy", true))
    return ITEM_HEAVY;
  else if(StrEqual(str, "engie", true))
    return ITEM_ENGIE;
  else if(StrEqual(str, "medic", true))
    return ITEM_MEDIC;
  else if(StrEqual(str, "sniper", true))
    return ITEM_SNIPER;
  else if(StrEqual(str, "spy", true))
    return ITEM_SPY;
  return ITEM_INVALID;
}


stock bool HasClassFilter(int &val)
{
  if(HasFlag(val, ITEM_SCOUT))
    return true;
  else if(HasFlag(val, ITEM_SOLDIER))
    return true;
  else if(HasFlag(val, ITEM_PYRO))
    return true;
  else if(HasFlag(val, ITEM_DEMO))
    return true;
  else if(HasFlag(val, ITEM_HEAVY))
    return true;
  else if(HasFlag(val, ITEM_ENGIE))
    return true;
  else if(HasFlag(val, ITEM_MEDIC))
    return true;
  else if(HasFlag(val, ITEM_SNIPER))
    return true;
  else if(HasFlag(val, ITEM_SPY))
    return true;
  return false;
}


stock void AddFlag(int &val, int flag)
{
  val |= flag;
  return;
}

stock void RemFlag(int &val, int flag)
{
  val &= ~flag;
  return;
}

stock bool HasFlag(int val, int flag)
{
  return view_as<bool>((val & flag != 0));
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
