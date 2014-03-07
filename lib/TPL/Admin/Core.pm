package TPL::Admin::Core;

use strict;
use warnings;
use autodie;
use feature 'say';
use List::MoreUtils qw(firstidx);
use Carp qw(croak carp);
use LWP::Simple;
use HTML::TableExtract qw(tree);
use Getopt::Long;
use Data::Dump::Color;
use lib '../..';
use TPL::Database::DB_work qw ( db_handle 
				lookup_player_alts
				get_nicknames 
				);

use String::KeyboardDistance qw( qwerty_keyboard_distance_match );
use TPL::RegEx::Regexp qw( $match_pick
			   $picked_oop_match
			   $no_quotes
			   $only_oop_match
			   $valid_poster );

use Exporter 'import';
our @EXPORT_OK = qw (
		  $tourney_url
		  $oop_post
		  $to_post
		  $slam
		  $thread_poll
		  $output_file
		  $verbose
		  check_if_poll
		  get_oop
		  main
		);



no if $] >= 5.017011, warnings => 'experimental::smartmatch';

$||=1;
our ( $tourney_url, $oop_post, $to_post, $slam, $thread_poll, $verbose );
$verbose = 1;
our $last_post_checked;
our $theoop;
our $output_file = '../../../coded_picks.txt';
my $high_pass = 0.8;
my $low_pass  = 0.7;

# This sets up the header of the output, containing all the column names ... 
sub init {
	open OUTPUT_TOP, '>', $output_file;
	format OUTPUT_TOP =
=======================================================================
Username:		 	 Post Nr.	   	   Timestamp:	  Date:	 	 Nr.of picks
========================================================================


.


	write OUTPUT_TOP;

}


# Checks to see if the thread being parsed contains a poll ...
sub check_if_poll {
	my $page = get $tourney_url || croak "GET failed, URL is wrong or there is no Internet connection";
	foreach my $line (split (/<td class="tcat" colspan="4">(.*?)<\/td>/, $page)) {
		if ( $line =~ /View Poll Results/ ) {
			$thread_poll = 1;
		} else {
			$thread_poll = 0;
		}
	}
}

# Puts all the contents of a file in a variable ...
sub slurp_file_to_scalar {
	my $filename = shift;
	my $fh;
	my $contents = do {
		local $/ = undef;
		open $fh, "<", $filename
			or die "could not open $filename: $!";
		<$fh>;
		};
	close $fh;
	return \$contents;
}

# The main flow of the program, processes picks from where indicated ...
sub main {
	init();
	my $page_nr = get_range( $oop_post );
	my $page_nav = "&page=$page_nr";
	$tourney_url = "$tourney_url$page_nav";
	while ( parse_webpage( $tourney_url, $oop_post, $to_post )) {	
		$page_nr++;
		$page_nav = "&page=$page_nr";
		$tourney_url = "$tourney_url$page_nav";
		$page_nav = "";
	}
	
}

# If set, displays detailed info at the command line ...
sub llog {
	my ( $arg ) = shift @_;
	if ( $verbose ) {
		unless ( ref $arg ) {
			if ( defined $arg ) {
				print "$arg\n";
			} else {
				carp "Argument to llog is not defined";
			}
		} elsif ( ref $arg eq 'ARRAY') {
			dd ( @$arg );
		} elsif ( ref $arg eq 'HASH') {
			dd ( %$arg );
		}
		else {
			print "Couldn't parse llog arguments\n";
		}
	} 
}


# gets the order of play from the post that was pointed at ...
sub get_oop {
	if ( get_range( $oop_post ) > 1 ) {
		$tourney_url .= '&page='. get_range( $oop_post );
		$theoop = scan_for_oop( $tourney_url, $oop_post );
	} else {
		$theoop = scan_for_oop( $tourney_url, $oop_post );
	}
}

# returns the thread page number where the called post number falls in ...
sub get_range {
	my $nr = shift;
	my $range = int( ( $nr-1 ) / 20 ) + 1;
	return $range;
}

# inverts the date format in mm-dd-yy ...
sub convert_date {
	my $date = shift;
	my ( $mm, $dd, $yy );
	if ( $date =~ /\b(\d{2})-(\d{2})-(\d{4})\b/ ) {
		$mm = $1;
		$dd = $2;
		$yy = $3;
	}
	else {
		llog "Something went wrong when trying to convert the date";
	}

	return join "-", ( $mm, $dd, $yy );
}

