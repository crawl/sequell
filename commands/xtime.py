#! /usr/bin/python

from datetime import datetime, timedelta
import time
import helper

TOURNEY_BEGIN = datetime(2011, 5, 14)
TOURNEY_END   = datetime(2011, 5, 30)
TOURNEY_NAME = '%d 0.8 tournament' % TOURNEY_BEGIN.year

helper.help('Shows the UTC time on crawl.akrasiac.org.')

def pretty_delta(delta):
  seconds = delta.seconds
  hours = seconds / (60 * 60)
  minutes = (seconds / 60) % 60
  seconds = seconds % 60
  days = delta.days

  keys = [ [days, 'day'], [hours, 'hour'],
           [minutes, 'minute'],  [seconds, 'second'] ]
  keys = ["%d %s%s" % (k[0], k[1], k[0] > 1 and 's' or '')
          for k in keys if k[0] > 0]
  if not keys:
    return "now"
  elif len(keys) == 1:
    return "in " + keys[0]
  return "in " + ", ".join(keys[:-1]) + " and " + keys[-1]

now = datetime.utcnow()
extra = ''
if now < TOURNEY_BEGIN:
  ttime = TOURNEY_BEGIN - now
  extra = "The "+ TOURNEY_NAME + " starts " + pretty_delta(ttime) + '.'
elif now >= TOURNEY_BEGIN and now < TOURNEY_END:
  ttime = TOURNEY_END - now
  extra = "The " + TOURNEY_NAME + " ends " + pretty_delta(ttime) + "."

if extra:
  extra = " " + extra

print ("Time: %s, UTC."
       % (time.strftime('%b %d, %Y, %I:%M:%S %p', now.timetuple()))
       + extra)
