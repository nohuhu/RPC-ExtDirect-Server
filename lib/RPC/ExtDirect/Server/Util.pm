package RPC::ExtDirect::Server::Util;

use strict;
use warnings;
no  warnings 'uninitialized';   ## no critic

use Carp;
use Socket;
use Getopt::Std;
use Exporter;

use RPC::ExtDirect::Server;

use base 'Exporter';

our @EXPORT = qw/
    maybe_start_server
    start_server
    stop_server
/;

### PRIVATE PACKAGE SUBROUTINES ###
#
# Internal use only.
#

{
    my ($server_pid, $server_host, $server_port);
    
    sub get_server_pid { $server_pid };
    sub set_server_pid { $server_pid = shift; };
    
    sub get_server_host { $server_host };
    sub set_server_host { $server_host = shift };
    
    sub get_server_port { $server_port };
    sub set_server_port { $server_port = shift; };
}

### EXPORTED PUBLIC PACKAGE SUBROUTINE ###
#
# See if a host and port were given in the @ARGV, and start a new
# server instance if not.
#

sub maybe_start_server {
    if ( @ARGV ) {
        my %options;
        
        getopt('hp', \%options);
        
        # If a port is given but not the host name, we assume localhost
        $options{h} ||= '127.0.0.1';
        
        return ($options{h}, $options{p}) if $options{p};
    }
    
    return start_server( @_ );
}

### EXPORTED PUBLIC PACKAGE SUBROUTINE ###
#
# Start an RPC::ExtDirect::Server instance, wait for it to bind
# to a port and return the host and port number.
# If an instance has already been started, return its parameters
# instead of starting a new one.
#

sub start_server {
    my (%params) = @_;
    
    {
        my $host = get_server_host;
        my $port = get_server_port;
        
        if ( $port ) {
            return wantarray ? ($host, $port)
                 :             "$host:$port"
                 ;
        }
    }
    
    # This parameter is used for internal testing
    my $sleep        = delete $params{sleep};
    my $timeout      = delete $params{timeout}      || 30;
    my $server_class = delete $params{server_class} ||
                       'RPC::ExtDirect::Server';
    
    # We default to verbose exceptions, which is against Ext.Direct spec
    # but feels somewhat saner and is better for testing
    $params{verbose_exceptions} = 1
        unless defined $params{verbose_exceptions};

    my ($pid, $pipe_rd, $pipe_wr);
    pipe($pipe_rd, $pipe_wr) or die "Can't open pipe: $!";

    if ( $pid = fork ) {
        close $pipe_wr;
        local $SIG{CHLD} = sub { waitpid $pid, 0 };

        # Wait until the kid starts up, but don't block forever either
        my ($host, $port) = eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm $timeout;
            
            my ($host, $port) = split /:/, <$pipe_rd>;
            close $pipe_rd;
            
            alarm 0;
            
            ($host, $port + 0); # Easier than chomp
        };
        
        if ( my $err = $@ ) {
            # If timed out, try to clean up the kid anyway
            eval { kill 2, $pid };
            
            croak $err eq "alarm\n" ? "Timed out waiting for " .
                                      "$server_class instance to start " .
                                      "after $timeout seconds"
                :                     $err
                ;
        }
        
        set_server_pid($pid);
        set_server_host($host);
        set_server_port($port);

        return wantarray ? ($host, $port)
             :             "$host:$port"
             ;
    }
    elsif ( defined $pid && $pid == 0 ) {
        close $pipe_rd;

        srand;
        
        sleep $sleep if $sleep;

        my $forced_port = defined $params{port};

        if ( !$forced_port ) {
           $params{port} = &random_port;
        }

        my $server = $server_class->new(%params);
        
        {
            my $after_setup_listener
                = $server_class->can('after_setup_listener');
            
            no strict 'refs';
            *{$server_class.'::after_setup_listener'} = sub {
                my $self = shift;
                
                my $host = inet_ntoa inet_aton $self->host;
                my $port = $self->port;

                print $pipe_wr "$host:$port\n";
                close $pipe_wr;
                
                $after_setup_listener->($self, @_)
                    if $after_setup_listener;
            };
        }

        # If the port is taken, reroll the random generator and try again
        do {
            eval { $server->run() };

            # If the port was forced by the caller, punt
            die "$@\n" if $forced_port && $@;

            $server->port(&random_port);
        }
        while ( $@ );

        # Should be unreachable, just in case
        exit 0;
    }
    else {
        croak "Can't fork: $!";
    };

    return;
}

### EXPORTED PUBLIC PACKAGE SUBROUTINE ###
#
# Stop previously started server instance
#

sub stop_server {
    my ($pid) = @_;

    $pid = get_server_pid unless defined $pid;

    kill 2, $pid if defined $pid;

    set_server_port(undef);
    set_server_pid(undef);
}

sub random_port { 30000 + int rand 10000 };

# Ensure that the server is stopped cleanly at exit
END { stop_server }

1;
