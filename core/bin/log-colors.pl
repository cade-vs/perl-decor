#!/usr/bin/perl
use strict;

INIT { $| = 1; }

my $esc = chr(27) . '[';
while(<>)
  {
  chomp;
  my $clr;
  $clr = "1;31" if /error:/;
  $clr = "36"   if /status:/;
  $clr = "1;33" if /info:/;
  print $esc, $clr, 'm' if $clr;
  print;
  print $esc, '0m' if $clr;
  print "\n";
  }
