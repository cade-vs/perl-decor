#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core: send mail queue
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Decor::Core::Env;
use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Core::Shop;
use Decor::Shared::Utils;
use Data::Tools;
use Data::Tools::Process;
use Data::Dumper;
use Exception::Sink;

$|++;

my $smail_queue_table = 'smail';
my $opt_all_yes;
my $opt_verbose;
my $opt_daemonize;

our $help_text = <<END;
usage: $0 <options> application_name args
options:
    -t table  -- smail table to process ("smail" by default)
    -v        -- verbose output
    -d        -- increase DEBUG level (can be used multiple times)
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    -z        -- daemonize process (fork in background)
    -y        -- assume "yes" answer to all questions :)
    --        -- end of options

notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -rd is invalid, correct is: -r -d
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
  if( /-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level]\n";
    next;
    }
  if( /^-y/ )
    {
    $opt_all_yes = 1;
    print "option: assuming 'yes' to all questions\n";
    next;
    }
  if( /^-t/ )
    {
    $smail_queue_table = shift;
    print "option: smail queue table: $smail_queue_table\n";
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
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_app_name = lc shift @args;

if( $opt_app_name =~ /^[A-Z_0-9]+$/i )
  {
  print "info: application name in use [$opt_app_name]\n";
  }
else
  {
  print "error: invalid application name [$opt_app_name]\n";
  exit 1;
  }  

de_set_log_prefix( 'decor-smail-queue' );

#-----------------------------------------------------------------------------

setup_signals();

de_init( APP_NAME => $opt_app_name );

my $pid_root = de_root() . "/var/core/$opt_app_name\_$</pid/process/smail/$smail_queue_table";

pidfile_create( $pid_root );
de_reopen_logs();

de_log( "status: smail queue [$smail_queue_table] is running with pid [$$]" . ( $opt_daemonize ? " daemonized" : undef ) );

my $pres; # items processed (work done) it is either zero or positive non-zero count, could be negative non-zero
while( ! is_exit_requested() )
  {
  eval
    {
    $pres = process_smail_queue( $smail_queue_table, @args );
    sleep(1), next if $pres; # if non-zero, the more data is expected, so wait less
    last if is_exit_requested();
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

de_log( "status: smail queue [$smail_queue_table] finished with result [$pres]" );

#-----------------------------------------------------------------------------

my $request_exit;

sub setup_signals
{
  $SIG{ 'INT'  } = sub { $request_exit = 1 };
  $SIG{ 'TERM' } = sub { $request_exit = 2 };
  $SIG{ 'HUP'  } = sub { de_reopen_logs(); }
}

sub is_exit_requested
{
  return $request_exit;
}

sub request_exit
{
  return ++$request_exit;
}

#-----------------------------------------------------------------------------

sub process_smail_queue
{
  my $smail_que_table = shift;
  my @args = @_;

  my $rec = record_new();

  my $rc;
  # select first 64 in the queue (to limit transaction scope), waiting to be send
  $rec->select( $smail_que_table, 'STATUS = ? AND PTIME <= ?', { BIND => [ 0, time() ], LIMIT => 64, ORDERBY => '_ID' } ) or return undef;
  while( $rec->next() )
    {
    send_single_mail( $rec );
    $rc++;
    }
  $rec->finish();
  
  $rec->commit();
  return $rc;
}

sub send_single_mail
{
  my $rec = shift;

  my $id = $rec->id();

  # FIXME FIXME FIXME FIXME FIXME FIXME FIXME: move to library, clean the code!
  # FIXME FIXME FIXME FIXME FIXME FIXME FIXME: move to library, clean the code!
  # FIXME FIXME FIXME FIXME FIXME FIXME FIXME: move to library, clean the code!

use Decor::Shared::Config;

  # FIXME: common simple config load for arbitrary config files
  my $app_dir = de_app_dir();
  my $smcfg   = de_config_load_file( "$app_dir/etc/smail.conf" );
     $smcfg   = $smcfg->{ '@' }{ '@' } if $smcfg;

  # TODO: timeout
  # TODO: HELO
  my $host = $smcfg->{ 'SMTP' } || $smcfg->{ 'HOST' };
  my $port = $smcfg->{ 'PORT' } || 587;
  my $from = $smcfg->{ 'FROM' };
  my $user = $smcfg->{ 'USER' };
  my $pass = $smcfg->{ 'PASS' };
  my $sdbg = $smcfg->{ 'DEBUG' };
  my $to   = r $rec 'RCPT';
  my $cc   = r $rec 'CC'; 
  my $bcc  = r $rec 'BCC'; 
  my $subj = r $rec 'SUBJ'; 
  my $body = r $rec 'BODY'; 

  use Email::Simple;
  use Net::SMTP;

  eval
    {
    # Connect to Outlook SMTP server
    my $smtp = Net::SMTP->new(
        $host,
        Port    => $port,
        Hello   => 'rdx-notify-server',
        Timeout => 30,
        Debug   => !! $sdbg,
    ) or die "SMTP error: cannot create object\n";

    # Start TLS encryption
    $smtp->starttls() or die "TLS error: $!\n";

    # Authenticate
    $smtp->auth( $user, $pass ) or die "AUTH error: $!\n";

    # Send email
    $smtp->mail( $from );
    $smtp->to( $to );
    $smtp->cc( $cc );
    $smtp->bcc( $bcc );

    my $email = Email::Simple->create(
        header => [
                    From    => $from,
                    To      => $to,
                    CC      => $cc,
                    BCC     => $bcc,
                    Subject => 'Testing RDX Notify',
                    Message => "[RDX] $subj"
                  ],
        
        body   => $body . "\n\n---\nTIMESTAMP: " . scalar localtime,
    );

    $smtp->data();
    $smtp->datasend( $email->as_string() );
    $smtp->dataend();

    $smtp->ok() or die "SEND error\n";

    $smtp->quit;
    };
  if( $@ )
    {
    de_log( "error: smail id [$id] exception [$@]" );
    $rec->w( STATUS => 0, STATUS_DES => $@, MTIME => time(), PTIME => time() + 60, PCOUNT => $rec->r( 'PCOUNT' ) + 1 );
    }
  else
    {
    de_log( "error: smail id [$id] sent OK" );
    $rec->w( STATUS => 1, STATUS_DES => 'OK', MTIME => time() );
    }  
  $rec->save();
  $rec->commit();
  return 1;
}
