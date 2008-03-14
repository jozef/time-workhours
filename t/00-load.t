#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DateTime::WorkingHours' );
}

diag( "Testing DateTime::WorkingHours $DateTime::WorkingHours::VERSION, Perl $], $^X" );
