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

use FindBin;
use lib '/usr/local/decor/shared/lib';
use lib $FindBin::Bin . "/../../lib";

use Time::HR;

use Date::Parse;
use Data::Dumper;
use Decor::Shared::Types::Native;

my $t = new Decor::Shared::Types::Native;

$t->set_format( { NAME => 'UTIME' }, '%d.%m.%Y %H:%M:%S %z %Z' );

my $now = time();

my $s = gethrtime();

#for( 1..2000)
#{
my $now_s = $t->format( $now, { NAME => 'UTIME' } );
print "$now_s (local)\n";
my $now_s = $t->format( $now, { NAME => 'UTIME', TZ => 'EET' } );
print "$now_s (EET)\n";
my $now_s = $t->format( $now, { NAME => 'UTIME', TZ => 'GMT' } );
print "$now_s (GMT)\n";
#}

my $e = ( gethrtime() - $s ) / 1000_000_000;

print "elapsed $e\n";

my $then = str2time( $now_s );

print " now: $now\nthen: $then\n";
