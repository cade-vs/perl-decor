package decor::actions::home;
use strict;

sub main
{
  my $reo = shift;

  my $in = $reo->is_logged_in() ? "IN" : "OUT";

  my $new_id = $reo->param( 'F:NEW_ID' );
  
  if( $new_id > 0 )
    {
    return "already done insert!";
    }
  else
    {  
    return $reo->forward_new( ACTION => 'edit', TABLE => 'test1', ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => 'NEW_ID' ) if $in;
    }

  return "NEW_ID IS [$new_id] -- [$$] THE NEW APP1 3 HELLO! ($$) world: " . rand() . " [$in]";
  return $reo->forward_new( ACTION => 'edit', TABLE => 'test1', ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => 'NEW_ID' );
}

1;
