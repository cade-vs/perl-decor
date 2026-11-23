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
use Web::Reactor::HTML; # html_text() # cc20261110-5

sub main
{
  my $reo = shift;

  return "n/a" unless $reo->is_logged_in();

  my $us = $reo->get_user_session();
  my $un  = $us->{ 'USER_NAME' };
  my $urn = $us->{ 'USER_REALNAME' };

#-  return "<span class=main-menu>$urn [$un]</span>"; # cc20261110-5
  return "<span class=main-menu>" . html_text( $urn ) . " [" . html_text( $un ) . "]</span>"; # user data # cc20261110-5
}

1;
