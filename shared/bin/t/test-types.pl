#!/usr/bin/perl
##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( $ENV{ 'DECOR_ROOT' } || '/usr/local/decor' ) . '/core/lib';
use lib ( $ENV{ 'DECOR_ROOT' } || '/usr/local/decor' ) . '/shared/lib';

use Time::HR;
use Date::Parse;
use Data::Dumper;
use Time::JulianDay;

use Decor::Shared::Types;

type_set_format( { NAME => 'UTIME' }, 'MDY24Z' );
type_set_format( { NAME => 'DATE'  }, 'MDY' );

my $now = time();

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

for( 1..10000)
{
my $utime = type_revert( '1.3.2016 11:11 pm +0000', { NAME => 'UTIME' } );
my $utime_str = type_format( $utime, { NAME => 'UTIME', TZ => 'EET' } );
}

my $e = ( gethrtime() - $s ) / 1000_000_000;

print "revert/format: elapsed $e\n";
