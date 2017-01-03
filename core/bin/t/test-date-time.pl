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
use Date::Format qw( strftime );
use Time::JulianDay;

my @t = ( 12, 34, 2115 );
my $s = strftime( "%H:%M:%S %p", @t );

print "$s\n";

#----------------------------------------------------------------------------

my ( $y, $m, $d ) = inverse_julian_day( 2457439 );

my @t = ( undef, undef, undef, $d, $m - 1, $y - 1900 );

my $da = strftime( '%Y.%m.%d', @t, 'GMT' );

print "$da ( $y, $m, $d )\n";

#----------------------------------------------------------------------------

my @t = localtime(time());

my $ut = strftime( "%d.%m.%Y %H:%M:%S", @t, 'GMT' );

print "$ut\n";
