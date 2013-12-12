package RPC::ExtDirect::Server;

use strict;
use warnings;
no  warnings 'uninitialized';   ## no critic

use HTTP::Date qw(str2time time2str);
use CGI '-nph';
use List::Util qw(first);

use RPC::ExtDirect::API     api_path    => '/api',
                            router_path => '/router',
                            poll_path   => '/events',
                            ;

use CGI::ExtDirect;

use base 'HTTP::Server::Simple::CGI';

### VERSION ###

our $VERSION = '0.01';

### PUBLIC PACKAGE VARIABLE ###
#
# Turns debugging on and off
#

our $DEBUG = 0;

### PUBLIC PACKAGE VARIABLE ###
#
# Main dispatch table that matches URIs to methods
#

our @DISPATCH = (

    # Format:
#   { match => qr{URI}, code => \&method, },

    { match => qr{^/api},    code => \&handle_extdirect_api    },
    { match => qr{^/router}, code => \&handle_extdirect_router },
    { match => qr{^/events}, code => \&handle_extdirect_events },
);

### PUBLIC CLASS METHOD (CONSTRUCTOR) ###
#
# Instantiate a new HTTPServer
#

sub new {
    my ($class, %params) = @_;

    my $host       = $params{host};
    my $static_dir = $params{static_dir};

    die "Static directory is required parameter, stopped\n"
        unless defined $static_dir;

    # We generate random port here to avoid clashing in parallel testing
    my $port = $params{port} || 30000 + int rand 9999;

    logit("New HTTPServer with port $port on localhost");

    my $self = $class->SUPER::new($port);

    # Host is always localhost for testing, except when overridden
    $self->host( $host || '127.0.0.1' );

    $self->{static_dir} = $static_dir;

    logit("Using static directory ". $self->static_dir);

    return bless $self, $class;
}

### PUBLIC INSTANCE METHOD ###
#
# Parse HTTP request line. Returns three values: request method,
# URI and protocol.
#

sub parse_request {
    $_ = <STDIN>;

    return unless defined $_;

    /^(\w+)\s+(\S+)(?:\s+(\S+))?\r?$/ and
        return (
            defined $1 ? $1 : '',
            defined $2 ? $2 : '',
            defined $3 ? $3 : '',
        );
}

### PUBLIC INSTANCE METHOD ###
#
# Parse incoming HTTP headers from STDIN and return arrayref of
# header/value pairs.
#

