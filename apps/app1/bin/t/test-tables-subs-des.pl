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

use Data::Lock qw( dlock dunlock );

use Storable qw( dclone );
use Clone qw( clone );

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );

my $salt = create_random_id( 512 );

#----------------------------------------------------------------------

my $mi = { XT => 'PREPARE', USER => 'test', REMOTE => 'local' };
my $mo = {};

subs_process_xt_message( $mi, $mo );

print Dumper( $mi, $mo );

#----------------------------------------------------------------------

my $user_salt  = $mo->{ 'USER_SALT'  };
my $login_salt = $mo->{ 'LOGIN_SALT' };

my $mi = { XT => 'BEGIN', USER => 'test', PASS => de_password_salt_hash( de_password_salt_hash( 'test123', $user_salt ), $login_salt ), REMOTE => 'local' };
my $mo = {};

subs_process_xt_message( $mi, $mo );

print Dumper( $mi, $mo );

my $t = gethrtime();
for( 1..1_00 )
{
  my $mi = { XT => 'D', TABLE => 'test1' };
  my $mo = {};
  subs_process_xt_message( $mi, $mo );

  #print Dumper( $mo );
  
}
$t = ( gethrtime() - $t ) / 1_000_000_000;
my $ps = 1_00 / $t;
print "$t secs, $ps per second\n";


my $mi = { XT => 'D', TABLE => 'test1' };
my $mo = {};
subs_process_xt_message( $mi, $mo );

print Dumper( $mo );

my $mi = { XT => 'M', MENU => 'main' };
my $mo = {};
subs_process_xt_message( $mi, $mo );

print Dumper( $mo );
