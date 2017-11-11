#if defined _sfp_shared_included
  #endinput
#endif
#define _sfp_shared_included

#define MAX_BOOLSTRING_LENGTH 8           // "disable" + \0
#define STANDARD_TAG "\x04[SM]\x01 "
#define MAX_SLOTSTRING_LENGTH 10          // "secondary" + \0
#define CONFIG_SIZE PLATFORM_MAX_PATH+13  // 13 = "configs/" + ".cfg" + \0

#include <tf2_stocks>

enum TF_Slot_Index // Because tf2_stocks has no invalid option.
{
	TF_Slot_Invalid    = -1,
	TF_Slot_Primary    = TFWeaponSlot_Primary,
	TF_Slot_Secondary  = TFWeaponSlot_Secondary,
	TF_Slot_Melee      = TFWeaponSlot_Melee,
	TF_Slot_Grenade    = TFWeaponSlot_Grenade,
	TF_Slot_Building   = TFWeaponSlot_Building,
	TF_Slot_PDA        = TFWeaponSlot_PDA,
	TF_Slot_Item1      = TFWeaponSlot_Item1,
	TF_Slot_Item2      = TFWeaponSlot_Item2,
	TF_Slot_AllWeapons // SPECIFICALLY MEANS Primary + Secondary + Melee
}


/**
 * Wraps ReplyToCommand with a coloured tag for command syntax.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
stock void TagReplyUsage(int client, const char[] msg, any ...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  ReplyToCommand(client, "\x04[SM]\x05 Usage\x01: %s", outStr);
  // FIXME Does this process translation?
  return;
}


/**
 * Wraps ReplyToCommand with a coloured tag.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
stock void TagReply(int client, const char[] msg, any...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  ReplyToCommand(client, "%s%s", STANDARD_TAG, outStr);
  return;
}


/**
 * Wraps PrintToChat with a coloured tag.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
stock void TagPrintChat(int client, const char[] msg, any...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  PrintToChat(client, "%s%s", STANDARD_TAG, outStr);
  return;
}


/**
 * Wraps ShowActivity2 with a coloured tag.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
stock void TagActivity(int client, const char[] msg, any ...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  ShowActivity2(client, STANDARD_TAG, "%s", outStr);
  return;
}


/**
 * Check if a client is actually in the game playing.
 * IsClientObserver will be true if they are dead, too.
 *
 * @param client    Client who issued command
 * @param bObserver Optional. Allow client if they are Observer/Spectator
 * @param bReplay	  Optional. Allow client if they are Replay bot
 * @param bSourceTV Optional. Allow client if they are SourceTV bot
 */
stock bool IsClientPlaying(int iClient,
  bool bAllowObserver=false,
  bool bAllowReplay=false,
  bool bAllowSourceTV=false,
  bool bAllowCoach=false)
{
  if(iClient <= 0 || iClient > MaxClients)
    return false;
  if(!IsClientInGame(iClient))
    return false;
  if(!bAllowObserver && IsClientObserver(iClient))
    return false;
  if(!bAllowReplay && IsClientReplay(iClient))
    return false;
  if(!bAllowSourceTV && IsClientSourceTV(iClient))
    return false;
  if(!bAllowCoach && GetEntProp(iClient, Prop_Send, "m_bIsCoaching"))
    return false;
  return true;
}


/**
 * Get the bool value of an string with a variety of checks.
 *
 * @param str       String to check
 * @param bool      Case-sensitive checking, lowercase only.
 * @param bool      Optional. Check for "1" and "0"
 * @param bool      Optional. Check for "on" and "off"
 * @param bool      Optional. Check for "enable" and "disable"
 * @param bool      Optional. Check for "yes" and "no"
 * @return int      Returns a three-point bool state: 1, 0 or -1 on invalid.
 */
stock int GetStringBool(const char[] str,
  bool bUseLowerCaseOnly,
  bool bBinary=false,
  bool bOnOff=false,
  bool bEnableDisable=false,
  bool bYesNo=false)
{
  if(bBinary)
  {
    if(StrEqual(str, "1", true))
      return 1;
    if(StrEqual(str, "0", true))
      return 0;
  }
  if(bOnOff)
  {
    if(StrEqual(str, "on", bUseLowerCaseOnly))
      return 1;
    if(StrEqual(str, "off", bUseLowerCaseOnly))
      return 0;
  }
  if(bEnableDisable)
  {
    if(StrEqual(str, "enable", bUseLowerCaseOnly))
      return 1;
    if(StrEqual(str, "disable", bUseLowerCaseOnly))
      return 0;
  }
  if(bYesNo)
  {
    if(StrEqual(str, "yes", bUseLowerCaseOnly))
      return 1;
    if(StrEqual(str, "no", bUseLowerCaseOnly))
      return 0;
  }
  return -1;
}


