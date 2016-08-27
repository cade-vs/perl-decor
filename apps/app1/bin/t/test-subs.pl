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
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
#use lib ( $ENV{ 'DECOR_ROOT' } || die 'missing DECOR_ROOT env variable' ) . "/core/lib";

use Time::HR;

use Data::Tools;
use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Code;
use Decor::Core::Subs;
#use Decor::Core::DSN;
#use Decor::Core::Profile;
#use Decor::Core::Describe;
#use Decor::Core::DB::IO;
#use Decor::Core::DB::Record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $salt = create_random_id( 512 );

my $mi = { XT => 'BEGIN', USER => 'cade', PASS => };
my $mo = {};
