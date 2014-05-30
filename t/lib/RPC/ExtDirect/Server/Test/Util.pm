package RPC::ExtDirect::Server::Test::Util;

use Exporter;
use Test::More;
use HTTP::Tiny;

use base 'Exporter';

our @EXPORT = qw/
    get
    post
    is_status
    is_content
    like_content
    is_header
    like_header
/;

sub get {
    my ($uri, $opt, $arg) = @_;

    my $http = HTTP::Tiny->new( max_redirect => 0, %$arg, );

    # HTTP::Tiny is picky about its arguments
    return $http->get($uri, $opt ? ($opt) : ());
}

sub post {
    my ($uri, $opt, $arg) = @_;

    my $http = HTTP::Tiny->new( max_redirect => 0, %$arg, );

    return $http->post($uri, $opt);
}

sub is_status {
    my ($r, $want, $msg) = @_;

    is $r->{status}, $want, $msg or diag explain "Response:", $resp;
}

sub is_content {
    my ($r, $want, $msg) = @_; 

    is $r->{content}, $want, $msg or diag explain "Response:", $resp;
}

sub like_content {
    my ($r, $want, $msg) = @_;

    like $r->{content}, $want, $msg or diag explain "Response:", $resp;
}

sub is_header {
    my $r   = shift;
    my $hdr = lc shift;
    my ($want, $msg) = @_;

    is $r->{headers}->{$hdr}, $want, $msg
        or diag explain "Response:", $resp;
}

sub like_header {
    my $r   = shift;
    my $hdr = lc shift;
    my ($want, $msg) = @_;

    like $r->{headers}->{$hdr}, $want, $msg
        or diag explain "Response:", $resp;
}

1;
