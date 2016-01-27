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
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../../lib";

use Time::HR;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Stage;
use Decor::Core::Profile;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $stage = Decor::Core::Stage->new( 'app1' );
$stage->init( de_root() );

print STDERR Dumper( $stage );

print STDERR '='x80;

my $tables_list = $stage->get_tables_list();

print STDERR Dumper( 111, $tables_list );

my $tables_list = $stage->get_tables_list();

print STDERR Dumper( 222, $tables_list );
