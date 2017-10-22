#if defined _sfp_shared_included
  #endinput
#endif
#define _sfp_shared_included

/**
 * Wraps ReplyToCommand with common coloured tags
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
stock void ReplyUsage(int client, const char[] msg, any ...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  ReplyToCommand(client, "\x04[SM]\x05 Usage\x01: %s", outStr);
  // FIXME Does this process translation?
  return;
}

stock void ReplyStandard(int client, const char[] msg, any...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  ReplyToCommand(client, "\x04[SM]\x01 %s", outStr);
  return;
}

stock void ReplyActivity(int client, const char[] msg, any ...)
{
  int len = strlen(msg) + 255;
  char[] outStr = new char[len];
  VFormat(outStr, len, msg, 3);

  ShowActivity2(client, "\x04[SM]\x01 ", msg);
  return;
}
