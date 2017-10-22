#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>  // Shared function library


//=================================
// Constants
#define PLUGIN_VERSION  "0.0.1"
#define PLUGIN_URL      "UNDEFINED"
#define UPDATE_URL      "UNDEFINED"


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack",
  author =      "SirDigby",
  description = "Megapack of Commands",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};



/***
 * This core file doesn't do a lot, but is the only file that includes
 * the translation and config files as part of the updater download, and sets the version cvar.
 *
 * As such, this is the ONLY required file.
 ***/
public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  RegAdminCmd("sm_sfpplugincheck", LoadCheck, ADMFLAG_ROOT, "Check which Satan's Fun Pack Modules are Installed");
  PrintToServer("%T", "SFP_Loaded", LANG_SERVER);
}


public Action LoadCheck(int client, int args)
{
  char path[PLATFORM_MAX_PATH], outStr[128];
  bool result;

  // Check each file
  BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/sfp_admintools.smx");
  result = FileExists(path);
  Format(outStr, sizeof(outStr),
    "MODULE - STATUS\n----------------\nAdminTools - %s", (result) ? "Loaded\n" : "NOT LOADED\n");

  PrintToConsole(client, outStr);
  if(client != 0 && GetCmdReplySource() == SM_REPLY_TO_CHAT)
    ReplyStandard(client, "%T", "SFP_ConsoleOutput", client);

  return Plugin_Handled;
}
