##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  This is custom server module to process generic messages while  
##  Decor app environment is preloaded. 
##  Check DECOR_ROOT/core/bin/decor-core-app-server.pl
##
##  To run this server module:
##
##  ./decor-core-app-server.pl -e app1 -u echo
##
##  For more information, check docs/custom-server-modules.txt
##
##############################################################################
package Decor::Core::Net::Server::Echo;
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

  # DO WORK HERE!
  %$mo = %$mi;
  $mo->{ 'XS' } = 'OK'; # mesage status must be specified, OK or EXXX

  de_log_dumper( "ECHO PROCESS " x 16, "$mi, $mo", $mi, $mo );

  return 1;
}

#-----------------------------------------------------------------------------

### EOF ######################################################################
1;
