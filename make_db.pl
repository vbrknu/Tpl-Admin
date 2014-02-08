use strict;
use warnings;

use lib 'lib';
use TPL::Database::DB_work 'db_handle';

my $dbh = db_handle('lib/TPL/Database/nicknames.db');

my $sql_players = <<"SQL";
CREATE TABLE IF NOT EXISTS players (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	first_name	VARCHAR(55) NOT NULL,
	middle_name	VARCHAR(55),
	last_name	VARCHAR(55) NOT NULL,
	country		VARCHAR(3) NOT NULL
);
SQL
$dbh->do($sql_players);

my $sql_nicknames = <<"SQL";
CREATE TABLE IF NOT EXISTS nicks (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	nick		VARCHAR(255) NOT NULL UNIQUE,
	player_id	INTEGER NOT NULL,
	FOREIGN KEY (player_id) REFERENCES players(id)
);
SQL
$dbh->do($sql_nicknames);