sub parse_headers {
    my @headers;

    while ( <STDIN> ) {
        s/[\r\l\n\s]+$//;
        last if /^$/;

        push @headers, $1 => $2
            if /^([^()<>\@,;:\\"\/\[\]?={} \t]+):\s*(.*)/i;
    };

    return \@headers;
}

### PUBLIC INSTANCE METHOD ###
#
# Find matching method by URI and dispatch it.
#

sub handle_request {
    my ($self, $cgi) = @_;

    $cgi->nph(1);
    $self->{cgi} = $cgi;

    my $path_info = $cgi->path_info();

    logit("Handling request: $path_info");

    my ($handler, $match)
        = map   { $_? ( $_->{code}, $_->{match} ) : () }
          first { $path_info =~ $_->{match}            }
                @DISPATCH
        ;

    logit("Got handler with match $match") if $handler;

    return $handler ? $handler->($self, $cgi)
         :            $self->handle_default($cgi)
         ;
}

### PUBLIC INSTANCE METHOD ###
#
# Return 404 header without a body.
#

sub handle_404 {
    my ($self, $cgi, $url) = @_;

    $cgi ||= $self->cgi;

    logit("Handling 404");

    print $cgi->header(-status => '404 Not Found', -charset => 'utf-8');

    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Return 500 header and message body.
#

sub handle_500 {
    my ($self, $cgi, $msg) = @_;

    $cgi ||= $self->cgi;

    logit("Handling 500");

    print $cgi->header(-status  => '500 Internal Server Error',
                       -charset => 'utf-8');

    my $msg_p = $msg ? "<br /><p>Error message: $msg</p>"
              :        "<br /><p></p>"
              ;

    print <<"END_HTML";
<html><head><title>Internal Server Error</title></head>
<body>
<p>We're terribly sorry but server was unable to process your request
due to internal error.</p>
<p>The error was not caused by your actions, it is probably a bug or
misconfiguration in the software.</p>
<p>If you don't mind helping to fix this error, please tell your system
administrator about it.</p>
$msg_p
</body>
</html>
END_HTML

    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Handle static content
#

my %MIME_TYPES = (
    'css'   => 'text/css',
    'txt'   => 'text/plain',
    'htm'   => 'text/html',
    'html'  => 'text/html',
    'ico'   => 'image/x-icon',
    'gif'   => 'image/gif',
    'jpg'   => 'image/jpeg',
    'jpeg'  => 'image/jpeg',
    'png'   => 'image/png',
    'js'    => 'text/javascript',
    'json'  => 'application/json',
    'swf'   => 'application/x-shockwave-flash',
);

sub handle_static {
    my ($self, %params) = @_;

    my $cgi = $self->cgi;

    my $file_name = $params{file_name};
    my $mime      = $params{mime};

    logit("Handling static request for $file_name");

    my ($fino, $fsize, $fmtime) = (stat $file_name)[1, 7, 9];
    $self->handle_404() unless $fino;

    my $suff;
    $file_name =~ /.*\.(\w+)$/ and $suff = $1;

    my $type = $mime || $MIME_TYPES{$suff} || 'application/octet-stream';

    logit("Got MIME type $type");

    my $ims = $cgi->http('If-Modified-Since');
    if ( $ims && $fmtime <= str2time($ims) )
    {
        logit("File has not changed, serving 304");
        print $cgi->header(-type => $type, -status => '304 Not Modified');
        return 1;
    };

    my ($in, $out, $rd, $buf);

    if ( not open $in, '<', $file_name ) {
        logit("File is unreadable, serving 403");
        print $cgi->header(-status => '403 Forbidden');
        return 1;
    };

    logit("Serving file content with 200");

    print $cgi->header(-type => $type, -status => '200 OK',
                       -charset => ($type !~ /image|octet/ ? 'utf-8' : ''),
                       -Expires => time2str(time + 259200), # 3 days
                       -Content_Length => $fsize,
                       -Last_Modified => time2str($fmtime));

    binmode $in;

    $out = select;
    binmode $out;

    # Reasonably large buffer?
    syswrite $out, $buf, $rd while $rd = sysread $in, $buf, 262144;

    return 1;
}

### PUBLIC INSTANCE METHOD ###
#
# Default request handler
#

sub handle_default {
    my ($self, $cgi) = @_;

    $cgi ||= $self->cgi;

    my $path = $cgi->path_info();

    # Lame security measure
    $self->handle_404() if $path =~ m{^\.{1,2}/};

    my $static = $self->static_dir();
    $static   .= '/' unless $path =~ m{^/};

    my $file_name = $static . $path;

    if ( -d $file_name ) {

        # Directory requested, redirecting to index.html
        $path =~ s{/$}{};

        logit("Got directory, redirecting to $path/index.html");

        print $cgi->redirect(-uri    => "$path/index.html",
                             -status => '301 Moved Permanently');
    }
    elsif ( -f $file_name && -r $file_name ) {

        # Got readable file, serving it as static content
        logit("Got readable file, serving as static content");
        $self->handle_static(file_name => $file_name );
    }
    else {
        $self->handle_404();
    };

    return 1;   # Just in case
}

### PUBLIC INSTANCE METHOD ###
#
# Return Ext.Direct API declaration JavaScript
#

sub handle_extdirect_api {
    my ($self, $cgi) = @_;

    $cgi ||= $self->cgi;

    logit("Got Ext.Direct API request");

    return $self->_handle_extdirect($cgi, 'api');
}

### PUBLIC INSTANCE METHOD ###
#
# Route Ext.Direct method calls
#

sub handle_extdirect_router {
    my ($self, $cgi) = @_;

    $cgi ||= $self->cgi;

    logit("Got Ext.Direct route request");

    return $self->_handle_extdirect($cgi, 'route');
}

### PUBLIC INSTANCE METHOD ###
#
# Poll Ext.Direct event providers for events
#

sub handle_extdirect_events {
    my ($self, $cgi) = @_;

    $cgi ||= $self->cgi;

    logit("Got Ext.Direct event poll request");

    return $self->_handle_extdirect($cgi, 'poll');
}

### PUBLIC INSTANCE METHODS ###
#
# Read only getters
#

sub cgi        { $_[0]->{cgi}        }
sub static_dir { $_[0]->{static_dir} }

### PUBLIC PACKAGE SUBROUTINE ###
#
# Helper method
#

sub logit { print STDERR @_ if $DEBUG }

### PUBLIC PACKAGE SUBROUTINE ###
#
# Prints banner, but only if debugging is on
#

sub print_banner {
    my ($self) = @_;

    $self->SUPER::print_banner if $DEBUG;
}

############## PRIVATE METHODS BELOW ##############

### PRIVATE INSTANCE METHOD ###
#
# Do actual heavy lifting for Ext.Direct calls
#

sub _handle_extdirect {
    my ($self, $cgi, $what) = @_;

    my $exd = CGI::ExtDirect->new({ cgi => $cgi, debug => 1});

    # Standard CGI headers for this handler
    my %std_cgi = ( nph => 1, '-charset' => 'utf-8' );

    print $exd->$what( %std_cgi );

    return 1;
}

1;

__END__

=pod

=head1 NAME

RPC::ExtDirect::Server - CGI-based Ext.Direct server

=head1 SYNOPSIS

 use RPC::ExtDirect::Server;
 
 my $server = RPC::ExtDirect::Server->new(static_dir => 'htdocs');
 my $port   = $server->port;
 
 print "Ext.Direct server is running on port $port\n";
 
 $server->run();

=head1 DESCRIPTION

This module implements a minimal Ext.Direct capable server in pure Perl.
Its main purpose it to be used as lightweight drop-in replacement for
more complex production environments like Plack or Apache/mod_perl, i.e.
for testing and mockups. It can also be used as the basis for production
application servers when feature richness is not a requirement, or when
resource consumption is of primary concern.

=head1 METHODS

=over 4

=item new(%params)

Create a new server instance with specified parameters:

=over 8

=item host

Hostname or IP address to bind to. Defaults to 127.0.0.1.

=item port

Port to bind to. Defaults to randomly generated in 30000-40000 range.

=item static_dir

Path to directory with static content. This parameter is mandatory.

=back

=item run

Run the server. This method never returns.

=back

=head1 DEPENDENCIES

RPC::ExtDirect::Server depends on the following modules:
L<CGI::ExtDirect>, L<RPC::ExtDirect>, L<JSON>, L<Attribute::Handlers>.

=head1 SEE ALSO

For more information, see L<CGI::ExtDirect>.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module. Use github tracker to report bugs
(the best way) or just drop me an e-mail. Patches are welcome.

=head1 AUTHOR

Alexander Tokarev E<lt>tokarev@cpan.orgE<gt>

=head1 ACKNOWLEDGEMENTS

I would like to thank IntelliSurvey, Inc for sponsoring my work
on this module.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 Alexander Tokarev.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.

=cut

