#!/usr/bin/python

import sys, re
from helper import *

help("Lists the top ten kills for a player's ghost.")

ghost = sys.argv[1]
kills = kills_by("%ss ghost" % ghost)
if len(kills) == 0:
    print "That ghost has never killed anyone!"
    sys.exit()

killed = []
uniq_killed = [] 
for kill in kills:
    killed.append(kill['name'])
    if kill['name'] not in uniq_killed:
        uniq_killed.append(kill['name'])
if len(kills) == 1: killstring = "1 kill"
else: killstring = str(len(kills)) + " kills"

uniq_killed.sort(lambda x,y: cmp(killed.count(y),killed.count(x)) or cmp(x,y))
freqstring = ''
numstats = 0
for kill in uniq_killed:
    if numstats > 9:
        break
    numstats +=1
    freqstring += "%dx %s(%.2f%%) " % (killed.count(kill), kill, 
            100*killed.count(kill)/float(len(kills)))
print("%s by %s's ghost. Most frequent: %s" % (killstring, ghost, freqstring))
