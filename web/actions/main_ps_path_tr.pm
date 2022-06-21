package decor::actions::main_ps_path_tr;
use strict;

sub main
{
  my $reo = shift;
  
  return $reo->is_logged_in() ? "<#main_ps_path_tr>" : undef;
}

1;
