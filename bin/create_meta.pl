#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;

use File::Basename qw(basename dirname);
use Getopt::Long qw(GetOptions);
use YAML qw(LoadFile);

use lib 'lib';
use Perl::Maven::Config;
use Perl::Maven::Meta;

binmode( STDOUT, ':encoding(UTF-8)' );
binmode( STDERR, ':encoding(UTF-8)' );

# Run with any value on the command line to get debugging info

my $cfg     = LoadFile('config.yml');
my $mymaven = Perl::Maven::Config->new( $cfg->{mymaven_yml} );

GetOptions(
	'verbose' => \my $verbose,

	#	'all'      => \my $all,
);
$ENV{METAMETA} = 1;

my $domain_name = $mymaven->{config}{installation}{domain};
my $meta        = Perl::Maven::Meta->new(
	verbose => $verbose,
	mymaven => $mymaven,
);
$meta->process_domain($domain_name);

#if ($all) {
#	for my $domain_name ( keys %{ $mymaven->{config} } ) {
#		my $meta = Perl::Maven::Meta->new(
#			verbose => $verbose,
#			mymaven => $mymaven,
#		);
#		$meta->process_domain($domain_name);
#	}
#}
#else {
#	usage('Missing domain') if not $domain_name;
#	usage("Invalid site '$domain_name'")
#		if not $mymaven->{config}{$domain_name};
#	my $meta = Perl::Maven::Meta->new(
#		verbose => $verbose,
#		mymaven => $mymaven,
#	);
#	$meta->process_domain($domain_name);
#}

exit;
###############################################################################
sub usage {
	my ($msg) = @_;

	print "*** $msg\n\n";
	print "Usage $0\n";
	print "         --verbose\n";
	exit;
}

