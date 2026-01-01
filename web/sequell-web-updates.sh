#!/bin/bash

set -e

cd /mnt/dcss_game_data/sequell
web/learndb-html.pl > www/learndb.html
web/user-commands-html.rb > www/userdef.html
