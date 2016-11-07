package decor::actions::login;
use strict;

use Data::Dumper;

sub main
{
  my $reo = shift;

  my $ui = $reo->get_user_input();

  my $button    = $reo->get_input_button_and_remove();
  my $button_id = $reo->get_input_button_id();

  my $user;
  my $pass;

  return "<#login_form>" unless $button eq 'LOGIN';

  my $user = $ui->{ 'USER' };
  my $pass = $ui->{ 'PASS' };
  
  my ( $client, $status ) = $reo->de_login( $user, $pass );

#  print STDERR Dumper( $reo );
#  return "login res: client [$client] status [$status] ";

  if( $client )
    {
    $reo->login();                                                                                                              
    $reo->forward_new( ACTION => 'home' );
    }
  else
    {
    $reo->html_content_set( 'login-error' => "<#$status>" );
    return "<#login_form>";
    }  
  
}

1;
