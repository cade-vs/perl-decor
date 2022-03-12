##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::map_location;
use strict;
use Data::Dumper;
use Exception::Sink;

use Web::Reactor::HTML::Form;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Decor::Web::Maps;

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();
  
  my $text;

  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();
  my $rs = $reo->get_page_session( 1 );

  my $core = $reo->de_connect();

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  my $return_data_to  = $reo->param( 'RETURN_DATA_TO'   );
  my $marker_location = $ui->{ 'MARKER_LOCATION_XYZ' };
  my $ll              = $reo->param( 'LL' );

  if( $button eq 'SELECT' )
    {
    return $reo->forward_back( "F:$return_data_to" => $marker_location );
#    if( $marker_location =~ /([-+]?\d+(\.\d*)?\s*,\s*[-+]?\d+(\.\d*)?)/ )
#      {
#      my $ll = $1;
#      return $reo->forward_back( "F:$return_data_to" => $ll );
#      }
    }

  $text .= map_tomtom( $reo, LL => $ll, ALLOW_SELECT => ( $return_data_to ? 1 : 0 ), ALLOW_NAV => 1 );

  return $text;
}

1;
