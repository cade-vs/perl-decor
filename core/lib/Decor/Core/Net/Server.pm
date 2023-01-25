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
##  eXecType Message Server
##
##############################################################################
package Decor::Core::Net::Server;
use strict;
use Data::Dumper;
use Exception::Sink;
use Data::Tools;
use Data::Tools::Socket;
use Net::Waiter 1.02;

use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Shared::Net::Protocols;
use Decor::Core::Subs::Env;

use parent qw( Net::Waiter );

my $SOCKET_TIMEOUT = 60;
my $SERVER_IDLE_EXIT_ALARM     =  5*60; # seconds
my $SERVER_IDLE_EXIT_ALARM_MIN =  1*60; # seconds
my $SERVER_IDLE_EXIT_ALARM_MAX = 15*60; # seconds

sub break_main_loop
{
  my $self = shift;

  de_log_debug( "breaking main loop..." );
  $self->SUPER::break_main_loop();
}

sub on_accept_ok
{
  my $self = shift;
  my $sock = shift;
  binmode( $sock );
  my $peerhost = $sock->peerhost();
  de_log_debug( "client connected from $peerhost" );
  if( $self->ssl_in_use() )
    {
    my $cn = $self->get_client_socket()->peer_certificate( 'cn' );
    de_log_debug( "peer certificate COMMON NAME [$cn]\n" );
    }
}

sub on_process_xt_message
{
  my $mi = shift;
  my $mo = shift;
  
  boom "on_process_xt_message() must be reimplemented in current class";
  return undef;
}

sub on_process_begin_reset
{
  my $self = shift;
  my $socket = shift;

  # usually nothing...
  return 1;
}

sub on_process
{
  my $self   = shift;
  my $socket = shift;

  # TODO: re/init app name and root
  de_log_debug( "client connected, begin reset & starting main loop..." );
  $self->on_process_begin_reset( $socket );

  my $mc =  0; # message counter
  my $mi = {}; # input message
  my $mo = {}; # output message
  while(4)
    {
    if( $self->{ 'BREAK_MAIN_LOOP' } )
      {
      de_log_debug( "exiting main loop..." );
      last;
      }
    server_idle_begin();
    
    my $ptype;
    my $nerr;
    ( $mi, $ptype, $nerr ) = de_net_protocol_read_message( $socket );

    if( $nerr eq 'E_COMM' )
      {
      de_log( "status: end of communication channel" );
      return;
      #$self->break_main_loop();
      #next;
      }
    
    $mo = {};
    $mc++;
    server_idle_end();
    de_log_debug( "received message with PTYPE [$ptype]" );

    
    if( ! $mi or ref( $mi ) ne 'HASH' )
      {
      de_log( "error: invalid or empty XTYPE incoming message received" );
      return;
      #$self->break_main_loop();
      #next;
      }

    my $xt = uc $mi->{ 'XT' };
    de_log_dumper2( "MIMI" x 16, $mi );

    # TODO: check incoming message

    my $xt_utime = time();
    my $xt_ref_str  = "$$|$xt|$mc|$xt_utime";
    my $xt_ref_hash = lc md5_hex( $xt_ref_str );

    $mi->{ 'XT_UTIME' } = $xt_utime;
    $mi->{ 'XT_MC'    } = $mc;
    $mi->{ 'XT_REFH'  } = $xt_ref_hash;

    eval
      {
      $self->on_process_xt_message( $mi, $mo, $socket );
      # de_log_dumper2( "HANDLER MO RES " x 8, "$mo", $mo );
      };
    if( $@ )
      {
      my $ev = $@;
      $ev =~ s/^BOOM: +\[\d+\] +//;
#      my $err_ref = create_random_id( 9, 'ABCDEFGHJKLMNPQRTVWXY0123456789' ); # print read safe
#      de_log( "error: XTYPE handler exception err_ref [$err_ref] details [$ev]\n" );
#      $mo->{ 'XS' } = $ev || "E_INTERNAL: exception err_ref [$err_ref]";
      $mo->{ 'XS' } = $ev || "E_INTERNAL: unexpected exception [@_]";
      subs_disable_manual_transaction();
      eval { dsn_rollback(); }; # FIXME: eval/break-main-loop
      if( $@ )
        {
        de_log( "error: DSN ROLLBACK exception [$@]" );
        return;
        #$self->break_main_loop();
        #next;
        }
      }
    elsif( ! subs_in_manual_transaction() )
      {
      eval { dsn_commit(); };
      if( $@ )
        {
        de_log( "error: DSN COMMIT exception [$@]" );
        return;
        #$self->break_main_loop();
        #next;
        }
      }  
    
    my $xs = $mo->{ 'XS' };
    
    if ( $xs =~ /^(OK|E_[A-Z_0-9]+)(:\s*(.*?))?/ )
      {
      $mo->{ 'XS'     } = uc $1;
      # $mo->{ 'XS_MSG' } =    $3; # error details message will not be reported back to client!
      }
    else  
      {
      de_log( "error: invalid or empty XTYPE STATUS (XS) [$xs], ignoring message" );
      # TODO: rollback?
      $mo = {};
      $mo->{ 'XS' } = "E_STATUS";
      return;
      #$self->break_main_loop();
      #next;
      }

    if( $xs ne 'OK' )
      {
      my $err_ref = create_random_id( 9, 'ABCDEFGHJKLMNPQRTVWXY0123456789' ); # print read safe
      $mo->{ 'XS_ERR_REF' } = $err_ref;
      de_log( "error: XTYPE [$xt] XSTATUS [$xs] DBI::errstr [$DBI::errstr] err_ref [$err_ref]" );
      }
    else
      {
      de_log_debug( "debug: XTYPE [$xt] XSTATUS [$xs]" );
      }  

    de_log_dumper2( "MOMO" x 16, $mo );
    my $send_file_name = $mo->{ '___SEND_FILE_NAME' };
    my $send_file_size = $mo->{ '___SEND_FILE_SIZE' };
    delete $mo->{ '___SEND_FILE_NAME' };
    delete $mo->{ '___SEND_FILE_SIZE' };
    $mo->{ '___FILE_SIZE' } = $send_file_size if $send_file_size > 0;
    
    my $mo_res = de_net_protocol_write_message( $socket, $ptype, $mo );

    if( $mo_res == 0 )
      {
      de_log( "error: error sending outgoing XTYPE message, breaking main loop..." );
      return;
      #$self->break_main_loop();
      #next;
      }

    if( $send_file_name and $send_file_size > 0 )
      {
      open( my $fi, '<', $send_file_name );
      binmode( $fi );

      my $read_size = 0;
      my $buf_size = 1024*1024;
      my $read;
      while(4)
        {
        my $data;
        $read = read( $fi, $data, $buf_size );
        $read_size += $read;
        my $write = socket_write( $socket, $data, $read );
        last if $read < $buf_size;
        }
      close( $fi );
      # TODO: check if read_size == send file size, boom and disconnect on error
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
