#!/usr/bin/python
import string, re, os, sys
import os.path
from glob import glob
import yaml
from datetime import datetime
import time

CFGFILE = 'commands/crawl-data.yml'
CFG = yaml.load(open(CFGFILE).read())

www_rawdatapath = '/var/www/crawl/rawdata/'

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

NICK_ALIASES = { }
NICKMAP_FILE = 'nicks.map'
nick_aliases_loaded = False

class Tournament (object):
    def __init__(self, data):
        self.data = data

    def start_date(self):
        return self.date_from_string(self.raw_start_date())

    def end_date(self):
        return self.date_from_string(self.raw_end_date())

    def game_version(self):
        return self.data['version']

    def date_from_string(self, date_string):
        return datetime(*(time.strptime(str(date_string), '%Y%m%d')[0:6]))

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

def game_skill_title(game):
    title = game['title']
    turns = game['turn']
    if int(turns) < 200000:
        return title
    else:
        return game_skill_farming(title)

def skill_title_is_adjective(title):
    return adjective_skills.has_key(title) or adjective_end.search(title)

def game_skill_farming(title):
    if skill_title_is_adjective(title):
        return title + " Farmer"
    else:
        return "Farming " + title

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

def canonicalize_nick(nick):
    global WHERE_DIRS
    if WHERE_DIRS is None:
        WHERE_DIRS = [ f for f in glob(www_rawdatapath + '/*')
                       if os.path.isdir(f) ]
    lnickw = '/' + nick.lower()
    match = [ x for x in WHERE_DIRS if x.lower().endswith(lnickw) ]
    return len(match) > 0 and extract_nick_from_wherepath(match[0]) or None

def canonicalize_nicks(nicks):
    return [ n for n in [ canonicalize_nick(x) for x in nicks ] if n ]

def extract_nick_from_wherepath(wherepath):
    windex = wherepath.rfind('/')
    if windex == -1:
	return None
    where = wherepath[windex + 1 : ]
    if os.path.isfile(wherepath + '/' + where + '.where'):
    	return where

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

def munge_game(game):
    logline = ''
    for detail in details_names:
        try:
            game[detail] # try to catch a keyerror early
            logline += detail + '=' + str(game[detail]).replace(':', '::') + ':'
        except KeyError:
            continue

    logline = logline[:-1]
    return logline

def demunge_xlogline(logline):
    if not logline:
        return {}
    if logline[0] == ':' or (logline[-1] == ':' and not logline[-2] == ':'):
        sys.exit(1)
    if '\n' in logline:
        sys.exit(1)
    logline = replace(logline, "::", "\n")
    details = dict([(item[:item.index('=')], item[item.index('=') + 1:]) for item in logline.split(':')])
    for key in details:
        for char in key:
            if char not in xkeychars:
                sys.exit(1)
        details[key] = replace(details[key], "\n", ":")
    return details

def deathstring(game):
    deathstring = ''
    if game['death_type']:
        deathstring = death_methods[game['death_type']]
        if game['death_source_name']:
            deathstring += " - %s" % game['death_source_name']
    else:
        deathstring = "killed by %s" % game['death_source_name']
    if game['auxkilldata']:
        deathstring += " (%s)" % game['auxkilldata']
    return deathstring

def serialize_time(s):
    return '%d:%02d:%02d' % (s/60/60%60, s/60%60, s%60)

def help(helpstring):
    if sys.argv[4]:
        print helpstring
        sys.exit()

def load_nick_aliases():
    global nick_aliases_loaded
    if nick_aliases_loaded:
        return NICK_ALIASES
    nick_aliases_loaded = True
    if os.path.exists(NICKMAP_FILE):
        for line in open(NICKMAP_FILE).readlines():
            nicks = line.split()
            if len(nicks) > 1:
                NICK_ALIASES[nicks[0].lower()] = " ".join(nicks[ 1 : ])
    return NICK_ALIASES

def nick_aliases(nick):
    load_nick_aliases()
    alias = NICK_ALIASES.get(nick.lower())
    if alias:
        return alias.split()
    else:
        return [ nick ]

def canonical_aliases(nick):
    return canonicalize_nicks(nick_aliases(nick))

def nick_alias(nick):
    return nick_aliases(nick)[0]
