#!/usr/bin/perl
##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use FindBin;
use lib '/usr/local/recoil/lib';
use lib $FindBin::Bin . "/../../lib";

use Data::Dumper;
use App::Recoil::Env;
use App::Recoil::Config;

my $root = shift;

$RED_DEBUG = 1;

my @dirs = (
           "$root/proto",
           "$root/apps/app1/modules/testmod/proto",
           "$root/apps/app1/proto",
           );

my $cfg = red_config_load( 'try', \@dirs );

print STDERR Dumper( $cfg );



