#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings

#include <satansfunpack>  // Shared function library


//=================================
// Constants
#define PLUGIN_VERSION  "0.0.1"
#define PLUGIN_URL      "UNDEFINED"
#define UPDATE_URL      "UNDEFINED" // NOTE Unique update file per compiled plugin.


public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun Pack - Quick Conditions",
  author =      "SirDigby",
  description = "Easy-Access Superpowers",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};



public void OnPluginStart()
{
  LoadTranslations("satansfunpack.phrases");
  RegAdminCmd("sm_boing", CMD_Boing, ADMFLAG_BAN, "Bouncy + Pew Pew");
  RegAdminCmd("sm_dancemonkey", CMD_Dance, ADMFLAG_BAN, "Use this before shooting near a player's feet");

  PrintToServer("%T", "SFP_QuickConditionsLoaded", LANG_SERVER);
}


/**
 * Give player infinite jumps and double fire rate.
 * (Cond 72/TFCond_HalloweenSpeedBoost)
 *
 * sm_boing [Target] <1/0/On/Off>
 */
public Action CMD_Boing(int client, int args)
{
  if(args < 1)
  {
    ReplyUsage(client, "%T", "SM_BOING_Usage", client);
    return Plugin_Handled;
  }

  char state[8];
  char targ_name[MAX_TARGET_LENGTH];
  int targ_list[MAXPLAYERS], targ_count;
  bool tn_is_ml;

  if(args == 1)
  {
    GetCmdArg(1, state, sizeof(state));
    targ_count = 1;
    targ_list[0] = client;
  }
  else if(args > 1)
  {
    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(2, state, sizeof(state));
    GetCmdArg(1, arg1, sizeof(arg1));

    // Get Target List
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


  bool bState = false;

  if(StrEqual(state, "off", false) || StrEqual(state, "0", true))
    bState = true;
  else if(StrEqual(state, "on", false) || StrEqual(state, "1", true))
    bState = false;


  if(bState)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_AddCondition(targ_list[i], TFCond_HalloweenSpeedBoost, TFCondDuration_Infinite, 0);
      ReplyStandard(targ_list[i], "%T", "SM_BOING_On", targ_list[i]);
    }
  }
  else
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_RemoveCondition(targ_list[i], TFCond_HalloweenSpeedBoost);
      ReplyStandard(targ_list[i], "%T", "SM_BOING_Off", targ_list[i]);
    }
  }

  return Plugin_Handled;
}


/**
 * Force player into the thriller-taunt-lock state
 * (Cond 54/TFCond_HalloweenThriller)
 *
 * sm_dancemonkey <Target> <Duration/0/Stop/End/Off>
 */
public Action CMD_Dance(int client, int args)
{
  if(args < 2)
  {
    ReplyUsage(client, "%T", "SM_DANCE_Usage", client);
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[16];
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));

  // Get Target List
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

  // Process arg2/duration
  int iArg2;
  if(StrEqual(arg2, "stop", false)
  || StrEqual(arg2, "end", false)
  || StrEqual(arg2, "off", false)
  || StrEqual(arg2, "0", true))
  {
    iArg2 = -1;
  }
  else
  {
    iArg2 = StringToInt(arg2);
  }

  if(iArg2 > 0)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_AddCondition(targ_list[i], TFCond_HalloweenThriller, view_as<float>(iArg2), 0);
      ReplyStandard(targ_list[i], "%T", "SM_DANCE_On", targ_list[i]);
    }
  }
  else if (iArg2 < 0)
  {
    for(int i = 0; i < targ_count; ++i)
    {
      TF2_RemoveCondition(targ_list[i], TFCond_HalloweenThriller);
      ReplyStandard(targ_list[i], "%T", "SM_DANCE_Off", targ_list[i]);
    }
  }
  else // if iArg2 = 0; if It's not "stop" and not an int above 0
    ReplyUsage(client, "%T", "SM_DANCE_Usage", client);

  return Plugin_Handled;
}
