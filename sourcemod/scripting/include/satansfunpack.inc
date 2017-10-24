#if defined _sfp_shared_included
  #endinput
#endif
#define _sfp_shared_included

#define MAX_BOOLSTRING_LENGTH 7
#define STANDARD_TAG "\x04[SM]\x01"

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

  ReplyToCommand(client, "%s %s", STANDARD_TAG, outStr);
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

  PrintToChat(client, "%s %s", STANDARD_TAG, outStr);
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

  ShowActivity2(client, "%s %s", STANDARD_TAG, msg);
  return;
}


/**
 * Check if a client is actually in the game playing.
 *
 * @param client    Client who issued command
 * @param bReplay	  Optional. Check if client is Replay bot
 * @param bSourceTV Optional. Check if client is SourceTV bot
 */
stock bool IsClientPlaying(int iClient, bool bReplay=false, bool bSourceTV=false)
{
  if(iClient <= 0) // TODO: Can we check MaxClients out of a plugin?
    return false;
  if(!IsClientInGame(iClient))
    return false;
  if(bReplay && !IsClientReplay(iClient))
    return false;
  if(bSourceTV && !IsClientSourceTV(iClient))
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
