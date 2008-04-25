#!/usr/bin/python
import sys, string
import re
from helper import *
 
help("Expands race/role abbreviations. Example usage: !wtf TrBe")
#ABBREV_FILE = 'abbrev.txt'
ABBREV_FILE = ''
 
def expand_any(what, lookup, expanded):
    if what in lookup:
        return expanded[ lookup.index(what) ]
    else:
        llookup = [ x.lower() for x in lookup ]
        lwhat = what.lower()
        if lwhat in llookup:
            return expanded[ llookup.index(lwhat) ]
    return None
 
def expand_race(what):
    return expand_any(what, races_abbrev, races)
 
def expand_role(what):
    return expand_any(what, roles_abbrev, roles)
 
def expand(what):
    if what == '': return [ 'WTF?' ]
    if what.lower() == 'wtf': return [ 'WTFF!' ]
 
    args = re.findall(r'(?i)([a-z]{2})', what) or [ what ]
    if len(args) >= 2:
        ans = [expand_race(args[0]) or 'Unperson', 
               expand_role(args[1]) or 'Unemployed']
        if ans[1] == 'Unemployed': ans.reverse()
        return ans
    elif len(args) == 1:
        return [ ' or '.join( [
            x for x in (expand_race(args[0]), expand_role(args[0])) if x ] ) or
            'WTF was that? Unthing!' ]
 
def split_abbr_line(line):
    return [ x.strip() for x in 
             re.match(r'\s*(\S.*?\S)\s*=\s*(.*)', line).groups() ]
 
def load_abbrevs(file):
    misc = { }
    try:
        for line in open(file):
            abbr, exp = split_abbr_line(line)
            misc[abbr] = exp
    except IOError:
        pass
    return misc
 
def save_abbrevs(file, abbr):
    f = open(file, 'w')
    for key in abbr:
        if abbr[key].strip():
            f.write("%s=%s\n" % (key, abbr[key]))
    f.close()
 
def add_abbrev(abbr, what, who):
    key, val = split_abbr_line(what)
    abbr[key.lower()] = val and ("%s (ref: %s)" % (val, who)) or ''
 
def do_abbrv_thing(what, who):
    what = ' '.join(what.split(' ')[1:])
    if ABBREV_FILE:
        abbr = load_abbrevs(ABBREV_FILE)
 
        if what.lower() in abbr:
            return [ abbr[what.lower()] ];
 
        if '=' in what:
            add_abbrev(abbr, what, who)
            try:
                save_abbrevs(ABBREV_FILE, abbr)
            except IOError:
                return [ "Couldn't note that." ]
            else:
                return [ "Okeydoke." ]
 
    return expand(what)
 
if __name__ == '__main__':
    if len(sys.argv) < 4:
        print "Need at least 3 arguments: <what> <who> <fullcmd>"
        sys.exit(1)
 
    print ' '.join( do_abbrv_thing( sys.argv[3], sys.argv[2] ) )