# returns a SORTED ARRAY of HASHREFS ...
sub sortDS {
	my $ref = shift;
	return 	map  { { $_ => $ref->{$_} } }
		sort { $ref->{$a}{playerId} <=> $ref->{$b}{playerId} } keys %$ref;
	
}

# searches the html retrieved for the order of play in the required format ...
sub scan_for_oop {
	my $url = shift @_;
	my $oop_postNr = shift @_;
	my $content	= get($url);
	my @order_of_play;

	my @iterator;
	if ( $thread_poll ) {
		@iterator = grep {$_ % 2 == 1} 5 .. 43;
	} else {
		@iterator = grep {$_ % 2 == 0} 4 .. 42;
	}
	
	for my $i (@iterator) {
		my $extractor	= HTML::TableExtract->new( attribs => { class => "tborder", cellpadding => 6, cellspacing => 0, border => 0, width => "100%", align => "center"}, 
													depth 	=> 0, 
													count 	=> $i, 
													strip_html_on_match => 1, );
		
		$extractor->parse($content);
		my $table = $extractor->tree;
		my $table_tree = $table->tree;

		my $time_and_date 	= ${$table_tree->rows->[0]}[0]->as_text or die $!;
		my $postNr 		= ${$table_tree->rows->[0]}[1]->as_text or die $!;
		my $poster 		= ${$table_tree->rows->[1]}[0]->as_text or die $!;
		my $post 		= ${$table_tree->rows->[1]}[1]->as_text or die $!;
		
		#Getting the post number properly
		$postNr =~ s/[^0-9]//g;
		#Getting rid of wide chars
		$post =~ s/[^[:ascii:]]+//g;
		
		if ( $post !~ /$no_quotes/ and  $postNr == $oop_postNr) {
			while ( ( $post =~ /$only_oop_match/g ) ) {
				push @order_of_play, $1;
			}
			last;
		}
	}
	
	return \@order_of_play;
}

# this checks players' picks up against the order of play ...
sub check_with_oop {
	my $theoop = shift @_;
	my $players = shift @_;
	my ( $name, $date, $time, $post_number, $nr_of_picks, @picks, @oop_matches );
	foreach my $record (@$players) {
		foreach my $key ( keys %{$record} ) {
			$name = $key;
			$date = $record->{$key}->{date_and_time};
			$time = $record->{$key}->{time_of_post};
			$post_number = $record->{$key}->{thread_post_nr};
			$nr_of_picks = keys ${$record}{$key}{picks};
			foreach my $pick (keys ${$record}{$key}{picks}){
				for (keys ${$record}{$key}{picks}[$pick]) {
					my $current_pick = $_;
					my $first_match  = firstidx { $_ eq $current_pick } @$theoop;
					if ( $first_match >= 0 ) {
						$picks[$pick] = join ' ', $_, $record->{$key}->{picks}[$pick]{$_};
						$oop_matches[$pick] = $first_match;
					} else {
						$picks[$pick] = '?'; 
					}
				}
			}
			my @nonmatched;
			foreach ( 0 .. $#$theoop ) {
				if ( $_ ~~ @oop_matches ) {
					next;
				} else {
					push @nonmatched, $_ ;
				}
			}
			process_picks($name, $date, $time, $post_number, $nr_of_picks, $slam, \@picks, \@nonmatched);
			@picks = ();
		}
	}
}

# codes up the picks for the first player in a match ...
sub process_first_pos {
	my ($bestOf5, $nbOfSets, $playerPicked) = @_;
	my $thisPick;
	if    ( (!$bestOf5 and $nbOfSets eq "2" ) or ( $bestOf5 and $nbOfSets eq "3") ) { $thisPick = "a";}
	elsif ( (!$bestOf5 and $nbOfSets eq "3" ) or ( $bestOf5 and $nbOfSets eq "4") ) { $thisPick = "b";}
	elsif                                        ( $bestOf5 and $nbOfSets eq "5") 	{ $thisPick = "c";}
	else 										{ $thisPick = "?";
			                                                                llog "Bad number of sets for the $playerPicked pick."; }

	return $thisPick;
}

