##############################################################################
##
##  App::Recon application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recon::Core::Log;
use strict;

use Data::Dumper;
use App::Recoil::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                rc_set_log_prefix
                rc_log
                rc_log_debug
                rc_log_stack
                rc_log_dumper
                
                rc_reopen_logs

                );


# fixme: log files

my $RECON_LOG_PREFIX = 'recon';

sub rc_set_log_prefix
{
  my $prefix = shift;
  
  $RECON_LOG_PREFIX = $prefix;
}

sub rc_log
{
  my @args = @_;
  
  chomp( @args );
  
  print STDERR "$RECON_LOG_PREFIX [$$]: $_\n" for @args;
}

sub rc_log_debug
{
  return unless $RECON_DEBUG;

  my @args = @_;
  chomp( @args );
  my $msg = join( "\n", @args );
  $msg = "debug: $msg" unless $msg =~ /^debug:/i;
  rc_log( $msg );
}

sub rc_log_stack
{
  rc_log_debug( @_, "\n", Exception::Sink::get_stack_trace() );
}

sub rc_log_dumper
{
  return unless $RECON_DEBUG;
  rc_log_debug( Dumper( @_ ) );
}

sub rc_reopen_logs
{
  1; # fixme: nothing yet
}
                
### EOF ######################################################################
1;
