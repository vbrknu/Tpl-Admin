package TPL::RegEx::Regexp;

use strict;
use warnings;
use autodie;
use feature 'say';
use Exporter 'import';
our @EXPORT_OK = qw( $match_pick
		     $picked_oop_match
		     $no_quotes
		     $only_oop_match
		     $valid_poster );

our $match_pick = qr /
			([A-Z]{1,2})		# initials of player
			\s
			([A-Za-z\']+		# name, also covers names like O'Brien, O'Connell etc
			-?
			[A-Za-z\. ]*)		# in case of two namers
			\(([A-Z]{3})\)		# country code
			\s?	
			vs[.]?			# the vs which is mandatory for the oop
			\s?
			(?:\[\d{1,2}\]|\[WC\]|\[Q\]|\[LL\])? # ignores the bracketed info like WC or Q, LL
			\s?
			([A-Z]{1,2})		
			\s?
			([A-Za-z\']+
			-?
			[A-Za-z\. ]*)
			\(([A-Z]{3})\)
			\W*			# match and pick could be separated by punctuation char
			([A-Za-z\']+		# name
			-?
			[A-Za-z\. ]*)		# in case of two namer
			in \s?		
			(\d{1}) 		# number of sets chosen
		    /msx;

our $picked_oop_match = qr /
			([A-Z]{1,2}
			\s
			[A-Za-z\']+
			-?
			[A-Za-z\. ]*
			\([A-Z]{3}\)
			\s?
			vs[.]?
			\s?
			\[?[[:alnum:]]+?\]?	# also consuming the bracketed info that might appear
			\s?
			[A-Z]{1,2}
			\s?
			[A-Za-z\']+
			-?
			[A-Za-z\. ]*
			\([A-Z]{3}\))
			\W*		
			([A-Za-z\']+
			-?
			[A-Za-z\. ]* 			
			in \s?		
			\d{1}) 		
		    /msx;			


our $only_oop_match = qr /
			([A-Z]{1,2}
			\s
			[A-Za-z\']+
			-?
			[A-Za-z\. ]*
			\([A-Z]{3}\)
			\s?
			vs[.]?
			\s?
			\[?[[:alnum:]]+?\]?
			\s?
			[A-Z]{1,2}
			\s?
			[A-Za-z\']+
			-?
			[A-Za-z\. ]*
			\([A-Z]{3}\))
		    /sx;

our $no_quotes = qr /
		  (?<=\s)			# matching whatever follows
		  (Originally\sPosted)		# string that denotes quote
		/x;

our $valid_poster = qr /
			(?<=\s)
			(Banned
			|Guest
			|New\sUser
			|Rookie
			|Semi-Pro
			|Professional
			|Hall\sOf\sFame
			|Legend
			|G.O.A.T.
			|Bionic\sPoster)
		    /x;





