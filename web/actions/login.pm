##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::login;
use strict;

use Data::Dumper;

sub main
{
  my $reo = shift;

  my $auto_user = $reo->cfg()->{ 'DECOR_AUTO_USER' }; # config keys, the old reactor kept the config under {ENV}
  my $auto_pass = $reo->cfg()->{ 'DECOR_AUTO_PASS' };

  my $ui = $reo->get_user_input();

  my $button    = $reo->get_input_button_and_remove();

  my $user;
  my $pass;

  # a submitted form always wins, auto login only without one, a failed auto login leaves the form usable
  if( $button eq 'LOGIN' )
    {
    $user = $ui->{ 'USER'     };
    $pass = $ui->{ 'PASSWORD' };
    }
  elsif( $auto_user and $auto_pass )
    {
    $user = $auto_user;
    $pass = $auto_pass;
    }
  else
    {
    return "<#login_form>";
    }
  
  if( $reo->de_login( $user, $pass ) )
    {
    $reo->login( $user );
    return $reo->forward_new( ACTION => 'home' ); # explicit, as the other actions
    }
  else
    {
    my $client = $reo->de_connect(); # the connection de_login() made, de_connect() reuses it
    my $status = $client->status();
    if( $status =~ /^E_SESSION/ )
      {
      $reo->logout();
      }
    $reo->html_hold_set( 'login-error' => "<#$status>" );

    return "<#login_form>";
    }  
  
}

1;
