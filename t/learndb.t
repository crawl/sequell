use strict;
use warnings;

use Test::More;
use lib 'lib';
use File::Path;
use utf8;

BEGIN {
  $ENV{LEARNDB} = 'tmp/test.db';
  unlink $ENV{LEARNDB};
};

File::Path::make_path('tmp');

$ENV{IRC_NICK_AUTHENTICATED} = 'y';
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{RUBYOPT} = '-rubygems -Isrc';
$ENV{PERL_UNICODE} = 'AS';
$ENV{HENZELL_ROOT} = '.';
$ENV{HENZELL_ALL_COMMANDS} = 'y';

use Henzell::ReactorService;
use Henzell::IRCTestStub;
use Henzell::CommandService;
use Henzell::Bus;
use LearnDB;

my $channel = '##crawl';
my $nick = 'greensnark';
my $rc = 'rc/sequell.rc';
my $irc = Henzell::IRCTestStub->new(channel => $channel);
my $bus = Henzell::Bus->new;
my $cmd = Henzell::CommandService->new(irc => $irc,
                                       config => $rc,
                                       bus => $bus);
my $ldb = Henzell::ReactorService->new(executor => $cmd,
                                       irc => $irc,
                                       bus => $bus);
$irc->configure_services(services => [$ldb]);

irc('!learn add aa Hello');
irc('!learn add aa there');
irc('!learn add bb mellow');
irc('!learn add bb yak');
irc('!learn add bb fries');
is(irc('!learn swap aa bb'), 'aa[2], bb[3] => bb[2], aa[3]');
is(irc('??aa'), 'aa[1/3]: mellow');
is(irc('!learn swap aa[2 aa[$'), 'Swapped aa[2] with aa[$].');

irc('!learn add greeter Hi $nick');
is(irc('??greeter'), 'greeter[1/1]: Hi greensnark');
is(irc('!RELAY -nick mazda ??greeter'), 'greeter[1/1]: Hi mazda');
is(irc('!RELAY -nick mazda -prefix Yak: ??greeter'), 'Yak:greeter[1/1]: Hi mazda');
is(irc('!RELAY -nick mazda !learn add foo bar'), 'Permission db:foo denied: proxying not permitted');

irc('!learn add xxx Yak');
is(irc('!learn mv xxx yyy'), 'xxx -> yyy[1/1]: Yak');
irc('!learn add src Test');
irc('!learn add dst Hi');
irc('!learn mv src[$] dst[$]');
is(irc('??dst[$]'), "dst[2/2]: Test");
is(irc('??dst[2/2]'), "dst[2/2]: Test");
is(irc('??src[$]'), "I don't have a page labeled src[-1] in my learndb.");
irc('!learn del dst[$]');
is(irc('??dst[$]'), "dst[1/1]: Hi");

is(irc('??cow'), "I don't have a page labeled cow in my learndb.");
is(irc('!learn add cow MOOOOOO'), 'cow[1/1]: MOOOOOO');
is(irc('??cow'), "cow[1/1]: MOOOOOO");

irc('!learn add pow see {cow}');
is(irc('??pow'), "cow[1/1]: MOOOOOO");

irc('!learn add numeric_dummy 10');
is(irc('.echo $(ldb numeric_dummy)'), 'numeric_dummy[1/1]: 10');
irc('!learn add cow cowcowcow');
is(irc('??pow[2]'), "cow[2/2]: cowcowcow");
is(irc('??pow[-1]'), "cow[2/2]: cowcowcow");

is(irc('!learn add superior_cow More cow than cow'),
   'superior cow[1/1]: More cow than cow');
is(irc('!learn add "superior cow" Considerably more'),
       'superior cow[2/2]: Considerably more');
is(irc('!learn add \'ultra bull\' Ultra ultra'),
   'ultra bull[1/1]: Ultra ultra');
is(irc('!learn mv "superior cow"[$] \'ultra bull\''),
   'superior cow[2] -> ultra bull[2/2]: Considerably more');
is(irc('!learn rm superior cow'),
   'Deleted superior cow[1/1]: More cow than cow');
is(irc('!learn rm ultra bull[$'),
   'Deleted ultra bull[2/2]: Considerably more');
is(irc('!learn rm ultra bull[$'),
   'Deleted ultra bull[1/1]: Ultra ultra');

irc('!learn add cow How now');
irc('!learn add cowt see {cow}');
irc('!learn add cszo cßo');
is(irc('??cszo'), "cszo[1/1]: cßo");
is(irc('??cowd'), "cowd ~ cow[1/3]: MOOOOOO");
is(irc('??pow[-1]'), "cow[3/3]: How now");
is(irc('??Coc'), "Coc ~ cow[1/3]: MOOOOOO");
is(irc('??powz[3]'), "powz ~ pow ~ cow[3/3]: How now");

