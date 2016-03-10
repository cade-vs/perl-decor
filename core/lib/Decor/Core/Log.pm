##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Log;
use strict;

use Data::Dumper;

use Decor::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_set_log_prefix
                de_log
                de_log_debug
                de_log_stack
                de_log_dumper
                
                de_reopen_logs

                );


# fixme: log files

my $DECOR_LOG_PREFIX = 'decor';

sub de_set_log_prefix
{
  my $prefix = shift;
  
  $DECOR_LOG_PREFIX = $prefix;
}

sub de_log
{
  my @args = @_;
  
  chomp( @args );
  
  print STDERR "$DECOR_LOG_PREFIX [$$]: $_\n" for @args;
}

sub de_log_debug
{
  return unless de_debug();

  my @args = @_;
  chomp( @args );
  my $msg = join( "\n", @args );
  $msg = "debug: $msg" unless $msg =~ /^debug:/i;
  de_log( $msg );
}

sub de_log_stack
{
  de_log_debug( @_, "\n", Exception::Sink::get_stack_trace() );
}

sub de_log_dumper
{
  return unless de_debug();
  de_log_debug( Dumper( @_ ) );
}

sub de_reopen_logs
{
  1; # fixme: nothing yet
}
                
### EOF ######################################################################
1;
