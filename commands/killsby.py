#!/usr/bin/python

import sys, re
from helper import *

help("Lists the top 10 player kills for a given monster.")

monster = sys.argv[3]
strip_first_word = re.compile(r'^\S+\s+')
monster = strip_first_word.sub('',sys.argv[3])
    
kills = kills_by(monster)
if not kills:
    print "That monster has never killed anyone!"
    sys.exit()

killed = []
uniq_killed = [] 
for kill in kills:
    killed.append(kill['name'])
    if kill['name'] not in uniq_killed:
        uniq_killed.append(kill['name'])
try:
    monster = kills[0]['killer']
except KeyError:
    monster = kills[0]['ktyp']
if len(kills) == 1: killstring = "1 kill"
else: killstring = "%s kills" % str(len(kills))

uniq_killed.sort(lambda x,y: cmp(killed.count(y),killed.count(x)) or cmp(x,y))
freqstring = ''
numstats = 0
for kill in uniq_killed:
    if numstats > 9:
        break
    numstats +=1
    freqstring += "%dx %s(%.2f%%) " % (killed.count(kill), kill, 
            100*killed.count(kill)/float(len(kills)))
print("%s by %s. Most frequent: %s" % (killstring, monster, freqstring))
