#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::Net::Server::App;
use Decor::Shared::Net::Protocols;


my $opt_app_name;
my $opt_no_fork = 0;
my $opt_preload = 0;
my $opt_listen_port = 4243;
my $opt_net_protocols = '*';

our $help_text = <<END;
usage: $0 <options>
options:
    -p port   -- port number for incoming connections (default 9100)
    -f        -- run in foreground (no fork) mode
    -e app    -- preload application (will serve only single app)
    -t psj    -- allow network protocol formats (p=storable,s=stacker,j=json)
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
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
    print "option: run in foreground (no fork) mode\n";
    next;
    }
  if( /-p/ )
    {
    $opt_listen_port = shift;
    print "option: listening on port [$opt_listen_port]\n";
    next;
    }
  if( /-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /-t/ )
    {
    $opt_net_protocols = shift;
    print "option: allowed network protocols [$opt_net_protocols]\n";
    next;
    }
  if( /-e/ )
    {
    $opt_preload  = 1;
    $opt_app_name = lc shift @args;
    print "option: preload application, will serve single app\n";
    next;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
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

my $server = new Decor::Core::Net::Server::App( %srv_opt );

if( $opt_preload )
  {
  de_init( APP_NAME => $opt_app_name );
  preload_all_tables_descriptions();
  }
de_net_protocols_allow( $opt_net_protocols );

print "starting server main listen loop...\n";
$server->run();
