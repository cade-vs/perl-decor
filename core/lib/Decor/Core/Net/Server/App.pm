##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Net::Server::App;
use strict;
use Exception::Sink;
use Decor::Core::Subs;
use Decor::Core::Log;

use parent qw( Decor::Core::Net::Server );

sub on_process_xt_message
{
  my $self = shift;
  my $mi   = shift;
  my $mo   = shift;
  my $socket = shift;

  subs_process_xt_message( $mi, $mo, $socket );

#  de_log_dumper( "SUBS PROCESS " x 16, "$mi, $mo", $mi, $mo );

  return 1;
}

sub on_process_begin_reset
{
  my $self = shift;
  my $socket = shift;

  Decor::Core::Subs::__sub_reset_state();
  return 1;
}

#-----------------------------------------------------------------------------

### EOF ######################################################################
1;
