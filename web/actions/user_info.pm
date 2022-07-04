##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::user_info;
use strict;

sub main
{
  my $reo = shift;

  return "n/a" unless $reo->is_logged_in();

  my $us = $reo->get_user_session();
  my $un = $us->{ 'USER_NAME' };

  return "<span class=hi>$un</span>";
}

1;
