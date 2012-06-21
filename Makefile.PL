use 5.006000;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'RPC::ExtDirect::Server',
    VERSION_FROM      => 'lib/RPC/ExtDirect/Server.pm',

    ($ExtUtils::MakeMaker::VERSION >= 6.55
        ? ( BUILD_REQUIRES => {
                'WWW::Mechanize' => 0,
            },
            PREREQ_PM => {
                'RPC::ExtDirect' => '1.31',
                'CGI::ExtDirect' => '1.12',
            },
        )
        : ( PREREQ_PM         => {
                'WWW::Mechanize' => 0,
                'RPC::ExtDirect' => '1.31',
                'CGI::ExtDirect' => '1.12',
            },
        )
    ),
    ABSTRACT => 'CGI-based Ext.Direct server',
    AUTHOR   => 'Alexander Tokarev <tokarev@cpan.org>',
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

