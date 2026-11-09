##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::logout;
use strict;

use Data::Dumper;

sub main
{
  my $reo = shift;

  $reo->log( "status: logout remote [" . $reo->get_client_ip() . "]" ); # through the reactor log, as de_login()
  $reo->de_logout();
  
  return "<#logout_done>";
}

1;
