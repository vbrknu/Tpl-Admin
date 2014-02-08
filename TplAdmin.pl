#!/usr/bin/perl -w
use strict;
use warnings;
use feature 'say';
use Getopt::Long;
use Carp qw( croak carp);
use lib 'lib';
use lib '..\..';

use TPL::Admin::Core qw (
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

# This is a command line interface for TplAdmin
# The output of the program is located in coded_picks.txt in the same directory as this script


$tourney_url = 'http://tt.tennis-warehouse.com/showthread.php?t=487248';

$output_file = 'coded_picks.txt';

GetOptions(
	'oop=i' 	=> \$oop_post,		# post number where the oop is inputted
	'to=i'		=> \$to_post,		# last post that should be looked at
	'slam' 		=> \$slam,		# flag if tournament is slam or not
	'poll' 		=> \$thread_poll,	# flag if thread has a poll or not
	'verbose' 	=> \$verbose,		# verbose cmd line output
) or die "Could not parse command line arguments";

check_if_poll();
get_oop();
main();

