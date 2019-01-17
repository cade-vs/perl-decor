#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( $ENV{ 'DECOR_ROOT' } || '/usr/local/decor' ) . '/core/lib';
use lib ( $ENV{ 'DECOR_ROOT' } || '/usr/local/decor' ) . '/shared/lib';

use Time::HR;
use Time::HiRes;
use Date::Parse;
use Data::Dumper;
use Time::JulianDay;
use Data::Tools;
use Data::Tools::Math;

use Decor::Shared::Types;

type_set_format( { NAME => 'UTIME' }, 'MDY24Z' );
type_set_format( { NAME => 'DATE'  }, 'MDY' );



my $now = Time::HiRes::time();
print "$now (now)\n";
my $now_s = type_format( $now, { NAME => 'UTIME', DOT => 6, FMT => 'YMD12Z' } );
print "$now_s (local)\n";

my $rev = type_revert( $now_s, { NAME => 'UTIME', DOT => 6 } );
print "$rev (rev)\n\n";


my $now_s = type_format( 123.0456, { NAME => 'TIME', DOT => 4 } );
print "$now_s\n";

my $rev = type_revert( $now_s, { NAME => 'TIME', DOT => 6 } );
print "$rev (rev)\n\n";


$now_s = "2018.07.23 02:34:43";
my $rev = type_revert( $now_s, { NAME => 'UTIME', DOT => 6 } );
print "$rev (rev) $now_s\n\n";


 
my $now_s = type_format( 1532302710.1234, { NAME => 'UTIME', DOT => 0 } );
print "$now_s\n";

exit;








my $s = gethrtime();

#for( 1..2000)
#{
my $now_s = type_format( $now, { NAME => 'UTIME' } );
print "$now_s (local)\n";
my $now_s = type_format( $now, { NAME => 'UTIME', TZ => 'EET' } );
print "$now_s (EET)\n";
my $now_s = type_format( $now, { NAME => 'UTIME', TZ => 'GMT' } );
print "$now_s (GMT)\n";
#}

my $e = ( gethrtime() - $s ) / 1000_000_000;

print "elapsed $e\n";

my $then = str2time( $now_s );

print " now: $now\nthen: $then\n-----------------------------\n\n";

my $time = type_revert( '11:44 pm', { NAME => 'TIME' } );
my $time_str = type_format( $time, { NAME => 'TIME' });
print "res time=[$time] $time_str\n";

my $date = type_revert( '14.3.2016', { NAME => 'DATE' } );
my $date_str = type_format( $date, { NAME => 'DATE' });
print "res date=[$date] $date_str\n";


my $utime = type_revert( '1.3.2016 11:11 pm +0000', { NAME => 'UTIME' } );
my $utime_str = type_format( $utime, { NAME => 'UTIME', TZ => 'EET' } );
print "res date=[$utime] $utime_str\n";


my $s = gethrtime();

my $loopcnt = 10000;
for( 1..$loopcnt)
{
my $utime = type_revert( '1.3.2016 11:11 pm +0000', { NAME => 'UTIME' } );
my $utime_str = type_format( $utime, { NAME => 'UTIME', TZ => 'EET' } );
}

my $e = ( gethrtime() - $s ) / 1000_000_000;

print "UTIME revert/format: $loopcnt loops: elapsed $e\n";
