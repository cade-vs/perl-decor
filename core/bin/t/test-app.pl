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
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../../lib";

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Application;

$Data::Dumper::Indent = 3;

my $root = de_root();

de_set_debug( 1 );

my $app = Decor::Core::Application->new( 'app1' );
$app->init( $root );

print STDERR Dumper( $app );

my $des = $app->describe_table( 'test1' );

print STDERR Dumper( $des );




