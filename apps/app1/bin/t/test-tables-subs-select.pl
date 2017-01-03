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
use Decor::Core::Log;
use Decor::Core::Utils;

use Data::Lock qw( dlock dunlock );

use Storable qw( dclone );
use Clone qw( clone );

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

de_init( APP_NAME => 'app1' );
de_debug_set( 11 );
$DE_LOG_TO_STDERR = 1;
$DE_LOG_TO_FILES  = 1;

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

#----------------------------------------------------------------------

my %filter;

%filter = (
          SUMA => '0.9464',
          );

%filter = (
          SUMA => { OP => '>', VALUE => '0.5' },
          );
          
%filter = (
          REF => [ qw( 10075 10077 10079 ) ],
          );

my $mi = { XT => 'S', TABLE => 'test1', FIELDS => '*', FILTER => \%filter };
my $mo = {};
subs_process_xt_message( $mi, $mo );

print Dumper( $mo );

my $select_handle = $mo->{ 'SELECT_HANDLE' };

while( 4 )
  {
  my $mi = { XT => 'FETCH', 'SELECT_HANDLE' => $select_handle };
  my $mo = {};

  subs_process_xt_message( $mi, $mo );

  print Dumper( $mi, $mo );
  last unless $mo->{ 'XS' } eq 'OK';
  }

#----------------------------------------------------------------------

my $mi = { XT => 'FINISH', 'SELECT_HANDLE' => $select_handle };
my $mo = {};
subs_process_xt_message( $mi, $mo );

print Dumper( $mo );