irc('!learn set cow[-1] How now brown cow');
is(irc('??pow[-1]'), "cow[3/3]: How now brown cow");

is(irc('!learn set radon An element'), 'radon[1/1]: An element');
is(irc('!learn set radon A radioactive element'),
   'radon[1/1]: A radioactive element');
is(irc('!learn set radon[5] Rn'),
   'radon[2/2]: Rn');
is(irc('!learn set radon[2] RADON'),
   'radon[2/2]: RADON');
is(irc('!learn set radon[-1] ?'),
   'radon[2/2]: ?');
is(irc('!learn set radon[$] ???'),
   'radon[2/2]: ???');
is(irc('!learn set puma[$] PUMA'), 'puma[1/1]: PUMA');

like(irc('?/cow'), qr/Matching terms \(2\): cow, cowt; entries \(4\): cow\[2\].*/);
is(irc('?/<cow'), 'Matching terms (2): cow, cowt');
like(irc('?/>cow'), qr/Matching entries \(4\): cow\[2.*/);

irc('!cmd foo .echo Hi');
irc('!cmd foz .echo Foz');
irc('!cmd bar .echo Bar');
irc('!learn add !help:!foo Hahahahaha');
is(irc('!help !foo'), "!foo: Hahahahaha");
is(irc('!help !foz'), "No help for !foz (you could add help with !learn add !help:!foz <helpful text>)");
like(irc('!help !bar'), qr/No help for !bar/);
like(irc('!help !miaow'), qr/Unknown command: !miaow/);

beh('Hi! ::: Hello, $nick. Welcome to ${channel}!', sub {
  is(irc('Hi!'), "Hello, greensnark. Welcome to ##crawl!")
});

beh('Give $person a hug ::: /me hugs $person.', sub {
  is(irc('Give rutabaga a hug'), "/me hugs rutabaga.")
});

beh('/me visits >>> ::: /me also visits $after', sub {
  is(emote('visits the Lair'), "/me also visits the Lair")
});

beh('/me visits (?P<place>.*) ::: /me also visits $place', sub {
  is(emote('visits the Lair'), "/me also visits the Lair")
});

beh('Is there $*balm in Gilead\? ::: Why, yes, there is $balm', sub {
  is(irc('Is there milk and honey in Gilead?'),
     "Why, yes, there is milk and honey")
});

beh('r\?\?>>> ::: $(!learn q $after)', sub {
  is(irc('r??cow'), "cow[1/3]: MOOOOOO")
});

beh('.echo Hi! ::: Hola ::: continue',
    '.echo Hi! ::: Eeek! ::: break', sub {
  is(irc('.echo Hi!'), "Hola\nEeek!\nHi!");
});

beh('.echo Hi! ::: Hola ::: last',
    '.echo Hi! ::: Eeek! ::: break', sub {
  is(irc('.echo Hi!'), "Hola");
});

beh('.echo Hi! ::: Eeek! ::: break',
    '.echo Hi! ::: Hola ::: last', sub {
      is(irc('.echo Hi!'), "Eeek!\nHi!");
});

beh('\?\?\s*secret\s* :::  ::: last', sub {
  is(irc('??secret'), "");
  is(irc('\\\\??secret'), "I don't have a page labeled secret in my learndb.");
});

beh('!tell $bot >>> ::: Flee, ${nick}! ::: last', sub {
  is(irc('!tell Sequell Hi'), "Flee, greensnark!");
  like(irc('!tell greensnark Hi'), qr/OK, .*greensnark/);
});

irc('!cmd !yak .echo Hi');
is(irc('!yak'), "Hi");
irc('!cmd -rm !yak');

is(irc('.echo $(do 0)'), '0');

done_testing();

sub irc {
  my $command = shift();
  $irc->tick();
  $irc->said({ channel => $channel,
               body => $command,
               verbatim => $command,
               who => $nick });
  my $out = $irc->output() || '';
  $out =~ s/\s+$//;
  $out
}

sub emote {
  my $command = shift();
  $irc->emoted({ channel => $channel,
                 body => $command,
                 who => $nick });
  my $out = $irc->output() || '';
  $out =~ s/\s+$//;
  $out
}

sub beh {
  my @beh = @_;
  my $test = pop @beh;
  LearnDB::del_term(':beh:');
  irc("!learn add :beh: $_") for @beh;
  $test->();
}
