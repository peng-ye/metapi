#!/usr/bin/env python

import os 
import sys
import subprocess


with os.scandir(sys.argv[1]) as itr:
    i = 0
    for entry in itr:
        bin_id, suffix = os.path.splitext(entry.name)
        if suffix == "." + sys.argv[2]:
            i += 1
            subprocess.run('''mv %s %s''' \
                  % (os.path.join(sys.argv[1], entry.name),
                     os.path.join(sys.argv[3] + "." + str(i) + "." + sys.argv[2])), shell=True)

