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

type_set_format( { NAME => 'UTIME' }, 'DMY24Z' );
type_set_format( { NAME => 'DATE'  }, 'DMY' );



my $now = Time::HiRes::time();
my $now_s = type_format( $now, { NAME => 'UTIME' } );
print "[$now] $now_s (now)\n";

my $date = type_convert( $now, 'UTIME' => 'DATE' );
my $date_s = type_format( $date, { NAME => 'DATE' } );
print "[$date] $date_s\n";

my $time = type_convert( $now, 'UTIME' => 'TIME', { TZ => 'GMT' } );
my $time_s = type_format( $time, { NAME => 'TIME' } );
print "[$time] $time_s\n";

print "----------------------------\n";

my $date = type_utime2date( $now );
my $date_s = type_format( $date, { NAME => 'DATE' } );
print "[$date] $date_s\n";

my $time = type_utime2time( $now, 'GMT' );
my $time_s = type_format( $time, { NAME => 'TIME' } );
print "[$time] $time_s\n";

print "----------------------------\n";
my ( $date, $time ) = type_utime_split( $now, 'GMT' );
my $date_s = type_format( $date, { NAME => 'DATE' } );
print "[$date] $date_s\n";
my $time_s = type_format( $time, { NAME => 'TIME' } );
print "[$time] $time_s\n";

my $utime = type_utime_merge( $date, $time, 'GMT' );
my $now_s = type_format( $utime, { NAME => 'UTIME', TZ => 'EET' } );
print "[$now] $now_s (now)\n";

print "----------------------------\n";
