#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use open ':std', ':encoding(UTF-8)';

use Data::Tools;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::Net::Server::App;
use Decor::Shared::Net::Protocols;
use Decor::Shared::Utils;

INIT { $| = 1; }

my $DEFAULT_SERVER_MODULE_PREFIX = "Decor::Core::Net::Server::";
my $DEFAULT_SERVER_MODULE        = "App";

my $opt_app_name;
my $opt_no_fork = 0;
my $opt_preload = 0;
my $opt_listen_port = 42000;
my $opt_net_protocols = '*';
my $server_module = $DEFAULT_SERVER_MODULE;

our $help_text = <<END;
usage: $0 <options>
options:
    -p port   -- port number for incoming connections (default $opt_listen_port)
    -f        -- run in foreground (no fork) mode
    -e app    -- preload application (will serve only single app)
    -t psj    -- allow network protocol formats (p=storable,s=stacker,j=json)
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    -rc       -- use ANSI-colored STDERR log messages (same as -rrc)
    -u srvmod -- server module (default: App) AVOID IF UNSURE! USE -e FIRST!
    --        -- end of options
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -fd is invalid, correct is: -f -d
END

if( @ARGV == 0 )
  {
  print $help_text;
  exit;
  }

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /-f/ )
    {
    $opt_no_fork = 1;
    print "status: option: run in foreground (no fork) mode\n";
    next;
    }
  if( /-p/ )
    {
    $opt_listen_port = shift;
    print "status: option: listening on port [$opt_listen_port]\n";
    next;
    }
  if( /-u/ )
    {
    die "-e must be specified before -u!\n" unless $opt_preload;
    $server_module = shift;
    $server_module = uc( substr( $server_module, 0, 1 ) ) . lc( substr( $server_module, 1 ) );
    die "invalid server module name [$server_module] check -u parameter!\n" unless de_check_name( $server_module );
    print "status: option: using server module [$DEFAULT_SERVER_MODULE_PREFIX$server_module]\n";
    next;
    }
  if( /-r(r)?(c)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    $DE_LOG_STDERR_COLORS = $2 ? 1 : 0;
    print "status: option: forwarding logs to STDERR\n";
    next;
    }
  if( /-t/ )
    {
    $opt_net_protocols = shift;
    print "status: option: allowed network protocols [$opt_net_protocols]\n";
    next;
    }
  if( /-e/ )
    {
    $opt_preload  = 1;
    $opt_app_name = lc shift @ARGV;
    print "status: option: preload application, will serve single app\n";
    next;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "status: option: debug level raised, now is [$level] \n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }



if( $opt_preload )
  {
  if( $opt_app_name =~ /^[A-Z_0-9]+$/i )
    {
    print "info: application name in use [$opt_app_name]\n";
    }
  else
    {
    print "error: invalid application name [$opt_app_name]\n";
    exit 1;
    }  
  }  

#-----------------------------------------------------------------------------

my %srv_opt = (
              PORT    => $opt_listen_port,
              NO_FORK => $opt_no_fork,
              );

if( $opt_preload )
  {
  de_init( APP_NAME => $opt_app_name );
  preload_all_tables_descriptions();
  }
de_net_protocols_allow( $opt_net_protocols );

my $server_pkg  = "$DEFAULT_SERVER_MODULE_PREFIX$server_module";
my $server_file = perl_package_to_file( $server_pkg );

print "info: starting server [$server_pkg] main listen loop on port [$opt_listen_port]...\n";

eval
  {
  require $server_file;
  };
if( $@ )  
  {
  print "cannot load server module [$server_pkg] from file [$server_file] reason [$@]\n";
  exit(111);
  }

my $server = new $server_pkg %srv_opt;
$server->run();
