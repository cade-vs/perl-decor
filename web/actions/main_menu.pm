package decor::actions::main_menu;
use strict;

sub main
{
  my $reo = shift;
  
  return "<#menu_outside>" unless $reo->is_logged_in();

  
  
  return "MAIN MENU" . rand();
}

1;
