##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Net::Server::App;
use strict;
use Exception::Sink;
use Decor::Core::Log;

use parent qw( Decor::Core::Net::Server );

sub on_process_xt_message
{
  my $self = shift;
  my $mi   = shift;
  my $mo   = shift;

  $mo->{ 'ECHO' } = $mi;
  $mo->{ 'XS'   } = 'OK';

    de_log_dumper( "PROCESS " x 16, "$mi, $mo", $mi, $mo );

  return 1;
}

#-----------------------------------------------------------------------------

### EOF ######################################################################
1;
