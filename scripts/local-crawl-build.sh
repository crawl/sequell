#! /usr/bin/env bash

export PATH="/usr/lib/ccache:$PATH"
cd /home/gammafunk/dcss-bots/sequell
scripts/update-crawl-source -j 2 -m 'debug-lite EXTERNAL_FLAGS_L=-DDEBUG_STATISTICS'
