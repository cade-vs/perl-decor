##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Log;
use strict;
use open ':std', ':encoding(UTF-8)';

use POSIX;
use Fcntl qw( :flock );                                                                                                         
use Data::Dumper;
use Exception::Sink;
use Decor::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                $DE_LOG_TO_STDERR
                $DE_LOG_TO_FILES
                $DE_LOG_STDERR_COLORS

                de_set_log_prefix
                de_set_log_dir
                
                de_log
                de_log_debug
                de_log_debug2
                de_log_debug_stack
                de_log_debug_stack2
                
                de_log_dumper
                de_log_dumper2
                
                de_reopen_logs

                );

our $DE_LOG_TO_STDERR       = 0;
our $DE_LOG_TO_FILES        = 1;
our $DE_LOG_MAX_REPEAT_MSG  = 32;
our $DE_LOG_STDERR_COLORS   = 0;

my $MSG_TYPE_COLOR_RESET = chr(27) . '[0m';
my %MSG_TYPE_COLOR = (
                     error   => chr(27) . '[1;31m',
                     fatal   => chr(27) . '[1;31m',
                     status  => chr(27) . '[36m',
                     info    => chr(27) . '[32m',
                     warning => chr(27) . '[1;33m',
                     );


# TODO: push/pop of temporary secondary prefixes (hints), use wrapper class

my $DE_LOG_PREFIX = 'decor';
my $DE_LOG_DIR    = '';

sub de_set_log_prefix
{
  my $prefix = shift;
  
  $DE_LOG_PREFIX = $prefix;
}

sub de_set_log_dir
{
  my $dir = shift;

  boom "invalid or unreachable log directory [$dir]" unless -d $dir;

  $DE_LOG_DIR = $dir;
}

my $last_log_message;
my $last_log_message_count;
my %de_log_files;

sub de_log
{
  my @args = @_;

  chomp( @args );

  $DE_LOG_TO_STDERR = 1 if ! $DE_LOG_TO_STDERR and ! $DE_LOG_TO_FILES;
  
  for my $msg ( @args )
    {
#    if( $last_log_message eq $msg and $last_log_message_count < $DE_LOG_MAX_REPEAT_MSG )
#      {
#      $last_log_message_count++;
#      next;
#      }

    my $msg_in_type = 'unknown';
    $msg_in_type = lc $1 if $msg =~ /^([a-z_]+):/;
    next if $msg_in_type eq 'debug' and ! de_debug();

    my @msg_types = ( $msg_in_type );
    push @msg_types, 'global' if $DE_LOG_TO_FILES and de_init_done();

    my $tm = strftime( "%Y%m%d-%H%M%S", localtime() );
    my $lp = "$tm ${DE_LOG_PREFIX}[$$]"; # log msg prefix

    my @msg;
    
    push @msg, "$lp this message was repeated $last_log_message_count times:\n"
        if $last_log_message_count;
    $last_log_message = $msg;
    $last_log_message_count = 0;
    push @msg, "$lp $msg\n";

    # write in order to prevent deadlock caused by flock
    for my $msg_type ( sort @msg_types )
      {
      if( $DE_LOG_TO_FILES )
        {
        my $fh = $de_log_files{ $msg_type };
        if( de_init_done() and $DE_LOG_TO_FILES and -d $DE_LOG_DIR and ! $fh )
          {
          open( $fh, '>>', "$DE_LOG_DIR/$msg_type.log" );
          $de_log_files{ $msg_type } = $fh;
          }
        __log_to_file( $fh, @msg ) if $fh;
        }  
      # msg_type
      }

    if( $DE_LOG_TO_STDERR )  
      {
      if( $DE_LOG_STDERR_COLORS )
        {
        unshift @msg, $MSG_TYPE_COLOR{ $msg_in_type } if exists $MSG_TYPE_COLOR{ $msg_in_type };
        push    @msg, $MSG_TYPE_COLOR_RESET;
        }
      __log_to_file( \*STDERR, @msg ); # only "global" to stderr
      }

    # msg
    }

  return undef;
}

sub __log_to_file
{
  my $fh  = shift;
  flock( $fh, LOCK_EX );
  print $fh @_;
  flock( $fh, LOCK_UN );
}

sub de_log_debug
{
  return unless de_debug();

  my @args = @_;
  chomp( @args );
  my $msg = join( "\n", @args );
  $msg = "debug: $msg" unless $msg =~ /^[a-z]+:/i;
  de_log( $msg );
}

sub de_log_debug2
{
  return unless de_debug() > 1;
  de_log_debug( @_ );
}

sub de_log_debug_stack
{
  de_log_debug( @_, "\n", Exception::Sink::get_stack_trace() );
}

sub de_log_debug_stack2
{
  de_log_debug2( @_, "\n", Exception::Sink::get_stack_trace() );
}

sub de_log_dumper
{
  return unless de_debug();
  de_log_debug( Dumper( @_ ) );
}

sub de_log_dumper2
{
  return unless de_debug() > 1;
  de_log_debug( Dumper( @_ ) );
}

sub de_reopen_logs
{
  %de_log_files = ();
  1;
}
                
### EOF ######################################################################
1;