# codes up the picks for the second player in a match ...
sub process_second_pos {
	my ($bestOf5, $nbOfSets, $playerPicked) = @_;
	my $thisPick;
	if    ( (!$bestOf5 and $nbOfSets eq "2" ) or ( $bestOf5 and $nbOfSets eq "3") ) { $thisPick = "x";}
	elsif ( (!$bestOf5 and $nbOfSets eq "3" ) or ( $bestOf5 and $nbOfSets eq "4") ) { $thisPick = "y";}
	elsif                                        ( $bestOf5 and $nbOfSets eq "5") 	{ $thisPick = "z";}
	else 										{ $thisPick = "?";
			                                                                llog "Bad number of sets for the $playerPicked pick."; }

	return $thisPick;
}

# checks a string if it's made up of two words ...
sub check_two_namer {
	my ($name, $initial) = @_;
	my $initials;
	if ($name =~ /([\w]+)-([\w]+)/i or $name =~ /([\w]+)\s([\w]+)/i) {
		my @charsL1 = split("", $1);
		my @charsL2 = split("", $2);
		$initials = $initial.$charsL1[0].$charsL2[0];
			
	} else {
		my @charsL1 = split("", $name);
		$initials = $initial.$charsL1[0];
	}
	
	return $initials;
}

# checks if called string is lexically anywhere near similar with any of the nicknames indicated ...
sub nickname_spellcheck {
	my ( $playerPicked, $nicknames )= @_;
	
	foreach (@$nicknames) {
		if ( qwerty_keyboard_distance_match ($playerPicked, $_) > $low_pass ) {
			return 1;
		}
	}	
	return undef;
}

