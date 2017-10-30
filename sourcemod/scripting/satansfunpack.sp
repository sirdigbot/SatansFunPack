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
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/main_update.txt"


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;
char    g_szList[206] = "MODULE - INSTALLED(Y/N)\n--------\n"; // 206 exactly, incl \0.
Handle  h_szConfig = null;


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack",
  author =      "SirDigby",
  description = "A Megapack of Commands",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};


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



/***
 * This core file doesn't do a lot, but is the only file that includes:
 * The translation and config files as part of the updater download.
 * It also Sets the main version, config and updater cvars.
 * Modules must use FindConVar for the updater and cvar setting.
 *
 * As such, this is the ONLY required file.
 ***/
public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");

  CreateConVar("satansfunpack_version", PLUGIN_VERSION, "Satan's Fun Pack version. Do Not Touch!", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

  h_bUpdate = CreateConVar("sm_satansfunpack_update", "1", "Update this Plugin Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

  h_szConfig = CreateConVar("sm_satansfunpack_config", "satansfunpack.cfg", "Config File used for Satan'sFunPack (Relative to Sourcemod/Configs)\n(Default: satansfunpack.cfg)", FCVAR_SPONLY);
  if(!h_szConfig)
    SetFailState("Config CVar somehow failed to be created."); // To stop compile warnings.

  RegAdminCmd("sm_sfpplugincheck", InstallCheck, ADMFLAG_ROOT, "Check which Satan's Fun Pack Modules are Installed");

  /**
   * Check what modules are installed and cache list.
   * Expensive so do only OnPluginStart.
   **/
  int count = 0;
  count += CheckFileAndCache("AdminTools", "plugins/sfp_admintools.smx");
  count += CheckFileAndCache("Bans", "plugins/sfp_bans.smx");
  count += CheckFileAndCache("ChatVision", "plugins/sfp_chatvision.smx");
  count += CheckFileAndCache("Duel", "plugins/sfp_duel.smx");
  count += CheckFileAndCache("GodMode", "plugins/sfp_godmode.smx");
  count += CheckFileAndCache("GroupManager", "plugins/sfp_groupmanager.smx");
  count += CheckFileAndCache("InfoUtils", "plugins/sfp_infoutils.smx");
  count += CheckFileAndCache("Mirror", "plugins/sfp_mirror.smx");
  count += CheckFileAndCache("QuickConditions", "plugins/sfp_quickconditions.smx");
  count += CheckFileAndCache("Targeting", "plugins/sfp_targeting.smx");
  count += CheckFileAndCache("ToyBox", "plugins/sfp_toybox.smx");
  count += CheckFileAndCache("Trails", "plugins/sfp_trails.smx");

  PrintToServer("%T", "SFP_Loaded", LANG_SERVER, count);
}


int CheckFileAndCache(const char[] pluginName, const char[] filepath)
{
  char path[PLATFORM_MAX_PATH], buffer[32];
  bool result;

  BuildPath(Path_SM, path, PLATFORM_MAX_PATH, filepath);
  result = FileExists(path);

  Format(buffer, sizeof(buffer), "%s - %s", pluginName, (result) ? "Y\n" : "N\n");
  StrCat(g_szList, sizeof(g_szList), buffer);
  return view_as<int>(result);
}


public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = view_as<bool>(StringToInt(newValue));
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  return;
}



public Action InstallCheck(int client, int args)
{
  PrintToConsole(client, g_szList);
  if(client != 0 && GetCmdReplySource() == SM_REPLY_TO_CHAT)
    TagReply(client, "%T", "SFP_ConsoleOutput", client);

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
