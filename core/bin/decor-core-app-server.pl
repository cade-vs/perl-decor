#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use open ':std', ':encoding(UTF-8)';

use Data::Tools;
use Data::Tools::Process;
use Data::Tools::Socket::Protocols;

use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::DSN;
use Decor::Core::Describe;
use Decor::Core::Net::Server::App;
use Decor::Shared::Utils;

INIT { $| = 1; }

my $DEFAULT_SERVER_MODULE_PREFIX = "Decor::Core::Net::Server::";
my $DEFAULT_SERVER_MODULE        = "App";

my $opt_app_name;
my $opt_no_fork = 0;
my $opt_prefork = 0;
my $opt_maxfork = 0;
my $opt_preload = 0;
my $opt_listen_port = 42000;
my $opt_net_protocols = '*';
my $server_module = $DEFAULT_SERVER_MODULE;
my $opt_ssl;
my %opt_ssl;

my $opt_daemonize;

eval { require IO::Socket::SSL; };
my $no_ssl = $@ if $@;

our $help_text = <<END;
usage: $0 <options>
options:
    -p port    -- port number for incoming connections (default $opt_listen_port)
    -f         -- run in foreground (no fork) mode
    -k cnt     -- run in prefork mode, start initial 'cnt' processes.
    -x cnt     -- fork maximum 'cnt' processes (also for prefork mode)
    -e app     -- preload application (will serve only single app)
    -t psj     -- allow network protocol formats (p=storable,s=stacker,j=json)
    -d         -- increase DEBUG level (can be used multiple times)
    -r         -- log to STDERR
    -rr        -- log to both files and STDERR
    -rc        -- use ANSI-colored STDERR log messages (same as -rrc)
    -g         -- use single log file (no detail split)
    -u srvmod  -- server module (default: App) AVOID IF UNSURE! USE -e FIRST!
    -sc cert   -- file with SSL/X509 certificate
    -sk key    -- file with SSl/X509 certificate key
    -su bundle -- file with trusted SSL/X509 certificate issuers
                  if -su given, all clients' certificates will be verified!
    -z         -- daemonize process (detach from controlling terminal)
    --         -- end of options
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
  if( /-k/ )
    {
    $opt_prefork = shift;
    print "status: option: run in prefork mode, spawning initial $opt_prefork processes\n";
    next;
    }
  if( /-x/ )
    {
    $opt_maxfork = shift;
    print "status: option: max fork $opt_prefork processes\n";
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
    # $server_module = uc( substr( $server_module, 0, 1 ) ) . lc( substr( $server_module, 1 ) );
    die "invalid server module name [$server_module] check -u parameter!\n" unless de_check_pkg_name( $server_module );
    print "status: option: using server module [$DEFAULT_SERVER_MODULE_PREFIX$server_module]\n";
    next;
    }
  if( /-r(r)?(c)?/ )
    {
    # FIXME: cleanup logic
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    $DE_LOG_STDERR_COLORS = $2 ? 1 : 0;
    print "status: option: forwarding logs to STDERR\n";
    next;
    }
  if( /-g/ )
    {
    # FIXME: cleanup logic
    $DE_LOG_TO_FILES  = 2;
    }
  if( /-t/ )
    {
    $opt_net_protocols = shift;
    print "status: option: allowed network protocols [$opt_net_protocols]\n";
    next;
    }
  if( /-sc/ )
    {
    die "error: SSL not available: $no_ssl" if $no_ssl;
    $opt_ssl{ 'SSL_cert_file' } = shift;
    die "error: cannot read SSL server certificate file [$opt_ssl{ 'SSL_cert_file' }]" unless -r $opt_ssl{ 'SSL_cert_file' };
    print "status: option: SSL server certificate file [$opt_ssl{ 'SSL_cert_file' }]\n";
    $opt_ssl{ 'SSL' } = 1;
    next;
    }
  if( /-sk/ )
    {
    die "error: SSL not available: $no_ssl" if $no_ssl;
    $opt_ssl{ 'SSL_key_file' } = shift;
    die "error: cannot read SSL server certificate key [$opt_ssl{ 'SSL_key_file' }]" unless -r $opt_ssl{ 'SSL_key_file' };
    print "status: option: SSL server certificate key [$opt_ssl{ 'SSL_key_file' }]\n";
    $opt_ssl{ 'SSL' } = 1;
    next;
    }
  if( /-su/ )
    {
    die "error: SSL not available: $no_ssl" if $no_ssl;
    $opt_ssl{ 'SSL_ca_file' } = shift;
    die "error: cannot read SSL server trusted certificates [$opt_ssl{ 'SSL_ca_file' }]" unless -r $opt_ssl{ 'SSL_ca_file' };
    print "status: option: SSL server trusted certificates [$opt_ssl{ 'SSL_ca_file' }]\n";
    $opt_ssl{ 'SSL_verify_mode' } = IO::Socket::SSL::SSL_VERIFY_PEER();
    $opt_ssl{ 'SSL' } = 1;
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
  if( /^-z/ )
    {
    $opt_daemonize++;
    print "status: option: going daemon... :>\n";
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
              PREFORK => $opt_prefork,
              MAXFORK => $opt_maxfork,
              SSL     => $opt_ssl,
              
              %opt_ssl

              );

if( $opt_preload )
  {
  de_init( APP_NAME => $opt_app_name );
  preload_all_tables_descriptions();
  }
socket_protocols_allow( $opt_net_protocols );

my $server_pkg  = "$DEFAULT_SERVER_MODULE_PREFIX$server_module";
my $server_file = perl_package_to_file( $server_pkg );

de_set_log_prefix( perl_package_to_file( $server_module ) );

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

daemonize() if $opt_daemonize;
de_reopen_logs();

my $pid_root = de_root() . "/var/core/$opt_app_name\_$</pid/app_server/$server_pkg.port$opt_listen_port";
pidfile_create( $pid_root );

$srv_opt{ 'PID_ROOT' } = $pid_root;

print "status: server started with pid [$$]\n";
my $server = new $server_pkg %srv_opt;
$server->run();

pidfile_remove( $pid_root );
rmdir( "$pid_root.d" );
