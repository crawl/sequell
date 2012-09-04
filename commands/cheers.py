#!/usr/bin/python
#coding: utf-8

import helper
import sys
import random

helper.help('Celebrate!')

beverage = [
    ('whiskey', 2),
    ('beer', 2),
    ('mead', 2),
    ('lager', 2),
    ('vodka', 2),
    ('cider', 2),
    ('tequila', 2),
    ('gin', 2),
    ('bourbon', 2),
    ('scotch', 2),
    ('rum', 2),
    ('brandy', 2),
    ('cognac', 1),
    ('vermouth', 1),
    ('saké', 1),
    ('sangria', 1),
    ('goldschläger', 1),
    ('absinthe', 1),
    ('cabernet sauvignon', 1),
    ('moonshine', 1),
]

container = [
    ('glass', 2),
    ('pint', 2),
    ('flagon', 2),
    ('stein', 2),
    ('shot glass', 2),
    ('boot full', 1),
    ('briefcase full', 1),
    ('pony keg', 1),
    ('party ball', 1),
    ('cask', 1),
]

def select(items):
    total_weight = sum(weight for name, weight in items)
    index = random.randint(1, total_weight)  # Inclusive bounds
    for item in items:
        index -= item[1]
        if index <= 0:
            return item[0]

if __name__ == '__main__':
    print '/me slides a ' + select(container) + ' of ' + select(beverage) + \
          ' across the bar to ' + sys.argv[1] + ', on the house.'
