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

use Time::HR;

use Data::Dumper;
use Data::Tools;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::DSN;
use Decor::Core::Subs;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::DB::IO;
use Decor::Core::DB::Record;
use Decor::Core::Utils;
use Decor::Core::Menu;

use Data::Lock qw( dlock dunlock );

use Storable qw( dclone );
use Clone qw( clone );

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $menu = de_menu_get( 'MAIN' );

print Dumper( 'MAIN ' x 10, $menu );

#my $menu = de_menu_get( 'TEST' );

#print Dumper( 'TEST ' x 10, $menu );
