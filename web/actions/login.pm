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
  my $button_id = $reo->get_input_button_id();

  my $user;
  my $pass;

  if( $auto_user and $auto_pass )
    {
    $user = $auto_user;
    $pass = $auto_pass;
    }
  else
    {  
    return "<#login_form>" unless $button eq 'LOGIN';

    $user = $ui->{ 'USER'     };
    $pass = $ui->{ 'PASSWORD' };
    }
  
  my $client = $reo->de_connect();

  if( $reo->de_login( $user, $pass ) )
    {
    $reo->login( $user );
    $reo->forward_new( ACTION => 'home' );
    }
  else
    {
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
