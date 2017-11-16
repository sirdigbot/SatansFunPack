#!/usr/bin/env python3

# Drag and drop text file with list of commands (1 per line)
# and output Help-Menu-ready KeyValues format

# sm_somecmd 
#   --->
# "1"
# {
#   "text"  "sm_somecmd"
#   "flags" "text"
# }

import sys

if len(sys.argv) < 2:
  print("Drag text file onto python script")
  input("Press enter to close\n\n")
else:
  i = 1   # 0 is reserved for command help text
  with open("HelpMenuCfg.txt", "w") as outFile:
      with open(sys.argv[1], "r") as inFile:
          for line in inFile:
              if line.rstrip(): # if not empty
                  outFile.write('"' + str(i) + '"\n{\n  "text"  "' + line.rstrip() + '"\n  "flags" "text"\n}\n')
                  i += 1
