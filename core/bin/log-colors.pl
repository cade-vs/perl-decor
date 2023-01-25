#!/usr/bin/perl
##############################################################################
##
##  small log colorizer
##  2021-2022 (c) Vladi Belperchinov-Shabanski "Cade"
##                http://cade.noxrun.com
##                      <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

INIT { $|++; }

my $esc = chr(27) . '[';
while(<>)
  {
  chomp;
  my $clr;
  $clr = "1;31" if /error:|fatal:|compilation failed/;
  $clr = "36"   if /status:/;
  $clr = "1;33" if /info:/;
  print $esc, $clr, 'm' if $clr;
  print;
  print $esc, '0m' if $clr;
  print "\n";
  }
