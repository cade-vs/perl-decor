##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil;

use POSIX ":sys_wait_h";
use Socket;
use IO::Socket;
use IO::Socket::INET;
use FileHandle;
use App::Recoil::Env;
use App::Recoil::Protocols;
use App::Recoil::NetworkDaemon;
use App::Recoil;
use App::Recoil::Log;

use strict;

##############################################################################

our $HELP = <<END;
usage: $0 <options>
options:
    -R rootdir       -- set root dir (mandatory!)
    -p port          -- listen port (default $RED_LISTEN_PORT_DEFAULT)
    -r               -- log only to STDERR (no log files)
    -rr              -- log to STDERR and logfiles
    -d               -- debug mode, multiple use is ok
                        (also DEBUG environment var)
    -e app_name      -- preload application
    -s               -- require SSL to connect
    -sk key_file     -- key file for SSL (implies -s)
    -sc crt_file     -- certificate file for SSL (implies -s)
    -sa ca_file      -- require signed cert for SSL (implies -s)
    -c configfile    -- use this config file (can be used multiple times)

END

##############################################################################

sub red_nd_get_opts
{
  my @args_in = @_;

  my @args_out;
  while( @_ )
    {
    $_ = shift;
    if( /^--+$/io )
      {
      push @args_out, @ARGV;
      last;
      }
    if( /^-R/ )
      {
      $RED_ROOT = shift;
      next;
      }
    if( /-p(\d*)/ )
      {
      $RED_LISTEN_PORT = $1 || shift;
      next;
      }
    if( /^-e/ )
      {
      $RED_APP_PRELOAD = shift;
      next;
      }
    if( /^-sk/ )
      {
      $RED_SSL_KEY_FILE = shift;
      $RED_SSL          = 1;
      next;
      }
    if( /^-sc/ )
      {
      $RED_SSL_CRT_FILE = shift;
      $RED_SSL          = 1;
      next;
      }
    if( /^-sa/ )
      {
      $RED_SSL_CA_FILE  = shift();
      $RED_SSL          = 1;
      $RED_SSL_VERIFY = 0x03; # verify + fail if no cert
      next;
      }
    if( /^-s/ )
      {
      $RED_SSL          = 1;
      next;
      }
    if( /^-r(r)?/ )
      {
      $RED_USE_LOG_FILES  = 0;
      $RED_USE_LOG_FILES  = 1 if $1 eq 'r';
      $RED_DUP_LOG_STDERR = 1 if $1 eq 'r';
      next;
      }
    if( /^-d/ )
      {
      $RED_DEBUG++;
      next;
      }
    if( /^-f/ )
      {
      $RED_FOREGROUND = 1;
      next;
      }
    if( /^-c/ )
      {
      my $cf = shift;
      die "config file not readable [$cf]\n" unless -r $cf;
      push @CONFIG_FILES, $cf;
      next;
      }
    if( /^(--?h(elp)?|help)$/io )
      {
      print $HELP;
      exit;
      }
    push @args_out, $_;
    }

  #use IO::Socket::SSL qw(debug3);
  if( $RED_SSL )
    {
    eval { require IO::Socket::SSL; };
    die "SSL not available: $@" if $@;
    };
    
  return @args_out;  
}

##############################################################################

sub main
{
  my @args_in = @_;

  my @args = red_nd_get_opts( @args_in );
  
  # todo: handle other types of connections... ?
  red_start_network_daemon( @args );
}  

###EOF########################################################################

1;
