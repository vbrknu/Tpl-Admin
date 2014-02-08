#!/usr/bin/perl -w
use strict;
use warnings;
use autodie;
use feature 'say';
use Data::Dump;
use lib 'lib';
use TPL::Database::DB_work qw ( db_handle
                            );

my $dbh = db_handle('lib/TPL/Database/nicknames.db');
my $filename = 'lib/TPL/Database/nicknames.txt';
open my $fh, '<', $filename;

my %records;
while (<$fh>) {
    chomp;
    
    #for this to work, none of the lines inside the braces can contain "|"
    if (/\|/) {
        my ($name, $country) = split /\|/;
        my ($last, $first) = split /,\s*/, $name;
        if ($first =~ /\w\s\w/ ) {
            ($first) = (split /\s/, $first);
        } elsif ($first =~ /\w\-\w/) {
            ($first) = (split /\-/, $first);
        }
        
        ($country) = ($country =~ /\((.*)\)/g);
        
        $records{first} = $first;
        $records{last}  = $last;
        $records{country}  = $country;
    }
    elsif (/,$/) {
        s/^\s+//g;
        s/,//g;
        if ($_) {
            say $_;
            push @{ $records{nicknames} }, $_;    
        }
    }
    
    # End of records, process it
    if (/[})]$/) {
        if ($records{nicknames}) {
            add_nickname_list($records{last}, $records{first}, $records{country}, $records{nicknames});
        }
        # Clear record after processing
        %records = ();
    }  
}

sub add_nickname_list {
	my ( $last, $first, $country, $nicks) = @_;
	my $sql_insert = <<'SQL';
	INSERT OR IGNORE INTO nicks (nick, player_id)
	VALUES (?, ?)
SQL
	
	my $sql_select = <<'SQLL';
	SELECT id FROM players
	WHERE first_name = ? AND last_name = ? AND country = ?
SQLL
	my $sth = $dbh->prepare($sql_select);
	$sth->execute($first, $last, $country);
	my @result_pk = $sth->fetchrow_array;
	
	my $sthn = $dbh->prepare($sql_insert);
	foreach (@$nicks) {
            if (defined $_) {
                $sthn->execute($_, $result_pk[0]);
            } else {
                say "Nickname is undefined";
            }
	}
	
	say "All done inserting nicknames for $first $last";
	
}

