use strict;
use warnings;
use autodie;
use feature 'say';

use lib 'lib';
use TPL::Database::DB_work 'db_handle';

my $dbh = db_handle('lib/TPL/Database/nicknames.db');
my $filename = 'lib/TPL/Database/rankings.txt';
open my $fh, '<', $filename;

while (<$fh>) {
	chomp;
	my ($last_name, $first_name, $country) = split /[,\|]/, $_;
	my $middle_name;
	$country =~ s/^\(//;
	$country =~ s/\)$//;
	
	if ($first_name =~ /\w\s(\w+)/) {
		$middle_name = $1;
	} elsif ($first_name =~ /\w\-(\w+)/) {
		$middle_name = $1;
	}
	
	if (defined $middle_name) {
		my $len 	= length $first_name;
		my $len_substr	= length $middle_name;
		$first_name 	= substr($first_name, 1, ($len - $len_substr) - 1);
		$middle_name =~ s/^\s+|\s+$//g;		
	}

	$first_name =~ s/^\s+|\s+$|\-+$//g ;
	$last_name =~ s/^\s+|\s+$//g ;
	
	my $record = <<'SQL';
INSERT INTO players ( 
	first_name, middle_name,
	last_name, country 
)
VALUES (?, ?, ?, ?)
SQL
	
	my $sth = $dbh->prepare($record);
	$sth->execute($first_name, $middle_name, $last_name, $country);
}

