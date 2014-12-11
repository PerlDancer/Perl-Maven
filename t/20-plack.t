use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Cwd qw(getcwd);
use Carp::Always;

use t::lib::Test;
t::lib::Test::setup();

use Dancer2;

#set log => 'debug';
#set startup_info => 0;
set( appdir => getcwd() );

is config->{'appdir'}, getcwd(), 'appdir';
is config->{'mymaven_yml'}, 'config/mymaven.yml', 'mymaven';

use Perl::Maven;

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
	my $cb  = shift;
	my $res = $cb->( GET 'http://test-perl-maven.com/' );
	is $res->code, 200;
	like( $res->content, qr{<title>Perl Maven - for people who want to get the most out of programming in Perl</title>},
		'main page' );
};

done_testing;
