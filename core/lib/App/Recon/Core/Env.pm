##############################################################################
##
##  App::Recon application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recon::Core::Env;
use strict;

use Data::Lock qw( dlock );

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                $RED_VERSION
                
                $RED_ROOT
                
                %RED_CONFIG
                @RED_CONFIG_FILES

                $RED_DEBUG
                
                $RED_LISTEN_PORT_DEFAULT
                $RED_LISTEN_PORT
                
                $RED_APP_PRELOAD
                $RED_APP_NAME

                $RED_SSL
                $RED_SSL_KEY_FILE
                $RED_SSL_CRT_FILE
                $RED_SSL_CA_FILE
                $RED_SSL_VERIFY
                $RED_SSL_PEER_CERT
                %RED_SSL_PEER_CERT_SUBJECT
                %RED_SSL_PEER_CERT_ISSUER

                $RED_FOREGROUND
                
                $RED_USE_LOG_FILES
                $RED_DUP_LOG_STDERR


                );



our $RED_VERSION = '1.0';

our $RED_ROOT = $ENV{ 'RECON_ROOT' } || '/usr/local/recon';
unshift @INC, "$RED_ROOT/core/lib";

our %RED_CONFIG;
our @RED_CONFIG_FILES;

our $RED_DEBUG;

dlock our $RED_LISTEN_PORT_DEFAULT = 9900;
our $RED_LISTEN_PORT = $RED_LISTEN_PORT_DEFAULT;

our $RED_APP_PRELOAD;
our $RED_APP_NAME;

our $RED_SSL = 0;
our $RED_SSL_KEY_FILE;
our $RED_SSL_CRT_FILE;
our $RED_SSL_CA_FILE;
our $RED_SSL_VERIFY;
our $RED_SSL_PEER_CERT;

our %RED_SSL_PEER_CERT_SUBJECT;
our %RED_SSL_PEER_CERT_ISSUER;

our $RED_FOREGROUND;

our $RED_USE_LOG_FILES;
our $RED_DUP_LOG_STDERR;

### PRIVATE ##################################################################

our %RE_STATIC_CONFIG;
our %RE_USER_SESSION;
our %RE_RUNTIME_SESSION;

__init_ev();

sub __init_ev
{
  %RE_STATIC_CONFIG   = ();
  %RE_USER_SESSION    = ();
  %RE_RUNTIME_SESSION = ();
  
  $RE_STATIC_CONFIG{ 'VERSION' } = 1.00;
  $RE_STATIC_CONFIG{ 'ROOT'    } = $ENV{ 'RECON_ROOT' } || '/usr/local/recon';
  unshift @INC, $RE_STATIC_CONFIG{ 'ROOT' } . '/core/lib';
}

### PUBLIC ###################################################################

sub rev_version
{
  return $RE_STATIC_CONFIG{ 'VERSION' };
}

sub rev_root
{
  return $RE_STATIC_CONFIG{ 'ROOT' };
}

sub rev_set_debug
{
  my $level  = shift;
  $RE_STATIC_CONFIG{ 'DEBUG' } = $level;
  return $level;
}

sub rev_debug
{
  return $RE_STATIC_CONFIG{ 'DEBUG' };
}

### EOF ######################################################################
1;
