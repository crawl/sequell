#!/bin/bash

set -e

export PERL5LIB=/home/gammafunk/perl5/lib/perl5

cd /home/gammafunk/dcss-bots/sequell
web/learndb-html.pl dat/learn.db www/learndb.html
web/user-commands-html.rb > www/userdef.html
