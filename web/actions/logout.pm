package decor::actions::logout;
use strict;

use Data::Dumper;

sub main
{
  my $reo = shift;

  $reo->de_logout();
  
  print STDERR "info: >>>>>>>>>>>>>>>>>>>>>> LOGOUT\n";
  
  return "<#logout_done>";
}

1;
