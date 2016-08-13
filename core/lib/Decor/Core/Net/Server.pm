##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Net::Server;
use strict;
use Exception::Sink;
#use Data::Tools::
use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Shared::Net::Protocols;

use parent qw( Net::Waiter );

my $SOCKET_TIMEOUT = 60;
my $SERVER_IDLE_EXIT_ALARM
my $SERVER_IDLE_EXIT_ALARM_MIN =  1*60; # seconds
my $SERVER_IDLE_EXIT_ALARM_MAX = 10*60; # seconds

#sub on_accept_ok
#{
#  my $self = shift;
#  my $sock = shift;
#  my $peerhost = $sock->peerhost();
#  print "client connected from $peerhost\n";
#}

sub on_process
{
  my $self = shift;
  my $sock = shift;

  my $mc = 0; # message counter
  my $mi;     # input message
  my $mo;     # output message
  while(4)
    {
    last if $self->{ 'BREAK_MAIN_LOOP' };
    server_idle_begin();
    
    $mi = de_net_protocol_read_message( $sock, $SOCKET_TIMEOUT );
    $mo = {};
    $hc++;
    server_idle_end();
    
    if( ! $mi or ref( $mi ) ne 'HASH' )
      {
      de_log( "error: invalid or empty XTYPE incoming message received" );
      $self->break_main_loop();
      next;
      }

    my $xt = uc $mi->{ 'XT' };
    de_debug_dumper( "MI" x 16, $mi );

    # TODO: check incoming message

    my $xt_utime = time();
    my $xt_ref_str  = "$$|$xt|$mc|$xt_utime";
    my $xt_ref_hash = lc md5hex( $xt_ref_str );

    my $xt_table = 'MAIN'; # FIXME: change on XT message
    my $xt_handler = $XT_TABLE{ $xt_table }{ $xt };
    
    my $xs;
    if( $xt_handler )
      {
      eval
        {
        my $xt_handler_res = $xt_handler( $mi, $mo, { NET_WAITER_OBJ => $self, SOCKET => $sock, } );
        };
      if( $@ or ! $xt_handler_res )
        {
        de_log( "error: XTYPE handler returned error [$xt_handler_res] or exception [$@]" );
        eval { dsn_rollback(); }; # FIXME: eval/break-main-loop
        if( $@ )
          {
          de_log( "error: DSN ROLLBACK exception [$@] breaking main looop" );
          $self->break_main_loop();
          next;
          }
        }
      else
        {
        eval { dsn_commit(); };
        if( $@ )
          {
          de_log( "error: DSN COMMIT exception [$@] breaking main looop" );
          $self->break_main_loop();
          next;
          }
        }  
      }
    else  
      {
      de_log( "error: unknown or forbidden message type received XTYPE [$xt], ignoring message" );
      $mo->{ 'XS' } = 'E_UNKNOWN_MESSAGE';
      }
    
    if ( $mo->{ 'XS' } !~ /^(OK|E_[A-Z_]+)$/ )
      {
      my $xs = $mo->{ 'XS' };
      de_log( "error: invalid or empty XTYPE STATUS (XS) [xs], ignoring message" );
      # TODO: rollback?
      $mo = {};
      $mo->{ 'XS' } = "E_STATUS";
      }

    de_debug( "debug: XTYPE [$xt] XSTATUS [$xs] DBI::errstr [$DBI::errstr]" );

    my $mo_res = de_net_protocol_write_message( $sock, $mo, $SOCKET_TIMEOUT );

    if( $mo_res == 0 )
      {
      de_log( "error: error sending outgoing XTYPE message" );
      $self->break_main_loop();
      next;
      }
    
    de_debug_dumper( "HO" x 16, $ho );
    my $write_res = de_net_protocol_write_message( $sock, $ho );
    }
  
}

#-----------------------------------------------------------------------------

sub server_idle_exit_handler
{
  de_log( "status: server idle exit alarm triggered [$SERVER_IDLE_EXIT_ALARM] sec, breaking main loop" );
  exit;
}

sub server_idle_alarm_set
{
  my $idle_alarm_seconds = shift;
  if( $idle_alarm_seconds > 0 )
    {
    # idle alarm cap
    $idle_alarm_seconds = $SERVER_IDLE_EXIT_ALARM_MAX if $idle_alarm_seconds > $SERVER_IDLE_EXIT_ALARM_MAX;
    $idle_alarm_seconds = $SERVER_IDLE_EXIT_ALARM_MIN if $idle_alarm_seconds < $SERVER_IDLE_EXIT_ALARM_MIN;
    }
  else
    {
    $idle_alarm_seconds = 0;
    }
  $SERVER_IDLE_EXIT_ALARM = $idle_alarm_seconds;
  de_log( "debug: idle alarm time advised to [$SERVER_IDLE_EXIT_ALARM] seconds" );
}

sub server_idle_begin
{
  return unless $SERVER_IDLE_EXIT_ALARM > 0;
  $SIG{ 'ALRM' } = \&server_idle_exit_handler;
  alarm( $SERVER_IDLE_EXIT_ALARM );
}

sub server_idle_end
{
  return unless $SERVER_IDLE_EXIT_ALARM > 0;
  alarm( 0 );
}

#-----------------------------------------------------------------------------

### EOF ######################################################################
1;
