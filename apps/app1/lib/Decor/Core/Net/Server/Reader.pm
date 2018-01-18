##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  This is custom server module to process generic messages while  
##  Decor app environment is preloaded. 
##  Check DECOR_ROOT/core/bin/decor-core-app-server.pl
##
##  To run this server module:
##
##  ./decor-core-app-server.pl -e app1 -u reader
##
##  For more information, check docs/custom-server-modules.txt
##
##############################################################################
package Decor::Core::Net::Server::Reader;
use strict;
use Exception::Sink;
use Decor::Core::Subs;
use Decor::Core::Log;
use Decor::Shared::Utils;
use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::DB::Record;
use Decor::Core::Subs::Env;
use Decor::Core::Profile;
use Decor::Core::Describe;
use Decor::Core::Menu;
use Decor::Core::Code;
use Decor::Core::DSN;

use parent qw( Decor::Core::Net::Server );

sub on_process_xt_message
{
  my $self = shift;
  my $mi   = shift;
  my $mo   = shift;
  my $socket = shift;


  my $xt = $mi->{ 'XT' };
  
  eval
  {
  return sub_read( $mi, $mo ) if uc $xt eq 'READ';
  die "unknown MESSAGE TYPE [$xt]\n";
  };
  if( $@ )
    {
    %$mo = ();
    $mo->{ 'XS'     } = "E_ERROR";
    $mo->{ 'XS_DES' } = $@;
    }

  return 1;
}

#-----------------------------------------------------------------------------

sub sub_read
{
  my $mi   = shift;
  my $mo   = shift;
  
  my $table  = uc $mi->{ 'TABLE'  };
  my $id     =    $mi->{ 'ID'     };

  boom "invalid TABLE name [$table]"    unless de_check_name( $table ) or ! des_exists( $table );
  boom "invalid ID [$id]"               if $id ne '' and ! de_check_id( $id );

  if( $id <= 0 )
    {
    $mo->{ 'XS' } = 'E_NOTFOUND';
    return;
    }

  my $io = new Decor::Core::DB::IO;
  
  my $hr = $io->read_first1_by_id_hashref( $table, $id );

  if( ! $hr )
    {
    $mo->{ 'XS' } = 'E_NOTFOUND';
    return;
    }
  
  $mo->{ 'DATA' } = $hr;
    
  $mo->{ 'XS' } = 'OK';
}

sub sub_insert
{
  my $mi   = shift;
  my $mo   = shift;

  die "insert not yet implemented\n";
  
}

sub sub_update
{
  my $mi   = shift;
  my $mo   = shift;
  
  die "update not yet implemented\n";
  
}

### EOF ######################################################################
1;
