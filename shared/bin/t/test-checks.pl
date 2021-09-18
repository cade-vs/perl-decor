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
use Date::Parse;
use Data::Dumper;
use Time::JulianDay;

use Decor::Shared::Utils;

print "enter file name/path?\n";
while(<>)
  {
  chomp;
  print de_check_fpath( $_ ) ? 'OK' : 'INVALID';
  print "\n";
  }
