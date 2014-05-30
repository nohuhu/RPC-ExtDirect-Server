# Test serving static content

use strict;
use warnings;
no  warnings 'uninitialized';

use Test::More tests => 9;

use lib 't/lib';
use RPC::ExtDirect::Server::Util;
use RPC::ExtDirect::Server::Test::Util;

my $static_dir = 't/htdocs';

my ($host, $port) = maybe_start_server(static_dir => $static_dir);

ok $port, "Got host: $host and port: $port";

# Should be a redirect from directory to index.html
my $resp = get "http://$host:$port/dir";

is_status $resp, 301, 'Got 301';

# Should get 404
$resp = get "http://$host:$port/nonexisting/stuff";

is_status $resp, 404, 'Got 404';

# Get a (seemingly) non-text file
my $want_len = (stat "$static_dir/bar.png")[7];

$resp = get "http://$host:$port/bar.png";

is_status    $resp, 200,                           'Img got status';
like_content $resp, qr/foo/,                       'Img got content';
is_header    $resp, 'Content-Type',   'image/png', 'Img got content type';
is_header    $resp, 'Content-Length', $want_len,   'Img got content length';

# Now get text file and check the type
$resp = get "http://$host:$port/foo.txt";

is_status   $resp, 200,                              'Text got status';
like_header $resp, 'Content-Type', qr/^text\/plain/, 'Text got content type';

