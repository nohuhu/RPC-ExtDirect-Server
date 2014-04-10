# Test working with Ext.Direct requests

package test::class;

use RPC::ExtDirect Action => 'test';

sub foo : ExtDirect(2) {
}

sub bar : ExtDirect(params => ['foo', 'bar']) {
}

package main;

use strict;
use warnings;
no  warnings 'uninitialized';

use RPC::ExtDirect::Test::Util;

use Test::More tests => 4;
use WWW::Mechanize;

use RPC::ExtDirect::Server::Util;

my $static_dir = 't/htdocs';
my $want_port  = shift @ARGV;

my ($host, $port) = start_server(
    static_dir => $static_dir,
    $want_port ? ( port => $want_port ) : (),
);

ok $port, "Got host: $host and port: $port";

my $mech = new WWW::Mechanize;

eval { $mech->get("http://$host:$port/extdirectapi") };

is $mech->status, 200,                      'Got status';
is $mech->ct,     'application/javascript', 'Got content type'
    or diag explain $mech->res;

my $want = <<'END_API';
Ext.app.REMOTING_API = {"actions":{"test":[{"name":"bar","params":["foo","bar"]},{"len":2,"name":"foo"}]},"type":"remoting","url":"/extdirectrouter"};
END_API

my $have = $mech->content;

cmp_api $have, $want, "API content";

