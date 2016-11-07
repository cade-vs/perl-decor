package decor::actions::logout;
use strict;

use Data::Dumper;

sub main
{
  my $reo = shift;

  $reo->logout();
  return "<#logout_done>";
}

1;
