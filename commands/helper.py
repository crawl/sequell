#!/usr/bin/python

from __future__ import print_function

import string, re, os, sys
import os.path
from glob import glob
import yaml
from datetime import datetime
import time

CFGFILE = os.path.join(os.environ['HENZELL_ROOT'], 'config/crawl-data.yml')
CFG = yaml.load(open(CFGFILE).read())

xkeychars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'

adjective_skills = \
  dict( [ (title, True) for
          title in [ 'Deadly Accurate', 'Spry', 'Covert', 'Unseen' ] ] )

adjective_end = re.compile(r'(?:ed|ble|ous|id)$')

SPECIES_MAP = CFG['species']
SPECIES = SPECIES_MAP.values()
SPECIES_ABBR = SPECIES_MAP.keys()

ROLE_MAP = CFG['classes']
ROLES = ROLE_MAP.values()
ROLES_ABBR = ROLE_MAP.keys()

WHERE_DIRS = None

class Tournament (object):
    def __init__(self, data):
        self.data = data

    def start_date(self):
        return self.date_from_string(self.raw_start_date())

    def end_date(self):
        return self.date_from_string(self.raw_end_date())

    def game_version(self):
        ver = self.data['version']
        if isinstance(ver, list):
            return ver[0]
        return ver

    def date_from_string(self, raw_date_string):
        date_string = str(raw_date_string).ljust(14, '0')
        return datetime(*(time.strptime(str(date_string), '%Y%m%d%H%M%S')[0:6]))

    def raw_start_date(self):
        return self.raw_time_range()[0]

    def raw_end_date(self):
        return self.raw_time_range()[1]

    def raw_time_range(self):
        return self.data['time']

def tourney_data():
    return CFG['tournament-data'] or { }

def default_tourney_name():
    return tourney_data()['default-tourney']

def default_tourney(game_type='crawl'):
    return Tournament(tourney_data()[game_type][default_tourney_name()])

def plural(int):
    if int > 1:
        return 's'
    else:
        return ''

def ntimes(times):
    if times == 1: return 'once'
    elif times == 2: return 'twice'
    elif times == 3: return 'thrice'
    else: return str(times) + ' times'

def strip_extension(name):
    dotind = name.rfind('.')
    return dotind == -1 and name or name[0 : dotind]

def once(times):
    if times == 1: return 'once'
    elif times == 2: return 'twice'
    elif times == 3: return 'thrice'
    else: return str(times)

def replace(string, toreplace, replacewith):
    while string.count(toreplace) > 0:
        string = string[:string.index(toreplace)] + replacewith + string[string.index(toreplace) + len(toreplace):]
    return string

def parse_argstring(argstring): # Takes a string of everything after !cmd.
    arglist = []
    if not argstring:
        return [], {}
    if argstring.count('"') % 2:
        print("Missing a quote mark?")
        sys.exit()
    if argstring.count('"') == 0:
        arglist = argstring.split(' ')
    else:
        i = 0
        quotelist = argstring.split('"')
        for string in quotelist:
            if not i % 2 and string: # if this is outside of quotes and exists
                list = string.split(' ')
                if not list[0]:
                    list = list[1:]
                # join the quoted material with the string before it
                if len(quotelist) > i + 1:
                    list[-1] = ''.join([list[-1], quotelist[i + 1]])
                    arglist.extend(list)
            i += 1
    # Now we have the One True Arglist. parse using parse_argslist.
    return parse_argslist(arglist)

def parse_argslist(argslist):
    # Takes a list of everything after the !command. (sys.argv[3].split(' ')[1:]
    # Returns args, opts
    args = []
    opts = []
    optlist = []
    if len(argslist) == 1 and len(argslist[0]) == 0:
        return args, dict(opts)
    for arg in argslist:
        if arg[0] == '-':
            optlist.append(arg[1:])
        else:
            args.append(string.lower(arg))
    for opt in optlist:
        opt = string.lower(opt)
        if '=' in opt and opt.split('=')[0] and opt.split('=')[1]:
            opts.append(tuple(opt.split('=')[:2]))
        else:
            opts.append((opt, ''))
    return args, dict(opts)

def help(helpstring):
    if sys.argv[4]:
        print(helpstring)
        sys.exit()
