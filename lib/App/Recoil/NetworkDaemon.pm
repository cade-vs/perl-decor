##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  network daemon
##
##############################################################################
package App::Recoil::NetworkDaemon;
use strict;

use POSIX ":sys_wait_h";
use Socket;
use IO::Socket;
use IO::Socket::INET;
use FileHandle;
use App::Recoil::Env;
use App::Recoil::Protocols;
use App::Recoil;
use App::Recoil::Log;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_start_network_daemon

                );

##############################################################################

my $break_main_loop = 0;

sub red_start_network_daemon
{
  red_set_log_prefix( "core" );

  $SIG{ 'INT'  } = sub { $break_main_loop = 1; };
  $SIG{ 'CHLD' } = \&__red_child_sub;
  $SIG{ 'USR1' } = \&red_reopen_logs;

  red_log( "status: network daemon started at: " . scalar( localtime() ) );
  red_log( "FOREGROUND mode: will accept only 1 client" ) if $RED_FOREGROUND;
  red_log( "DEBUG mode enabled: verbose messages will be printed"   ) if $RED_DEBUG;
  red_log( "SSL enabled:   only encrypted connections will be accepted" ) if $RED_SSL;
  red_log( "SSL key file:  $RED_SSL_KEY_FILE" ) if $RED_SSL_KEY_FILE;
  red_log( "SSL crt file:  $RED_SSL_CRT_FILE" ) if $RED_SSL_CRT_FILE;
  red_log( "SSL CA  file:  $RED_SSL_CA_FILE"  ) if $RED_SSL_CA_FILE;
  red_log( "SSL verify:    $RED_SSL_VERIFY"   ) if $RED_SSL_VERIFY;

########################## FIXME  red_init() or die "fatal: init failed\n";

  my $server_socket;
  my $server_ssl_trap_error;

  if( $RED_SSL )
    {
    my %ssl_opts;

    $ssl_opts{ SSL_key_file    } = $RED_SSL_KEY_FILE if $RED_SSL_KEY_FILE;
    $ssl_opts{ SSL_cert_file   } = $RED_SSL_CRT_FILE if $RED_SSL_CRT_FILE;
    $ssl_opts{ SSL_ca_file     } = $RED_SSL_CA_FILE  if $RED_SSL_CA_FILE;
    $ssl_opts{ SSL_verify_mode } = $RED_SSL_VERIFY   if $RED_SSL_VERIFY;
    $ssl_opts{ SSL_error_trap  } = sub { shift; $server_ssl_trap_error = shift; },

    $server_socket = IO::Socket::SSL->new(  
                                           Proto     => 'tcp',
                                           LocalPort => $RED_LISTEN_PORT,
                                           Listen    => 128,
                                           ReuseAddr => 1,
                                           
                                           %ssl_opts,
                                         );
    }
  else
    {
    $server_socket = IO::Socket::INET->new( 
                                            Proto     => 'tcp',
                                            LocalPort => $RED_LISTEN_PORT,
                                            Listen    => 128,
                                            ReuseAddr => 1,
                                          );
    }

  if( ! $server_socket )
    {
    red_log( "fatal: cannot open server port $RED_LISTEN_PORT: $!" );
    exit 100;
    }
  else
    {
    red_log( "status: listening on port $RED_LISTEN_PORT" );
    }

  ################# FIXME red_sys_connect( $SYSTEM ) if $SYS_PRELOAD;

  while(4)
    {
    last if $break_main_loop;
    my $client_socket = $server_socket->accept();
    if( ! $client_socket )
      {
      red_log( "fatal: $server_ssl_trap_error" ) if $RED_SSL and $server_ssl_trap_error;
      next;
      }

    my $peerhost = $client_socket->peerhost();
    my $peerport = $client_socket->peerport();
    my $sockhost = $client_socket->sockhost();
    my $sockport = $client_socket->sockport();


    red_log( "info: connection from $peerhost:$peerport to $sockhost:$sockport (me)" );
    # FIXME: check allowed/forbidden hosts...

    my $pid;
    if( ! $RED_FOREGROUND )
      {
      $pid = fork();
      if( ! defined $pid )
        {
        die "fatal: fork failed: $!";
        }
      if( $pid )
        {
        red_log( "status: new process forked, pid = $pid" );
        next;
        }
      }
    # --------- child here ---------

    # reinstall signal handlers in the kid
    $SIG{ 'INT'  } = sub { $break_main_loop = 1; };
    $SIG{ 'CHLD' } = 'DEFAULT';
    $SIG{ 'USR1' } = \&red_reopen_logs;

    if( $RED_SSL )
      {
      my $subject  = $client_socket->peer_certificate( "subject" );
      my $issuer   = $client_socket->peer_certificate( "issuer"  );
      
      $RED_SSL_PEER_CERT = Net::SSLeay::PEM_get_string_X509( $client_socket->peer_certificate() ) if $RED_SSL_CA_FILE;

      red_log( "debug: SSL cert subject: $subject" );
      red_log( "debug: SSL cert  issuer: $issuer"  );
      red_log( "debug: SSL cert    x509: $RED_SSL_PEER_CERT" );
      cert_line_parse( \%RED_SSL_PEER_CERT_SUBJECT, $subject );
      cert_line_parse( \%RED_SSL_PEER_CERT_ISSUER,  $issuer  );
      }

    red_log( "debug: ----- new process spawned, peer: $peerhost:$peerport -----" );
    
    $client_socket->autoflush( 1 );
    
    red_protocols_process( $client_socket );
    
    $client_socket->close();
    
    if( ! $RED_FOREGROUND )
      {
      red_log( "debug: ----- process did end -----" );
      exit();
      }
    # ------- child ends here -------
    }
  close( $server_socket );

  red_log( "status: exit at " . scalar( localtime() ) );

}

##############################################################################

sub __red_child_sub
{
  my $kid;
  while( ( $kid = waitpid( -1, WNOHANG ) ) > 0 )
    {
    red_log( "status: sigchld received [$kid]" );
    }
  $SIG{ 'CHLD' } = \&__red_child_sub;
}

###EOF########################################################################

1;
