#!/usr/bin/env python3


# Convert the Custom Chat Colours Menu (and old satansfunpack_colours.cfg)
# to the new minimal config style for sfp_namecolours
# CCC Menu -- https://forums.alliedmods.net/showthread.php?p=1825772

import sys

if len(sys.argv) < 2:
  print("colourcfg.py <config file>\n  OR\nDrag the config file onto the script.")
  input("Press enter to close..\n\n")
else:
  with open("ColourCfgOut.txt", "w") as out_file:
    out_dict  = {}
    dupes     = 0
    
    with open(sys.argv[1], "r") as in_file:
      lines = in_file.read().splitlines()
      
      for x in range(0, len(lines)):
        nameline = lines[x].strip()
        
        if nameline.startswith('"name"'):
          nameline  = nameline[6:].strip()            # Remove "name"<whitespace>
          hexline   = lines[x+1].strip()[5:].strip()  # Remove <ws>"hex"<ws>; hexline is below nameline
          
          # Remove quotes (breaks dictionary)
          nameline = nameline.replace('"', '')
          hexline = hexline.replace('"', '')[1:]      # Also remove '#' prefix
          
          if out_dict.get(nameline):
            print("[Line %d] Duplicate Name: '%s'" % (x, nameline))
            dupes += 1
          elif hexline in out_dict.values():
            print("[Line %d] Duplicate Hex: '%s'" % (x, hexline))
            dupes += 1
          
          # Always add duplicates.
          # Because of pythons keys, duplicate names arent always errors.
          # And you should decide which duplicate hex you'd prefer to keep based on name.
          
          out_dict[nameline] = hexline
            
    for key in out_dict:
      # Add beautiful column spacing and quotes marks
      out_file.write("{0:<30}{1:<}\n".format('"' + key + '"', '"' + out_dict[key] + '"'))
    
    # Pause prompt if dupes were found so you can read it in case of drag-and-drop
    if dupes > 0:
      input("Duplicates Found. Press enter to close..\n\n")
