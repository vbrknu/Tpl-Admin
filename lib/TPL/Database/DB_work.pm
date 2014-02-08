package TPL::Database::DB_work;

use strict;
use warnings;
use autodie;
use DBI;
use Carp 'croak';
use Exporter::NoWork -ALL => qw/default/;
use feature 'say';

sub db_handle {
	my $db_file = shift
		or croak "db_handle() requires a database name";
	no warnings 'once';
	return DBI->connect(
		"dbi:SQLite:dbname=$db_file",
		"", # no username required
		"", # no password required
		{ RaiseError => 1, PrintError => 0, AutoCommit => 1 },
	) or die $DBH::errstr;
}

sub lookup_player_name {
	my $name = shift;
	my ( %data, %alternates );
	my $sql = <<'SQL';
SELECT first_name, last_name, middle_name FROM players 
WHERE last_name = ?
SQL

	my $dbh = db_handle('..\Database\nicknames.db');
	my $sth = $dbh->prepare($sql);
	$sth->execute($name);
	
	while (my @result = $sth->fetchrow_array ) {
		$data{first_name} = $result[0];
		$data{last_name} = $result[1];
		if (defined $result[2]) {
			$data{middle_nameF} = $result[2];
		}
	}
	my @charsFN = split("", $data{first_name});
	my @charsLN = split("", $data{last_name});
	if (defined $data{middle_nameF}) {
		my @charsMN = split("", $data{middle_nameF});
		$alternates{full_name}	= join ' ', $data{first_name}, $data{middle_nameF}, $data{last_name};
		$alternates{capitalized}= join ' ', $charsFN[0].$charsMN[0], $data{last_name};
		$alternates{initials} 	= $charsFN[0].$charsMN[0].$charsLN[0];
	} else {
		$alternates{full_name} = join ' ', $data{first_name}, $data{last_name};
		$alternates{capitalized} = join ' ', $charsFN[0], $data{last_name};
	}
	
	$alternates{last_name} = $data{last_name};
	
	return \%alternates;
	
}

# returns the various combinations that a name could be molded to with the db info ...
sub lookup_player_alts {
	my ($initial, $last_name, $country) = @_;
	my %alternates;
	my $path;
	$initial = substr($initial, 0, 1);
	
	my ($package, $filename, $line) = caller;

	unless (caller) {
		say "Could not resolve where Core was called from";
	} elsif ( $filename =~ /lib/) {
		$path = 'lib\TPL\Database\nicknames.db';
	} else  {
		$path = '..\Database\nicknames.db';
	}
	
	my $sql = <<'SQL';
SELECT last_name , first_name, middle_name FROM players 
WHERE last_name = ? AND SUBSTR(first_name, 1, 1 ) = ?
SQL
	my (@charsMN1, @charsMN2);
	my @charsLN = split("", $last_name);
	my $dbh = db_handle($path);
	my $sth = $dbh->prepare($sql);
	$sth->execute($last_name, $initial);
	
	while (my @result = $sth->fetchrow_array ) {	
		$alternates{full_name} 	= "$result[1] $result[0]";
		$alternates{first_name} = $result[1];
		if ( defined $result[2] ) {
			$alternates{middle_name} = $result[2];
			$alternates{full_name} 	 = "$result[1] $result[2] $result[0]";
		}
	}
	
	if ($last_name =~ /([\w]+)-([\w]+)/i or $last_name =~ /([\w]+)\s([\w]+)/i) {
		$alternates{last_name_split1}    = $1;
		$alternates{last_name_split2}    = $2;
		$alternates{two_namer_space} 	 = "$1 $2";
		$alternates{two_namer_dash}	 = "$1-$2";
		$alternates{two_namer_no_space}  = "$1$2";
	}

	return \%alternates;
	
		 
}

sub add_nickname_list {
	my ( $last, $first, $country, $nicks) = @_;
	
	my $sql_insert = <<'SQL';
	INSERT INTO nicks (nick, player_id)
	VALUES (?, ?)
SQL
	
	my $sql_select = <<'SQLL';
	SELECT id FROM players
	WHERE first_name = ? AND last_name = ? AND country = ?
SQLL
	
	my $dbh = db_handle('..\Database\nicknames.db');
	my $sth = $dbh->prepare($sql_select);
	$sth->execute($first, $last, $country);
	my @result_pk = $sth->fetchrow_array;
	
	my $sthn = $dbh->prepare($sql_insert);
	foreach (@$nicks) {
		$sthn->execute($_, $result_pk[0]);
	}
	
	say "All done inserting nicknames for $first $last";
	
}

sub add_nicknames {
		my ( $name, $nicks ) = @_;

		my $sql = <<'SQL';
INSERT INTO nicks (nick, player_id)
VALUES (?, ?)
SQL
		my $sql_pk = <<'SQLL';
SELECT id FROM players
WHERE last_name = ?
SQLL

		my $dbh = db_handle('..\Database\nicknames.db');
		my $sth = $dbh->prepare($sql_pk);
		$sth->execute($name);
		my @result_pk = $sth->fetchrow_array;
		
		my $sthn = $dbh->prepare($sql);
		
		foreach (@$nicks) {
			$sthn->execute($_, $result_pk[0]);
		}
		
		say "all done";		
}

