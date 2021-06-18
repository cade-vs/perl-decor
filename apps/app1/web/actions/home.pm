package decor::actions::home;
use strict;

sub main
{
  my $reo = shift;

print STDERR "--------------------------------------PRECONNECT\n";

  my $core = $reo->de_connect();

  my $in = $reo->is_logged_in() ? "IN" : "OUT";

  # new id will have non-zero value only if the forwarded insert was successful
  my $new_id = $reo->param( 'F:NEW_ID' );
  
  # args for the new insert
  my @insert_args = ( ACTION => 'edit', TABLE => 'test1', ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => 'NEW_ID' );
  if( $new_id > 0 )
    {
    # insert was ok, new id was returned
    my $href = $reo->args_new( @insert_args );
    return "already done insert! <a href=?_=$href>insert new record here</a>";
    }
  else
    {  
    # first run, no previous insert, forward to new one
    return $reo->forward_new( @insert_args ) if $in;
    }

  return "NEW_ID IS [$new_id] -- [$$] THE NEW APP1 3 HELLO! ($$) world: " . rand() . " [$in]";
}

1;
