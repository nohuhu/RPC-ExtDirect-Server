# Test working with Ext.Direct requests

package test::class;

use RPC::ExtDirect::Event;
use RPC::ExtDirect Action => 'test';

sub foo : ExtDirect(2) { [@_] }
sub bar : ExtDirect(params => ['foo', 'bar']) { shift; +{@_} }
sub qux : ExtDirect(pollHandler) {
    return (
        RPC::ExtDirect::Event->new('foo', 'blah'),
        RPC::ExtDirect::Event->new('bar', 'bleh'),
    );
}

sub cgi : ExtDirect(0, env_arg => 1) {
    my ($class, $env) = @_;

    return $env->isa('CGI::Simple') ? \1 : \0;
}

package main;

use strict;
use warnings;

use RPC::ExtDirect::Test::Util qw/ cmp_api cmp_json /;

use Test::More tests => 12;

use lib 't/lib';
use RPC::ExtDirect::Server::Util;
use RPC::ExtDirect::Server::Test::Util;

my $static_dir = 't/htdocs';
my ($host, $port) = maybe_start_server( static_dir => $static_dir );

ok $port, "Got host: $host and port: $port";

my $api_uri    = "http://$host:$port/extdirectapi";
my $router_uri = "http://$host:$port/extdirectrouter";
my $poll_uri   = "http://$host:$port/extdirectevents";

my $resp = get $api_uri;

is_status   $resp, 200,'API status';
like_header $resp, 'Content-Type', qr/^application\/javascript/,
    'API content type';

my $want = <<'END_API';
Ext.app.REMOTING_API = {"actions":{"test":[{"name":"bar","params":["foo","bar"]},{"len":2,"name":"foo"},{"len":0,"name":"cgi"}]},"type":"remoting","url":"/extdirectrouter"};
Ext.app.POLLING_API = {"type":"polling","url":"/extdirectevents"};
END_API

my $have = $resp->{content};

cmp_api $have, $want, "API content";

my $req = q|{"type":"rpc","tid":1,"action":"test","method":"foo",|.
          q|"data":["foo","bar"]}|;

$resp = post $router_uri, { content => $req };

is_status $resp, 200, "Ordered req status";

$have = $resp->{content};
$want = q|{"result":["test::class","foo","bar"],"type":"rpc",|.
        q|"action":"test","method":"foo","tid":1}|;

cmp_json $have, $want, "Ordered req content"
    or diag explain "Response:", $resp;

$req = q|{"type":"rpc","tid":2,"action":"test","method":"bar",|.
       q|"data":{"foo":42,"bar":"blerg"}}|;

$resp = post $router_uri, { content => $req };

is_status $resp, 200, "Named req status";

$have = $resp->{content};
$want = q|{"result":{"foo":42,"bar":"blerg"},"type":"rpc",|.
        q|"action":"test","method":"bar","tid":2}|;

cmp_json $have, $want, "Named req content"
    or diag explain "Response:", $resp;

# If CGI::Simple is installed, check if we're defaulting to it
SKIP: {
    eval "require CGI::Simple";

    skip "CGI::Simple not installed", 2 if $@;

    $req = q|{"type":"rpc","tid":3,"action":"test","method":"cgi",|.
           q|"data":[]}|;

    $resp = post $router_uri, { content => $req };

    is_status $resp, 200, "CGI req status";

    $have = $resp->{content};
    $want = q|{"result":true,"type":"rpc","action":"test",|.
            q|"method":"cgi","tid":3}|;

    cmp_json $have, $want, "CGI req content"
        or diag explain "Response:", $resp;
}

$resp = get $poll_uri;

is_status $resp, 200, "Poll req status";

$have = $resp->{content};
$want = q|[{"type":"event","name":"foo","data":"blah"},|.
        q|{"type":"event","name":"bar","data":"bleh"}]|;

cmp_json $have, $want, "Poll req content"
    or diag explain "Response:", $resp;

