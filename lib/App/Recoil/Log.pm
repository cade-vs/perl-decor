##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil::Log;
use strict;

use App::Recoil::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_set_log_prefix
                red_log
                red_log_debug
                red_log_stack
                red_log_dumper
                
                red_reopen_logs

                );


# fixme: log files

my $RED_LOG_PREFIX = 'recoil';

sub red_set_log_prefix
{
  my $prefix = shift;
  
  $RED_LOG_PREFIX = $prefix;
}

sub red_log
{
  my @args = @_;
  
  chomp( @args );
  
  print STDERR "$RED_LOG_PREFIX [$$]: $_\n" for @args;
}

sub red_log_debug
{
  return unless $RED_DEBUG;

  my @args = @_;
  chomp( @args );
  my $msg = join( "\n", @args );
  $msg = "debug: $msg" unless $msg =~ /^debug:/i;
  red_log( $msg );
}

sub red_log_stack
{
  red_log_debug( @_, "\n", Exception::Sink::get_stack_trace() );
}

sub red_log_dumper
{
  return unless $RED_DEBUG;
  red_log_debug( Dumper( @_ ) );
}

sub red_reopen_logs
{
  1; # fixme: nothing yet
}
                
### EOF ######################################################################
1;
