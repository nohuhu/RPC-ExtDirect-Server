# This script can be used for manual HTTP server testing in case
# something goes awry

use strict;
use warnings;

use RPC::ExtDirect::Server;

my $port = shift @ARGV || 30000 + int rand 10000;

my $server = RPC::ExtDirect::Server->new(
    static_dir => '/tmp',
    port       => $port,
);
$port = $server->port;

print "Listening on port $port\n";

$server->run();

