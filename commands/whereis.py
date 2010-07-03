#!/usr/bin/python

import os.path
import sys
from helper import *

help('Lists where a player currently is in the dungeon.')
rawdatapath = '/var/www/crawl/rawdata/'

nick = sys.argv[1]

# games_for doesn't know about players playing their first game.
# this could probably be corrected by making the check just for the
# whereis file, since if there's no file, it's not like the requestor
# is going to get any useful information. But there might be a good
# reason not to do this, so I didn't make the change. -rachel 12/22/07

def where_file(nick):
    return (rawdatapath + '%s/%s.where') % (nick, nick)

aliases = canonical_aliases(nick)
aliases = [ x for x in aliases if os.path.exists(where_file(x)) ]

if not aliases:
    print("No games for %s." % sys.argv[1])
    sys.exit()

def where_mtime(nick):
    return os.path.getmtime(where_file(nick))

def most_recent_where_nick(aliases):
    most_recent = None
    chosen = None
    for alias in aliases:
        mt = where_mtime(alias)
        if not chosen or mt > chosen:
            chosen = mt
            most_recent = alias
    return most_recent

nick = most_recent_where_nick(aliases)

try:
    whereline = open(where_file(nick)).readlines()[0][:-1]
except IOError:
    print("No where info for %s." % nick)
    sys.exit()

details = demunge_xlogline(whereline)
version = details['v']
if ':' in details['place']:
    prep = 'on'
else:
    prep = 'in'
prestr = godstr = datestr = turnstr_suffix = turnstr = ''
try:
    godstr = ', a worshipper of %s,' % details['god']
except KeyError:
    godstr = ''
try:
    month = str(int(details['time'][4:6]) + 1)
    if len(month) < 2:
        month = '0' + month
    datestr = ' on %s-%s-%s' % (details['time'][0:4], month,
                                details['time'][6:8])
except KeyError:
    datestr = ''
nturns = int(details['turn'])
status = details['status']
if int(details['turn']) != 1:
    turnstr_suffix = 's'
turnstr = ' after %d turn%s' % (int(details['turn']), turnstr_suffix)
prestr = status
if status == 'saved':
    prestr = 'last saved'
elif status == 'active':
    prestr = 'is currently'
    datestr = ''

sktitle = game_skill_title(details)
print("%s the %s (L%s %s)%s %s %s %s%s%s." %
      (nick, sktitle, details['xl'], details['char'],
       godstr, prestr, prep, replace(details['place'], ';', ':'),
       datestr, turnstr))
