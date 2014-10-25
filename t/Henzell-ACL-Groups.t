use strict;
use warnings;

use Test::More;
use lib 'lib';

use Henzell::ACL::Groups;

my $g = Henzell::ACL::Groups->new;
$g->add('foo', 'greensnark pow @lap');
$g->add('lap', 'kangaroo');

ok(!$g->nick_in_groups('cow', 'lap'));
ok($g->nick_in_groups('kangaroo', 'foo'));
ok($g->nick_in_groups('greensnark', 'foo'));
ok(!$g->nick_in_groups('cow', 'fake'));

done_testing();