# the picks are processed and formatted in their final state and saved as output ...
sub process_picks {
	my ( $name, $date, $time, $post_number, $nr_of_picks, $bestOf5, $matchPicks, $oop_matches ) = @_;
	open OUTPUT, '>>', $output_file;
	my ( @codedPicks, @failedPicks);
	my $similar_player_names;
	
	foreach(@$matchPicks){ 		
		next unless /\bvs\b/; 	
		my ( $thisPick, $nbOfSets, $initials_first, $initials_second, $first_oop_format, $second_oop_format);
		
		if ( /$match_pick/ ){
		
		my ($firstI, $first, $first_country, $secondI, $second, $second_country, $playerPicked) = ($1, $2, $3, $4, $5, $6, $7);
		$nbOfSets = $8;
		
		$initials_first	 = check_two_namer( $first, $firstI);
		$initials_second = check_two_namer( $second, $secondI);
		
		$playerPicked 	=~ s/\s$//;
		$first		=~ s/\s$//;
		$second 	=~ s/\s$//;
		
		$first_oop_format	 = "$firstI $first";
		$second_oop_format	 = "$secondI $second";

		if ( qwerty_keyboard_distance_match($first, $second) > $high_pass ) {
			$similar_player_names = 1;
		} else {
			$similar_player_names = 0;
		}
		
		
		if ( $first =~ /$playerPicked/xi or $initials_first =~ /$playerPicked/i or $first_oop_format =~ /$playerPicked/i ){ 	
			$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
		}
		elsif ( $second =~ /$playerPicked/xi or $initials_second =~ /$playerPicked/i or $second_oop_format =~ /$playerPicked/i ){  
			$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
		}
		elsif ( $similar_player_names == 0 and qwerty_keyboard_distance_match($first, $playerPicked) > $low_pass ) {
			$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
		}
		elsif ( $similar_player_names == 0 and ( qwerty_keyboard_distance_match($second, $playerPicked) > $low_pass )) {
			$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
		}
		elsif ( $similar_player_names == 0 and qwerty_keyboard_distance_match( $first_oop_format, $playerPicked) > $low_pass ) {
			$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
		}
		elsif ( $similar_player_names == 0 and qwerty_keyboard_distance_match( $second_oop_format, $playerPicked) > $low_pass ) {
			$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
		}
		elsif	( defined $first ) {
			my $player_data = lookup_player_alts($firstI, $first, $first_country);
			my $nicknames 	= get_nicknames(${$player_data}{first_name}, $first);
				
			if ( (defined ${$player_data}{full_name}) and ( ( ${$player_data}{full_name} =~ /$playerPicked/i ))) {	
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ((defined ${$player_data}{full_name}) and ( $similar_player_names == 0 )
				and qwerty_keyboard_distance_match ( ${$player_data}{full_name}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{first_name} ) and ( ( ${$player_data}{first_name} =~ /$playerPicked/i ))) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( (defined ${$player_data}{first_name}) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{first_name}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{middle_name} ) and ( ${$player_data}{middle_name} =~ /$playerPicked/i )){
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( (defined ${$player_data}{middle_name}) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{middle_name}, $playerPicked ) > $high_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{two_namer_no_space} ) and ( ${$player_data}{two_namer_no_space} =~ /$playerPicked/i )) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{two_namer_no_space} ) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{two_namer_no_space}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{two_namer_space} ) and ( ${$player_data}{two_namer_space} =~ /$playerPicked/i )) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{two_namer_space} ) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{two_namer_space}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{last_name_split1} ) and ( ${$player_data}{last_name_split1} =~ /$playerPicked/i )) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{last_name_split1} ) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{last_name_split1}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{last_name_split2} ) and ( ${$player_data}{last_name_split2} =~ /$playerPicked/i )) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{last_name_split2} ) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{last_name_split2}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{two_namer_dash}) and ( ${$player_data}{two_namer_dash} =~ /$playerPicked/i )) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( defined ${$player_data}{two_namer_dash}) and ( $similar_player_names == 0 )
				 and qwerty_keyboard_distance_match ( ${$player_data}{two_namer_dash}, $playerPicked ) > $low_pass ) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			}
			elsif ( ( /$playerPicked/i ~~ @$nicknames ) or ( nickname_spellcheck ($playerPicked, $nicknames ))) {
				$thisPick = process_first_pos($bestOf5, $nbOfSets, $playerPicked);
			} 
			unless ( defined $thisPick ) {
				if ( ( defined $second ) ) {
					my $player_data = lookup_player_alts($secondI, $second, $second_country );
					my $nicknames 	= get_nicknames(${$player_data}{first_name}, $second);
					if ( (defined ${$player_data}{full_name}) and ( ( ${$player_data}{full_name} =~ /$playerPicked/i ))) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( (defined ${$player_data}{full_name}) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{full_name}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{first_name} ) and ( ( ${$player_data}{first_name} =~ /$playerPicked/i ))) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{first_name} ) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{first_name}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{middle_name} ) and ( ${$player_data}{middle_name} =~ /$playerPicked/i )){
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{middle_name} ) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{middle_name}, $playerPicked ) > $high_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{two_namer_no_space} ) and ( ${$player_data}{two_namer_no_space} =~ /$playerPicked/i )) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif (( defined ${$player_data}{two_namer_no_space} ) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{two_namer_no_space}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{two_namer_space} ) and ( ${$player_data}{two_namer_space} =~ /$playerPicked/i )) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{two_namer_space} ) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{two_namer_space}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{last_name_split1} ) and ( ${$player_data}{last_name_split1} =~ /$playerPicked/i )) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{last_name_split1} ) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{last_name_split1}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{last_name_split2} ) and ( ${$player_data}{last_name_split2} =~ /$playerPicked/i )) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{last_name_split2} ) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{last_name_split2}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{two_namer_dash}) and ( ${$player_data}{two_namer_dash} =~ /$playerPicked/i )) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( defined ${$player_data}{two_namer_dash}) and ( $similar_player_names == 0 )
						 and qwerty_keyboard_distance_match ( ${$player_data}{two_namer_dash}, $playerPicked ) > $low_pass ) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					}
					elsif ( ( /$playerPicked/i ~~ @$nicknames ) or ( nickname_spellcheck ($playerPicked, $nicknames ))) {
						$thisPick = process_second_pos($bestOf5, $nbOfSets, $playerPicked);
					} 
					else { $thisPick = "?";
						llog "Bad player name:$_";
					}
				}
				else {	$thisPick = "?";
					llog "Bad player name:$_";
				}
			}
		}
		else {
		$thisPick = "?";
		llog "Bad player name:$_";
			
		} 
		} 
		else {
			$thisPick = "?";
			llog "I don't understand this pick:$_"; 
			}
	push @codedPicks, $thisPick; 
	}

	foreach (@$oop_matches) {
		splice @codedPicks, $_, 0, '!';
	}

	@failedPicks = grep { $codedPicks[$_] =~ /\?/ } 0..$#codedPicks;
	my @failed = (@$oop_matches, @failedPicks);
	my $picks_string = join ",", @codedPicks;
	my @oop_matches_nonm = grep { $_++ } @failed;
	my $oop_m_string = join " ", @oop_matches_nonm;

	format OUTPUT =
