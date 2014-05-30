use 5.006000;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'RPC::ExtDirect::Server',
    VERSION_FROM      => 'lib/RPC/ExtDirect/Server.pm',

    PREREQ_PM         => {
        'RPC::ExtDirect'       => '3.00',
        'CGI::ExtDirect'       => '3.00',
        'HTTP::Server::Simple' => '0.44',
    },
    ABSTRACT => 'Prepackaged pure Perl Ext.Direct server',
    AUTHOR   => 'Alex Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',

    ($ExtUtils::MakeMaker::VERSION >= 6.46
        ? ( META_MERGE => {
                resources => {
                    bugtracker => 'http://github.com/nohuhu/RPC-ExtDirect-Server/issues',
                    repository => 'http://github.com/nohuhu/RPC-ExtDirect-Server',
                },
            },
        )
        : ()
    ),
);

