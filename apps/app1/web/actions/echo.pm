package decor::actions::echo;
use strict;

use Data::Dumper;


sub main
{
  my $reo = shift;

  my $in = $reo->is_logged_in() ? "IN" : "OUT";

  # get known parameters
  my $table   = $reo->param( 'TABLE'   );
  my $id      = $reo->param( 'ID'      );
  my $copy_id = $reo->param( 'COPY_ID' );

  # list all parameters
  my $ui = $reo->get_user_input();

  my $text;
  
  $text .= "<xmp>" . Dumper( $ui ) . "</xmp>";

  return $text;
}

1;