/**
 * Convert 6-digit Hex Number into RGB.
 *
 * @param hexStr      Hex string to check.
 * @param RedOut      Integer to store Red value in.
 * @param GreenOut    Integer to store Green value in.
 * @param BlueOut     Integer to store Blue value in.
 * @return bool       Returns true if successful, false if not.
 */
stock bool HexToRGB(const char[] hexStr, int &RedOut, int &GreenOut, int &BlueOut)
{
  if(strlen(hexStr) != 6)
    return false;

  char redStr[3], greenStr[3], blueStr[3];

  strcopy(redStr,   sizeof(redStr),   hexStr);
  strcopy(greenStr, sizeof(greenStr), hexStr[2]);
  strcopy(blueStr,  sizeof(blueStr),  hexStr[4]);

  RedOut    = StringToInt(redStr, 16);
  GreenOut  = StringToInt(greenStr, 16);
  BlueOut   = StringToInt(blueStr, 16);
  return true;
}


/**
 * Convert 8-digit Hex Number into RGBA.
 *
 * @param hexStr      Hex string to check.
 * @param RedOut      Integer to store Red value in.
 * @param GreenOut    Integer to store Green value in.
 * @param BlueOut     Integer to store Blue value in.
 * @param AlphaOut    Integer to store Alpha value in.
 * @return bool       Returns true if successful, false if not.
 */
stock bool HexToRGBA(const char[] hexStr, int &RedOut, int &GreenOut, int &BlueOut, int &AlphaOut)
{
  if(strlen(hexStr) != 8)
    return false;

  char redStr[3], greenStr[3], blueStr[3], alphaStr[3];

  strcopy(redStr,   sizeof(redStr),   hexStr);
  strcopy(greenStr, sizeof(greenStr), hexStr[2]);
  strcopy(blueStr,  sizeof(blueStr),  hexStr[4]);
  strcopy(alphaStr, sizeof(alphaStr), hexStr[6]);

  RedOut    = StringToInt(redStr, 16);
  GreenOut  = StringToInt(greenStr, 16);
  BlueOut   = StringToInt(blueStr, 16);
  AlphaOut  = StringToInt(alphaStr, 16);
  return true;
}


/**
 * Check if integer is between 0 and 255.
 *
 * @param red         Int value for red component.
 * @param green       Int value for green component.
 * @param blue        Int value for blue component.
 * @return bool       Returns true if successful, false if not.
 */
stock bool IsColourRGB(const int red, const int green, const int blue)
{
  if(red < 0 || red > 255)
    return false;
  if(green < 0 || green > 255)
    return false;
  if(blue < 0 || blue > 255)
    return false;
  return true;
}


/**
 * Check if integer is between 0 and 255.
 *
 * @param red         Int value for red component.
 * @param green       Int value for green component.
 * @param blue        Int value for blue component.
 * @param alpha       Int value for alpha component.
 * @return bool       Returns true if successful, false if not.
 */
stock bool IsColourRGBA(const int red, const int green, const int blue, const int alpha)
{
  if(red < 0 || red > 255)
    return false;
  if(green < 0 || green > 255)
    return false;
  if(blue < 0 || blue > 255)
    return false;
  if(alpha < 0 || alpha > 255)
    return false;
  return true;
}


/**
 * Get a weapon slot index. Specifically for weapons.
 *
 * @param str             String to check.
 * @return TF_Slot_Index  Returns weapon slot index or TF_Slot_Invalid
 */
stock TF_Slot_Index GetWeaponSlotIndex(const char[] str)
{
  if(StrEqual(str, "1", true) || StrEqual(str, "primary", false))
    return TF_Slot_Primary;
  else if(StrEqual(str, "2", true) || StrEqual(str, "secondary", false))
    return TF_Slot_Secondary;
  else if(StrEqual(str, "3", true) || StrEqual(str, "melee", false))
    return TF_Slot_Melee;
  else if(StrEqual(str, "all", false))
    return TF_Slot_AllWeapons; // All 3 of the above.
  return TF_Slot_Invalid;
}

/**
 * Flagbit Shorthands
 */
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
