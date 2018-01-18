package decor::actions::reader;
use strict;

use JSON;
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
  
  my $data = $ui->{ 'POSTDATA' };
  
  my $hr = JSON::decode_json( $data );

  
  my $core = new Decor::Shared::Net::Client;
  $core->connect( "localhost:42111", "app1", { 'MANUAL' => 1 } );

  my $res = $core->tx_msg( $hr );
  
  $text .= Dumper( $hr, $res );
  
  return $text;
}

1;
