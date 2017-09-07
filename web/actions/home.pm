package decor::actions::home;
use strict;

sub main
{
  my $reo = shift;
  
  my $in = $reo->is_logged_in() ? "IN" : "OUT";

  return "[$$] hellou! " . rand() . " [$in]";
}

1;
