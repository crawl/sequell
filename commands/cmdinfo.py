#!/usr/bin/python

import os, sys
from helper import *

help("Lists all available Henzell commands.")

commands = os.popen('cat commands/commands.txt').readlines()

output = ''
for line in commands:
    output += line.split(' ')[0] + ' '

print output
