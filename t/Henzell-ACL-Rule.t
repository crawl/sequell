use strict;
use warnings;

use Test::More;
use lib 'lib';

use Henzell::ACL::Rule;
use Henzell::ACL::Groups;

my $g = Henzell::ACL::Groups->new;

sub rule {
  my ($name, @entries) = @_;
  Henzell::ACL::Rule->new($g, $name, @entries)
}

ok(rule(":acl:db:cow")->matches_permission("db:cow"), "perm-match");
ok(rule(":acl:db:c*")->matches_permission("db:cow"), "perm-wildcard-match");
ok(!rule(":acl:db:c*")->matches_permission("db:moo"), "perm-wildcard-not-match");
is(rule(":acl:db:cow", "greensnark")->permit('greensnark'),
   'authenticated');
ok(!rule(":acl:db:cow", "greensnark")->permit('pow'),
   'reject-non-whitelisted');
is(rule(":acl:db:cow", "DENY:foo")->permit('greensnark'), 'any');
ok(!rule(":acl:db:cow", "DENY:foo")->permit('foo'), 'reject-blacklisted');
is(rule(":acl:db:cow", "*")->permit('yak'), 'any');
is(rule(":acl:db:cow", "+authenticated")->permit('yak'), 'authenticated');
ok(rule("acl:db:cow", "DENY:#crawl")->permit('greensnark', '#crawl-dev'));
ok(rule("acl:db:cow", "DENY:(#crawl pow)")->permit('greensnark', '#crawl-dev'));
ok(!rule("acl:db:cow", "DENY:(#crawl pow)")->permit('greensnark', '#crawl'));
ok(!rule("acl:db:cow", "DENY:(#crawl pow)")->permit('pow', '#crawl-dev'));
ok(!rule("acl:db:cow", "DENY:#crawl")->permit('greensnark', '#crawl'));
ok(!rule("acl:db:moo", "DENY:#:pm")->permit('greensnark', 'msg'));
ok(!rule("acl:db:moo", "DENY:#:pm cow")->permit('greensnark', 'msg'));
ok(rule("acl:db:moo", "DENY:#:pm cow")->permit('cow', '#crawl'));
ok(!rule("acl:db:foo", "#crawl")->permit('cow', '#crawl-dev'));
ok(rule("acl:db:foo", "#crawl")->permit('cow', '#crawl'));
ok(!rule("acl:db:foo", "#crawl zap")->permit('cow', '#crawl'));
is(rule("acl:db:foo", "#crawl zap")->permit('zap', '#crawl'),
   'authenticated');

# Group tests.
$g->add('main', '#crawl #crawl-dev');
$g->add('admins', 'greensnark yak @moreadmins');
$g->add('moreadmins', 'cow');
ok(rule("acl:db:foo", '#@main')->permit('foo', '#crawl'));
ok(!rule("acl:db:foo", '#@main')->permit('foo', '#crawl-sequell'));
ok(!rule("acl:db:foo", 'DENY:#@main')->permit('foo', '#crawl'));
ok(rule("acl:db:foo", 'DENY:#@main')->permit('foo', '##csdc'));
ok(!rule("acl:db:foo", '#@main @admins')->permit('foo', '#crawl'));
is(rule("acl:db:foo", '#@main @admins')->permit('cow', '#crawl'),
   'authenticated');

done_testing();
