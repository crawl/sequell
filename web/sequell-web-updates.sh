#!/bin/bash

set -e

while getopts "h?d:" opt; do
    case "$opt" in
        h|\?)
            echo -e "$usage_string"
            exit 0
            ;;
        d)  sequell_dir="$OPTARG"
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ -n "$sequell_dir" ]; then
    cd "$sequell_dir"
fi

web/learndb-html.pl dat/learn.db www/learndb.html
web/user-commands-html.rb > www/userdef.html
