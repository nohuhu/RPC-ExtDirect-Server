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

use lib 't/lib';

use util;

my $static_dir = 't/htdocs';

my $port = start_server(static_dir => $static_dir);

ok $port, 'Got port';

my $mech = new WWW::Mechanize;

eval { $mech->get("http://localhost:$port/api") };

is $mech->status, 200,                      'Got status';
is $mech->ct,     'application/javascript', 'Got content type';

my $expected_api = <<'END_API';
Ext.app.REMOTING_API = {"actions":{"test":[{"name":"bar","params":["foo","bar"]},{"len":2,"name":"foo"}]},"type":"remoting","url":"/router"};
END_API

my $actual_data   = deparse_api($mech->content);
my $expected_data = deparse_api($expected_api);

is_deeply $actual_data, $expected_data, 'Got content'
    or diag explain $actual_data;

