# This script can be used for manual HTTP server testing in case
# something goes awry

use common::sense;

use IS::Devel::Test::HTTPServer;

my $dsid = shift @ARGV // '_test';

my $server = IS::Devel::Test::HTTPServer->new(dsid => $dsid);
my $port   = $server->port;

say "Listening on port $port";

$server->run();

