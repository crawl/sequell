from helper import demunge_xlogline

lines = ("bla=b==oink:foo=joe",
         "blah::graff")

print "Line, dict"
for line in lines:
    print line, demunge_xlogline(line)
