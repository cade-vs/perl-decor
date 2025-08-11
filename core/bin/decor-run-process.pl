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

use Time::HR;

use Storable qw( dclone );
use Data::Lock qw( dlock dunlock );
use Data::Tools 1.09;
use Data::Tools::Process;
use Exception::Sink;

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::DSN;
use Decor::Core::Profile;
use Decor::Core::Log;
use Decor::Core::Code;
use Decor::Shared::Config;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $opt_app_name;
my $opt_verbose;
my $opt_daemonize;

our $help_text = <<END;
usage: $0 <options> application_name table fields
options:
    -v        -- verbose output
    -d        -- debug mode, can be used multiple times to rise debug level
    -z        -- daemonize process (fork in background)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -rd is invalid, correct is: -r -d
END

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
    next;
    }
  if( /^-z/ )
    {
    $opt_daemonize++;
    print "option: daemonize\n";
    next;
    }
  if( /^-v/ )
    {
    $opt_verbose = 1;
    next;
    }
  if( /-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

if( @args < 2 )
  {
  print $help_text;
  exit;
  }

my $opt_app_name = shift @args;

my $request_exit;

$SIG{ 'INT'  } = sub { $request_exit = 1 };
$SIG{ 'TERM' } = sub { $request_exit = 2 };
$SIG{ 'HUP'  } = \&usr_signal_sub;

de_init( APP_NAME => $opt_app_name );

my $pkg = shift @args;
my $trigger = 'main';

( $pkg, $trigger ) = ( $1, $3 ) if $pkg =~ /^([a-z_0-9\-]+)(:([a-z_0-9\-]+))$/;

die "$0: missing or unknown process package:trigger [$pkg:$trigger]\n" unless de_code_exists( 'PROCESSES', $pkg, $trigger );

my $pid_root = de_root() . "/var/core/$opt_app_name\_$</pid/process/$pkg/$trigger";

daemonize() if $opt_daemonize;

pidfile_create( $pid_root );
de_reopen_logs();

de_log( "status: process package:trigger [$pkg:$trigger] is running with pid [$$]" . ( $opt_daemonize ? " daemonized" : undef ) );

my $pres;
while( ! is_exit_requested() )
  {
  eval
    {
    $pres = de_code_exec( 'PROCESSES', $pkg, "ON_$trigger", @args );
    last if ! $pres or is_exit_requested();
    };

  if( surface( 'REQUEST_EXIT' ) )
    {
    de_log( "status: exit requested..." );
    last;
    }
  elsif( surface( '*' ) )
    {
    de_log( "error: exception: $@" );

    # something happened, disconnect databases, wait a bit and try again
    # if this persist, emergency exit may be considered
    # it should be measured by failures in time frame
    dsn_reset();
    sleep(  5 ); # TODO: config
    }
  else
    {
    # all is fine, sleep...
    sleep( 11 ); # TODO: config
    }
  }

pidfile_remove( $pid_root );

de_log( "status: process $pkg:$trigger finidhes with result [$pres]" );
de_done();

##############################################################################

sub is_exit_requested
{
  return $request_exit;
}

sub request_exit
{
  return ++$request_exit;
}

sub signal_handler_hup
{
  my $sig = shift;

  de_reopen_logs();

  rcd_log( "status: SIGHUP received, reopen logs..." );

  # jtbs
  $SIG{ 'HUP'  } = \&signal_handler_hup;
}

##############################################################################
