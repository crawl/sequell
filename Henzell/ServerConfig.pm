use strict;
use warnings;

package Henzell::ServerConfig;

use base 'Exporter';
use YAML::Any qw/LoadFile/;

my $SERVER_CONFIG_FILE = 'config/servers.yml';
my $SERVERCFG = LoadFile($SERVER_CONFIG_FILE);

sub source_hostname {
  my $source = shift;
  $$SERVERCFG{sources}{$source}
}

sub server_abbreviations {
  %{$$SERVERCFG{sources}}
}

1
