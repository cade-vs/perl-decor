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
my $des = $app->describe_table( 'test1' );

my $fields = $des->{ 'CACHE' }{ 'TEST1' };

print STDERR '='x80;

print STDERR Dumper( $des );
print STDERR Dumper( [ $des->fields() ] );
print STDERR Dumper( $des->get_table_des() );
print STDERR Dumper( $des->get_field_des( 'NAME' ) );




