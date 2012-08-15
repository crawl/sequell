#!/usr/bin/python
import helper
import sys

helper.help("see {banishment}")

if __name__ == '__main__':
    if sys.argv[1].lower() != 'wensley':  # nice try
        print sys.argv[2] + ' casts a spell. ' + sys.argv[1] + ' is devoured by a tear in reality!'
