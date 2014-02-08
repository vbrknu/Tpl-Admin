Tpl-Admin
=========

This program is used to help with the scoring of the TPL game that takes place at the tennis talk warehouse forums. It's output is the spreadsheet data that eventually goes into calculating the players' scores.

How to run it
-------------
You can use either the command line by running TplAdmin.pl as a script with several cmd options or the graphical interface by running GUI.pm in lib/TPL/Admin.

How it works
-------------
It simply extracts the posts and additional info in the thread where the game takes place, parses that according to regex rules and processes that data according to the scoring regulation of the game. 