@>>>>>>>>>>>>>>>>>>>>>>>>>>>>  		@||||	 	@>>>>>>>>>>	@>>>>>>>>>>>	@>>
$name,								$post_number, 	$time,		$date,			$nr_of_picks,
----------------------------------------------------------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$oop_m_string,
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$picks_string,




.
	write OUTPUT;
	close OUTPUT;

}

# does the html parsing of the page, retrieved all the data that will be processed further ...
sub parse_webpage {
	my $url = shift;
	my $from_post = shift;
	my $to_post = shift;
	my $players;
	my $ipl = 0;
	my $exit_flag = undef;
	my $content = get($url) ;
	my @iterator;
	if ( $thread_poll ) {
		@iterator = grep {$_ % 2 == 1} 5 .. 43;
	} else {
		@iterator = grep {$_ % 2 == 0} 4 .. 42;
	}
	
	for my $i (@iterator) {
		my $extractor	= HTML::TableExtract->new(  attribs => { class => "tborder", cellpadding => 6, cellspacing => 0,
									 border => 0, width => "100%", align => "center"}, 
									depth 	=> 0, 
									count 	=> $i, 
									strip_html_on_match => 1 );
		
		$extractor->parse($content);
		my $table = $extractor->tree;
		my $table_tree = $table->tree;
		
		#Getting the post number properly and checking if it's ahead or equal to the post we're supposed to be looking for
		my $postNr = ${$table_tree->rows->[0]}[1]->as_text; 			
		$postNr =~ s/[^0-9]//g;
		$last_post_checked = $postNr;
		
		if ( !defined ($to_post ) ) { 
			if ( $postNr < $from_post) {
				next;
			} 
		} elsif ( $postNr < $from_post ) {
			next;
		}
		
		my $time_and_date 	= ${$table_tree->rows->[0]}[0]->as_text;
		my $poster 		= ${$table_tree->rows->[1]}[0]->as_text;
		my $post 		= ${$table_tree->rows->[1]}[1]->as_text;		
		
		#Getting the username
		my @poster 	= split (/$valid_poster/, $poster);
		my $postr 	= $poster[0];	
		
		#Getting rid of wide chars
		$post =~ s/[^[:ascii:]]+//g;
		
		#Getting the date and time
		my @Date_and_Time = split(',', $time_and_date, 2);
		if ($Date_and_Time[0] =~ /Today/ ) 		{ $Date_and_Time[0] = "Today"; }
		elsif ( $Date_and_Time[0] =~ /Yesterday/ ) 	{ $Date_and_Time[0] = "Yesterday";}
		else { $Date_and_Time[0] = convert_date($Date_and_Time[0]); }
		$Date_and_Time[1] =~ s/^\s+|\s+$//g;
		
	
		#Getting the post
		my $userId = 0;
		
		if ( $postr =~ /seffina/ and $post =~ /___!([[:print:]]+)!___/) {
			$postr = $1;
		}
		
		if ( ( $post =~ /$picked_oop_match/ ) and ( $post !~ /$no_quotes/) and $postNr > 3 ) { 
			while ( $post =~ /$picked_oop_match/g ){
				$players->{$postr}{picks}[$userId++]{$1} = $2;
			}
		} elsif ( $postNr == $to_post ) {
			$exit_flag = 1;
			last;
		} else {
			next;
		}
		
		$players->{$postr}{playerId} 		= $ipl;
		$players->{$postr}{date_and_time} 	= $Date_and_Time[0];
		$players->{$postr}{time_of_post} 	= $Date_and_Time[1];
		$players->{$postr}{thread_post_nr} 	= $postNr;
		$ipl++;
		if ( $postNr >= $to_post or $exit_flag ) {
			last;
		}
	}
	my @players = sortDS($players);
	check_with_oop($theoop, \@players);
	if ($last_post_checked == $to_post or $exit_flag ) {
		return undef;
	}
		
	return $last_post_checked;
}

CHECK {
	unless ( defined $verbose) {
		carp "Verbosity has not been set";
	}
}

1;
