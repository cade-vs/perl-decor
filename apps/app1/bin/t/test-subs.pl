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

use Data::Tools;
use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Code;
use Decor::Core::Subs;
use Decor::Core::DSN;
#use Decor::Core::Profile;
#use Decor::Core::Describe;
#use Decor::Core::DB::IO;
#use Decor::Core::DB::Record;
use Decor::Core::Utils;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $salt = create_random_id( 512 );

#----------------------------------------------------------------------

my $mi = { XT => 'PREPARE', USER => 'test' };
my $mo = {};

subs_process_xt_message( $mi, $mo );

print Dumper( $mi, $mo );

#----------------------------------------------------------------------

my $user_salt  = $mo->{ 'USER_SALT'  };
my $login_salt = $mo->{ 'LOGIN_SALT' };

my $mi = { XT => 'BEGIN', USER => 'test', PASS => de_password_salt_hash( de_password_salt_hash( 'test123', $user_salt ), $login_salt ) };
my $mo = {};

subs_process_xt_message( $mi, $mo );

print Dumper( $mi, $mo );

dsn_commit();
