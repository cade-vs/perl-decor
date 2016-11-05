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
  
  my $res = $reo->de_login( $user, $pass );


  print STDERR Dumper( $reo );
  return "login res: [$res]";
  
  
}

1;
