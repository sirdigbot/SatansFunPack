#if defined _sfp_shared_included
  #endinput
#endif
#define _sfp_shared_included

#define MAX_BOOLSTRING_LENGTH 8           // "disable" + \0
#define STANDARD_TAG          "\x04[SM]\x01 "
#define CONSOLE_TAG           "[SM] "
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
 * Check if a string is a valid hex code.
 *
 * @param str       String to check.
 * @return bool     If str is valid 6-digit hex
 */
stock bool IsValid6DigitHex(const char[] str)
{
  if(strlen(str) != 6)
    return false;

  bool result = true;
  for(int i = 0; i < 6; ++i)
  {
    // If char is not in valid hex range, break
    if(!(str[i] >= 0x30 && str[i] <= 0x39)  // 0-9
    && !(str[i] >= 0x41 && str[i] <= 0x46)  // A-F
    && !(str[i] >= 0x61 && str[i] <= 0x66)) // a-f
    {
      result = false;
      break;
    }
  }
  return result;
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
 * Get the class contained in a given string. Shorthand or nicknames not supported.
 *
 * @param str             String to check.
 * @param acceptIndex     Check for 1-based class indexes.
 * @return TFClassType    Returns the specified class type or TFClass_Unknown if invalid.
 */
stock TFClassType GetClassFromString(const char[] str, const bool acceptIndex=false, const bool caseSensitive=false)
{
  if(StrEqual(str, "Scout", caseSensitive) || (acceptIndex && StrEqual(str, "1", true)))
    return TFClass_Scout;
  else if(StrEqual(str, "Soldier", caseSensitive) || (acceptIndex && StrEqual(str, "2", true)))
    return TFClass_Soldier;
  else if(StrEqual(str, "Pyro", caseSensitive) || (acceptIndex && StrEqual(str, "3", true)))
    return TFClass_Pyro;
  else if(StrEqual(str, "Demoman", caseSensitive) || StrEqual(str, "Demo", caseSensitive) || (acceptIndex && StrEqual(str, "4", true)))
    return TFClass_DemoMan;
  else if(StrEqual(str, "Heavy", caseSensitive) || (acceptIndex && StrEqual(str, "5", true)))
    return TFClass_Heavy;
  else if(StrEqual(str, "Engineer", caseSensitive) || StrEqual(str, "Engie", caseSensitive)  || (acceptIndex && StrEqual(str, "6", true)))
    return TFClass_Engineer;
  else if(StrEqual(str, "Medic", caseSensitive) || (acceptIndex && StrEqual(str, "7", true)))
    return TFClass_Medic;
  else if(StrEqual(str, "Sniper", caseSensitive) || (acceptIndex && StrEqual(str, "8", true)))
    return TFClass_Sniper;
  else if(StrEqual(str, "Spy", caseSensitive) || (acceptIndex && StrEqual(str, "9", true)))
    return TFClass_Spy;
  
  return TFClass_Unknown;
}

/**
 * Get a translated class name for a given client.
 *
 * @param class           The class type to translate.
 * @param buffer          The output string buffer.
 * @param maxlength       The size of the output string buffer.
 * @param client          The client index to translate for (or LANG_SERVER).
 * @return bool           True if class name was translated. False if otherwise.
 */
stock bool GetTranslatedClassName(const TFClassType class, char[] buffer, const int maxlength, const int client=LANG_SERVER)
{
  switch(class)
  {
    case TFClass_Scout:     Format(buffer, maxlength, "%T", "SFP_Scout", client);
    case TFClass_Soldier:   Format(buffer, maxlength, "%T", "SFP_Soldier", client);
    case TFClass_Pyro:      Format(buffer, maxlength, "%T", "SFP_Pyro", client);
    case TFClass_DemoMan:   Format(buffer, maxlength, "%T", "SFP_Demoman", client);
    case TFClass_Heavy:     Format(buffer, maxlength, "%T", "SFP_Heavy", client);
    case TFClass_Engineer:  Format(buffer, maxlength, "%T", "SFP_Engineer", client);
    case TFClass_Medic:     Format(buffer, maxlength, "%T", "SFP_Medic", client);
    case TFClass_Sniper:    Format(buffer, maxlength, "%T", "SFP_Sniper", client);
    case TFClass_Spy:       Format(buffer, maxlength, "%T", "SFP_Spy", client);
    default: return false;
  }
  return true;
}

/**
 * Get the base HP for a given class type
 */
stock int GetClassBaseHP(const TFClassType classType)
{
  switch(classType)
  {
    case TFClass_Scout:     return 125;
    case TFClass_Soldier:   return 200;
    case TFClass_Pyro:      return 175;
    case TFClass_DemoMan:   return 175;
    case TFClass_Heavy:     return 300;
    case TFClass_Engineer:  return 125;
    case TFClass_Medic:     return 150;
    case TFClass_Sniper:    return 125;
    case TFClass_Spy:       return 125;
  }
  return 125;
}

/**
 * Flagbit 'Shorthands'
 */
stock void AddFlag(int &val, const int flag)
{
  val |= flag;
  return;
}

stock void RemFlag(int &val, const int flag)
{
  val &= ~flag;
  return;
}

stock bool HasFlag(const int val, const int flag)
{
  return view_as<bool>((val & flag != 0));
}



/**
 * Set a player's health. For TF2 only.
 * Supposedly, using SetEntityHealth can cause crashing
 *
 * @param client    Client index to set health on
 * @param health    Amount to set
 */
stock void TF2_SetHealth(const int client, const int health)
{
  SetEntProp(client, Prop_Send, "m_iHealth", health);
  SetEntProp(client, Prop_Data, "m_iHealth", health);
  return;
}


/**
 * Limit an integer between a minimum and a maximum
 * @param val       Value to limit
 * @param min       Lower bound of limit
 * @param max       Upper bound of limit
 */
stock void ClampInt(int &val, const int min, const int max)
{
  if(val < min)
    val = min;
  else if(val > max)
    val = max;
  return;
}