sub delete_nickname {
		my ( $name, $nick ) = @_;
		
		my $sql_select = <<'SQL';
SELECT id FROM players
WHERE last_name = ?
SQL

		my $sql_del = <<'SQLL';
DELETE FROM nicks
WHERE player_id = ? AND nick = ? 
SQLL

		my $dbh = db_handle('..\Database\nicknames.db');
		my $sth = $dbh->prepare($sql_select);
		$sth->execute($name);
		my @result_pk = $sth->fetchrow_array;

		my $sthn = $dbh->prepare($sql_del);
		$sthn->execute( $result_pk[0], $nick );
		
		say "all done deleting";
}


sub delete_nicknames {
		my ( $name ) = shift;
		
		my $sql_select = <<'SQL';
SELECT id FROM players
WHERE last_name = ?
SQL

		my $sql_del = <<'SQLL';
DELETE FROM nicks
WHERE player_id = ? 
SQLL

		my $dbh = db_handle('..\Database\nicknames.db');
		my $sth = $dbh->prepare($sql_select);
		$sth->execute($name);
		my @result_pk = $sth->fetchrow_array;

		my $sthn = $dbh->prepare($sql_del);
		$sthn->execute( $result_pk[0] );
		
		say "all done deleting";
}

# Retrieves all the nicknames of the player ...
sub get_nicknames {
		my ($first, $last) = @_;
		my @found_nicks;
		my $path;
		my ($package, $filename, $line) = caller;
		
		unless (caller) {
			say "Could not resolve where Core was called from";
		} elsif ( $filename =~ /lib/) {
			 $path = 'lib\TPL\Database\nicknames.db';
		} else  {
			$path = '..\Database\nicknames.db';
		}
		
		my $sql_select = <<'SQL';
SELECT id FROM players
WHERE last_name = ? AND first_name = ?
SQL

		my $sql_sel_nicks = <<'SQLL';
SELECT nick FROM nicks
WHERE player_id = ?
SQLL
		my $dbh = db_handle($path);
		my $sth = $dbh->prepare($sql_select);
		$sth->execute($last, $first);
		my @result_pk = $sth->fetchrow_array;
		
		my $sthn = $dbh->prepare($sql_sel_nicks);
		$sthn->execute($result_pk[0]);

		while ( my @results = $sthn->fetchrow_array ) {
			push @found_nicks, $results[0];
		}
		
		return \@found_nicks;
}

sub lookup_nickname {
		my $nick = shift;
		my $sql_nick = <<'SQL';
SELECT player_id FROM nicks
WHERE nick = ?
SQL

		my $sql_name = <<'SQLL';
SELECT last_name FROM players
WHERE id = ?
SQLL

		my $dbh = db_handle('..\Database\nicknames.db');
		my $sth = $dbh->prepare($sql_nick);
		$sth->execute($nick);
		my @result_fk = $sth->fetchrow_array;
		
		my $sthn = $dbh->prepare($sql_name);
		$sthn->execute( $result_fk[0] );
		my @result_fn = $sthn->fetchrow_array;
		
		return $result_fn[0];
}

sub guess_player {
		my ( $country, $last_name, $first_name) = @_;
		my ( @countries, @last_names, @first_names);
		my $sql_country = <<'SQL';
SELECT country FROM players
SQL

		my $sql_iln = <<'SQLL';
SELECT last_name FROM players
SQLL

		my $sql_ifn = <<'SQLLL';
SELECT first_name FROM players
SQLLL

		my $dbh = db_handle('..\Database\nicknames.db');
		my $sth = $dbh->prepare($sql_country);
		$sth->execute();
		while ( my @db_countries = $sth->fetchrow_array ) { push @countries, $db_countries[0];  }
		
		my $stl = $dbh->prepare($sql_iln);
		$stl->execute();
		while ( my @db_last_names = $stl->fetchrow_array ) { push @last_names, $db_last_names[0]; }
		
		my $stf = $dbh->prepare($sql_ifn);
		$stf->execute();
		while ( my @db_first_names = $stf->fetchrow_array ) { push @first_names, $db_first_names[0]; } 
		
		my @charsFN = split("", $first_name);
		my @charsLN = split("", $last_name);
		
		for my $i (0 .. scalar @last_names - 1) {
			my @chars_currentLN = split("", $last_names[$i]);
			my @chars_currentFN = split("", $first_names[$i]);
			
			if ($charsFN[0] eq $chars_currentFN[0] and
				$charsLN[0] eq $chars_currentLN[0] and
				$country    eq $countries[0] ) {
				return $last_names[$i];
			}
		}
		
		return undef;
}

1;
