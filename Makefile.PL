use 5.006000;
use ExtUtils::MakeMaker;

# Add the `devtest` target to run regression and POD tests in one go
sub MY::postamble {
    return <<'END';
devtest :
	REGRESSION_TESTS=1 POD_TESTS=1 $(MAKE) test

END
}

# Override `disttest` so it would behave as `devtest`
sub MY::dist_test {
    return <<'END';
disttest : distdir
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) devtest $(PASTHRU)

END
}

my $mm_version = $ExtUtils::MakeMaker::VERSION;

WriteMakefile(
    NAME              => 'RPC::ExtDirect::Server',
    VERSION_FROM      => 'lib/RPC/ExtDirect/Server.pm',

    ($mm_version >= 6.5503 
      ? (
            BUILD_REQUIRES => {
                'HTTP::Tiny'            => '0.014',
                'Test::More'            => '0.82',
            },
            PREREQ_PM      => {
                'RPC::ExtDirect'        => '3.00',
                'CGI::ExtDirect'        => '3.00',
                'HTTP::Server::Simple'  => '0.44',
            },
        )
     : (
            PREREQ_PM      => {
                'HTTP::Tiny'            => '0.014',
                'Test::More'            => '0.82',
                'RPC::ExtDirect'        => '3.00',
                'CGI::ExtDirect'        => '3.00',
                'HTTP::Server::Simple'  => '0.44',
            },
       ),
    ),

    ABSTRACT => 'A tiny but capable pure Perl Ext.Direct server',
    AUTHOR   => 'Alex Tokarev <tokarev@cpan.org>',
    LICENSE  => 'perl',

    ($mm_version >= 6.46
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

