#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;

use FindBin;
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../../lib";

use Data::Dumper;
use App::Recon::Core::Env;
use App::Recon::Core::Config;

my $root = $RED_ROOT;

$RED_DEBUG = 1;

my @dirs = (
           "$root/proto",
           "$root/apps/app1/modules/testmod/proto",
           "$root/apps/app1/proto",
           );

print "@dirs";

my $cfg = re_config_load( 'try', \@dirs );

print STDERR Dumper( $cfg );



