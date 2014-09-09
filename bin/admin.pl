#!/usr/bin/perl
use strict;
use warnings;
use v5.12;

use Data::Dumper qw(Dumper);
use DBI;
use Getopt::Long qw(GetOptions);

my $dsn = 'dbi:SQLite:dbname=pm.db';
my $dbh = DBI->connect(
	$dsn, '', '',
	{
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}
);

my %opt;
GetOptions(
	\%opt,
	'products',
	'stats',
	'show',
	'list=s',
	'replace=s',

	'addsub=s',
	'email=s',

	'unsub=s',
	'dump'
) or usage();

if ( $opt{email} ) {
	$opt{email} = lc $opt{email};
}

if ( $opt{products} ) {
	my $products = $dbh->selectall_arrayref(
		q{
	   SELECT *
	   FROM product
	}
	);
	if ( $opt{dump} ) {
		print Dumper $products;
	}
	else {
		foreach my $p ( sort { $a->[1] cmp $b->[1] } @$products ) {
			printf "%2s %-35s %-33s %3s\n", @$p;
		}
	}
}
elsif ( $opt{stats} ) {
	my $products = $dbh->selectall_hashref(
		q{
	   SELECT *
	   FROM product
	}, 'id'
	);

	#print Dumper $products;
	my $subs = $dbh->selectall_hashref(
		q{SELECT pid, COUNT(*) cnt FROM subscription GROUP BY pid}, 'pid' );
	my $format = "%-35s %5s\n";
	printf $format, 'Product code', 'Number of subscribers';
	foreach my $pid ( sort keys %$products ) {
		printf $format, $products->{$pid}{code}, ( $subs->{$pid}{cnt} || 0 );
	}
	my $all_subs = $dbh->selectrow_array(
		q{SELECT COUNT(uid) FROM subscription WHERE pid != 1});
	my $distinct_subs = $dbh->selectrow_array(
		q{SELECT COUNT(DISTINCT(uid)) FROM subscription WHERE pid != 1});
	say '-' x 45;
	printf $format, q{Total 'purchases':},     $all_subs;
	printf $format, q{Distinct # of clients:}, $distinct_subs;
	print "\n";
	my $all_users    = $dbh->selectrow_array(q{SELECT COUNT(*) FROM user});
	my $not_verified = $dbh->selectrow_array(
		q{SELECT COUNT(*) FROM user WHERE verify_time is NULL});
	my $no_password
		= $dbh->selectrow_array(
		q{SELECT COUNT(*) FROM user WHERE verify_time is NOT NULL AND password is NULL}
		);
	printf $format, 'All the users', $all_users;
	printf $format, 'Verified', ( $all_users - $not_verified );
	printf $format, 'NOT Verified',             $not_verified;
	printf $format, 'Verified but NO password', $no_password;

}
elsif ( $opt{show} and $opt{email} ) {
	show_people( $opt{email} );
}
elsif ( $opt{replace} and $opt{email} ) {
	replace_email( $opt{email}, $opt{replace} );
}
elsif ( $opt{addsub} and $opt{email} ) {
	my $pid = $dbh->selectrow_array( q{SELECT id FROM product WHERE code = ?},
		undef, $opt{addsub} );
	my $uid = $dbh->selectrow_array( q{SELECT id FROM user WHERE email = ?},
		undef, $opt{email} );
	usage("Could not find product '$opt{addsub}'") if not $pid;
	usage("Could not find user '$opt{email}'")     if not $uid;
	print "PID: $pid  UID: $uid\n";
	$dbh->do( q{INSERT INTO subscription (uid, pid) VALUES (?, ?)},
		undef, $uid, $pid );
	show_people( $opt{email} );
}
elsif ( $opt{unsub} and $opt{email} ) {
	my $pid = $dbh->selectrow_array( q{SELECT id FROM product WHERE code = ?},
		undef, $opt{unsub} );
	my $uid = $dbh->selectrow_array( q{SELECT id FROM user WHERE email = ?},
		undef, $opt{email} );
	print "PID: $pid  UID: $uid\n";
	die 'Could not find product' if not $pid;
	die 'Could not find User'    if not $uid;
	$dbh->do( q{DELETE FROM subscription WHERE uid=? AND pid=?},
		undef, $uid, $pid );
	show_people( $opt{email} );
}
elsif ( $opt{list} ) {
	my $emails = $dbh->selectall_arrayref(
		q{
	   SELECT email
	   FROM user, subscription, product
	   WHERE user.id=subscription.uid
	     AND user.verify_time is not null
	     AND product.id=subscription.pid
	     AND product.code=?
	}, undef, $opt{list}
	);
	foreach my $e ( sort { $a->[0] cmp $b->[0] } @$emails ) {
		say "$e->[0]";
	}
}
else {
	usage();
}
exit;
#######################################################################################################

sub replace_email {
	my ( $old, $new ) = @_;
	show_people($old);
	$dbh->do( q{UPDATE user SET email = ? WHERE email = ?},
		undef, $new, $old );
	show_people($new);
}

sub show_people {
	my ($email) = @_;

	my $people = $dbh->selectall_arrayref(
		q{
	   SELECT id, email, verify_time
	   FROM user WHERE email LIKE ?
	}, undef, '%' . $email . '%'
	);
	foreach my $p (@$people) {
		$p->[2] //= '-';
		my $subs = $dbh->selectall_arrayref(
			q{SELECT product.code
			FROM product, subscription
			WHERE product.id=subscription.pid
			AND subscription.uid=?}, undef, $p->[0]
		);
		printf "%4s %30s  verify_time='%s'\n", @$p;
		foreach my $s (@$subs) {
			printf "     %s\n", @$s;
		}
	}
	return;
}

sub usage {
	my ($msg) = @_;

	if ($msg) {
		print "*** $msg\n\n";
	}

	print <<"END_USAGE";
Usage: $0
    --products                               list of products
    --stats                                  subscription statistics
    --show   --email FILTER_FOR_EMAIL        list users

    --replace NEW_EMAIL --email OLD_EMAIL

    --list PRODUCT                           list all the users who subscribe to this project

    --addsub product --email email\@address  add the specific product to the specific user
    --unsub  product --email email\@address  remove the perl_maven_cookbook from the specific user

Products:
END_USAGE

	my $products = $dbh->selectall_arrayref(
		q{
	   SELECT code, name
	   FROM product
       ORDER BY name
	}
	);
	foreach my $p (@$products) {
		say "   $p->[0]";
	}

	exit;
}

