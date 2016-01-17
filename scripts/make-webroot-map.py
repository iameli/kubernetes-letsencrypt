#!/usr/bin/env python

# I didn't want to write this part in bash.
import json
import sys
out = {}
for arg in sys.argv[1:]:
  out[arg] = '/app/webroot'
print json.dumps(out)
