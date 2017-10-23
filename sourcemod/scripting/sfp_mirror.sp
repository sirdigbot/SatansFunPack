#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings


//=================================
// Global
Handle  h_bUpdate = null;
bool    g_bUpdate;


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://github.com/sirdigbot/satansfunpack"
#define UPDATE_URL      "https://sirdigbot.github.io/SatansFunPack/sourcemod/mirror_update.txt"


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Mirror",
  author =      "SirDigby",
  description = "Stop Hitting Yourself",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};



public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");

  h_bUpdate = FindConVar("sm_satansfunpack_update");
  if(h_bUpdate == null)
    SetFailState("%T", "SFP_UpdateCvarFail", LANG_SERVER);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);

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
