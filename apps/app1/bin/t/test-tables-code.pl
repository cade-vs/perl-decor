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
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
#use lib ( $ENV{ 'DECOR_ROOT' } || die 'missing DECOR_ROOT env variable' ) . "/core/lib";

use Time::HR;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Code;
#use Decor::Core::DSN;
#use Decor::Core::Profile;
#use Decor::Core::Describe;
#use Decor::Core::DB::IO;
#use Decor::Core::DB::Record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

print "code exists: " . de_code_file_find( 'tables', 'test1' ) . "\n";

my $map = de_code_get_map( 'tables', 'test1' );

print Dumper( $map );

$map->{ 'on_more' }->();
