##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  eXecType Message Server
##
##############################################################################
package Decor::Core::Net::Server;
use strict;
use Exception::Sink;
use Data::Tools;
use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Shared::Net::Protocols;

use parent qw( Net::Waiter );

my $SOCKET_TIMEOUT = 60;
my $SERVER_IDLE_EXIT_ALARM     =  5*60; # seconds
my $SERVER_IDLE_EXIT_ALARM_MIN =  1*60; # seconds
my $SERVER_IDLE_EXIT_ALARM_MAX = 15*60; # seconds

#sub on_accept_ok
#{
#  my $self = shift;
#  my $sock = shift;
#  my $peerhost = $sock->peerhost();
#  print "client connected from $peerhost\n";
#}

sub on_process_xt_message
{
  my $mi = shift;
  my $mo = shift;
  
  boom "on_process_xt_message() must be reimplemented in current class";
  return undef;
}

sub on_process
{
  my $self = shift;
  my $sock = shift;

  # TODO: re/init app name and root
  de_log_debug( "client connected, starting main loop..." );

  my $mc =  0; # message counter
  my $mi = {}; # input message
  my $mo = {}; # output message
  while(4)
    {
    last if $self->{ 'BREAK_MAIN_LOOP' };
    server_idle_begin();
    
    my $ptype;
    ( $mi, $ptype ) = de_net_protocol_read_message( $sock );
    
    $mo = {};
    $mc++;
    server_idle_end();
    de_log_debug( "received message with PTYPE [$ptype]" );

    
    if( ! $mi or ref( $mi ) ne 'HASH' )
      {
      de_log( "error: invalid or empty XTYPE incoming message received" );
      $self->break_main_loop();
      next;
      }

    my $xt = uc $mi->{ 'XT' };
    de_log_dumper( "MI" x 16, $mi );

    # TODO: check incoming message

    my $xt_utime = time();
    my $xt_ref_str  = "$$|$xt|$mc|$xt_utime";
    my $xt_ref_hash = lc md5_hex( $xt_ref_str );

    $mi->{ 'XT_UTIME' } = $xt_utime;
    $mi->{ 'XT_MC'    } = $mc;
    $mi->{ 'XT_REFH'  } = $xt_ref_hash;

    my $xt_handler_res;
    eval
      {
      $xt_handler_res = $self->on_process_xt_message( $mi, $mo );
    de_log_dumper( "MO RES " x 16, "$mo", $mo );
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
    
    my $xs = $mo->{ 'XS' };
    
    if ( $xs !~ /^(OK|E_[A-Z_]+)$/ )
      {
      de_log( "error: invalid or empty XTYPE STATUS (XS) [$xs], ignoring message" );
      # TODO: rollback?
      $mo = {};
      $mo->{ 'XS' } = "E_STATUS";
      }

    de_log_debug( "debug: XTYPE [$xt] XSTATUS [$xs] DBI::errstr [$DBI::errstr]" );

    de_log_dumper( "MO" x 16, $mo );
    my $mo_res = de_net_protocol_write_message( $sock, $ptype, $mo );

    if( $mo_res == 0 )
      {
      de_log( "error: error sending outgoing XTYPE message" );
      $self->break_main_loop();
      next;
      }
    
    }
  de_log_debug( "main loop did exit\n" );
 
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
  de_log_debug( "debug: idle alarm time advised to [$SERVER_IDLE_EXIT_ALARM] seconds" );
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
