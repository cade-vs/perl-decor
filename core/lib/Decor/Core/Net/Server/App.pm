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

use parent qw( Decor::Core::Net::Server );

sub on_process_xt_message
{
  my $mi = shift;
  my $mo = shift;
  
  boom "on_process_xt_message() must be reimplemented in current class";
  return undef;
}

#-----------------------------------------------------------------------------

### EOF ######################################################################
1;
