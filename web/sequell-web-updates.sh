#!/bin/bash

set -e

cd /mnt/dcss/sequell
web/learndb-html.pl dat/learn.db www/learndb.html
web/user-commands-html.rb > www/userdef.html
