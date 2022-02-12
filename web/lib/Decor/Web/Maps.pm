##############################################################################
##
##  Decor application machinery core
##  2014-2022 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::Maps;
use strict;
use Data::Dumper;

use Decor::Web::HTML::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                map_tomtom

                );


sub map_tomtom
{
  my $reo  = shift;
  my %args = @_;

  my $ll               = $args{ 'LL' };
  my $allow_map_select = $args{ 'ALLOW_SELECT' } ? 1 : 0;
  my $allow_nav        = $args{ 'ALLOW_NAV' };

  my $text;

  my $map_cfg = $reo->de_load_cfg( 'map' );
  my $tomtom_key = $map_cfg->{ '@' }{ '@' }{ 'TOMTOM_KEY' }; # FIXME

  my ( $location_form, $location_form_begin, $location_form_id );

  if( $allow_nav )
    {
    $location_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
    $location_form_begin .= $location_form->begin( NAME => "form_location", DEFAULT_BUTTON => 'SELECT', CLASS => 'button act-button' );
    $location_form_id = $location_form->get_id();
    }

  my ( $lla, $llo, $llz );
  if( $ll =~ /([-+]?\d+(\.\d*)?)\s*,\s*([-+]?\d+(\.\d*)?)\s*(\@(\d+(\.\d*)?))?/ )
    {
    ( $lla, $llo, $llz ) = ( $1, $3, ( $6 || 17 ) );
    }
  else
    {
    ( $lla, $llo, $llz ) = ( 42.69774, 23.3218, 11 ); # TODO: FIXME: args ops
    }  


  my $back_button = de_html_alink_button( $reo, 'back', "&lArr; [~Back]", "[~Return to previous screen]", BTYPE => 'nav' );;

  $text .= <<END_OF_HTML;

<table width=100% class=map-layout>
<tr>

END_OF_HTML

if( $allow_nav )
{
$text .= <<END_OF_HTML;
    <td align=left>
      $location_form_begin
      $back_button
      <button form=$location_form_id name=BUTTON:SELECT class='button act-button'><img src=i/map_location.svg> Select location</button>
    </td>
    <td align=left>
      <input  form=$location_form_id id=marker_location_xyz name=marker_location_xyz>
      <input  form=$location_form_id type=submit value='Go to' class='button nav-button'>
    </td>
    <td>
      <form onsubmit='event.preventDefault(); geo_search();'>
      <input id=geo_search_input name=geo_search_input>
      <input type=submit value=Search class='button nav-button'>
      </form>
    </td>
END_OF_HTML
}

my $map_td_colspan = $allow_nav ? 4 : 1;

$text .= <<END_OF_HTML;
    <td align=right>
      zoom to 
      <a href='javascript:zoom_to_country_level();'>country</a>
      |
      <a href='javascript:zoom_to_city_level();'>city</a>
      |
      <a href='javascript:zoom_to_street_level();'>street</a>
      level
    </td>
</tr>
<tr>
    <td colspan=$map_td_colspan class=map-layout>
    <div id='map' class='map'></div>
    </td>
</tr>
</table>

<script src='jstt/maps-web.min.js'></script>
<script src='jstt/services-web.min.js'></script>
<script type='text/javascript' src='jstt/mobile-or-tablet.js'></script>

<script>

    var endpoint = 'https://{cyclingHostname}.api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?tileSize=512&key=$tomtom_key';
    var tiles = ['a', 'b', 'c', 'd'].map( function(hostname) { return endpoint.replace('{cyclingHostname}', hostname); } );

    var map = tt.map({
        key: '$tomtom_key',
        container: 'map',
        style: {
                'version': 8,
                'sources': {
                    'raster-tiles': {
                        'type': 'raster',
                        'tiles': tiles,
                        'tileSize': 256
                    }
                },
                'layers': [
                    {
                        'id': 'raster-tiles-layer',
                        'type': 'raster',
                        'source': 'raster-tiles'
                    }
                ]
            },
        dragPan: $allow_map_select || ! isMobileOrTablet()
    });

    map.dragRotate.disable();
    
    var scale = new tt.ScaleControl( {
                                      maxWidth: 512,
                                      unit: 'imperial'
                                      } );
    map.addControl( scale );
    scale.setUnit('metric');

    map.addControl( new tt.GeolocateControl( 
                       {
                          positionOptions: 
                             {
                             enableHighAccuracy: true
                             },
                          trackUserLocation: true
                       }
                 ));
    /* map.hidePOI(); */
                 
    var marker = new tt.Marker( { color: '#ff0000', draggable: true } );
    var pois_visible = 0;

    function num_dot_reduce( c, l )
    {
      return ( Math.round( c * l ) ) / l;
    }

    function coord_reduce( c )
    {
      return num_dot_reduce( c, 100000 );
    }

    function update_marker_position_and_zoom( ll )
    {
      var xyz = document.getElementById('marker_location_xyz');
      xyz.value = coord_reduce( ll.lat ) + "," + coord_reduce( ll.lng ) + '  \@' + num_dot_reduce( map.getZoom(), 10 );
    }

    function set_marker_to_lnglat( ll, force )
    {
      if( ! force && ! $allow_map_select ) return;
      update_marker_position_and_zoom( ll );
      marker.setLngLat( ll );
      marker.addTo( map );
    }
    
    function on_mouse_click( ev )
    {
      set_marker_to_lnglat( ev.lngLat );
    }

    function on_marker_dropped( ev )
    {
      set_marker_to_lnglat( ev.target.getLngLat() );
    }

    function on_zoomend( ev )
    {
      update_marker_position_and_zoom( marker.getLngLat() );
    }

    map.addControl( new tt.FullscreenControl() );
    map.addControl( new tt.NavigationControl() );
    map.setZoom( $llz );
    map.setCenter( { lon: $llo, lat: $lla } );
    map.on( 'click',   function (ev) { on_mouse_click( ev ) } );
    map.on( 'zoomend', function (ev) { on_zoomend( ev ) } );
    marker.on( 'dragend', function ( ev ) { on_marker_dropped( ev ) } );
    set_marker_to_lnglat( map.getCenter(), 1 );
    if( ! $allow_map_select )
      marker.setDraggable( false );
    show_hide_pois();

    function zoom_to_country_level()
    {
      map.setCenter( marker.getLngLat() );
      map.zoomTo( 6 );
    }

    function zoom_to_city_level()
    {
      map.setCenter( marker.getLngLat() );
      map.zoomTo( 12 );
    }

    function zoom_to_street_level()
    {
      map.setCenter( marker.getLngLat() );
      map.zoomTo( 16 );
    }

    function show_hide_pois()
    {
      if( pois_visible )
        map.hidePOI();
      else  
        map.showPOI();
      pois_visible = ! pois_visible;  
    }

    function geo_search_result( result ) 
    {
      console.log(result);
      if( result.results.length > 0 )
        {
        if( $allow_map_select )
          {
          set_marker_to_lnglat( result.results[0].position, 1 );
          map.setCenter( marker.getLngLat() );
          }
        else
          {
          map.setCenter( result.results[0].position );
          }  
        map.zoomTo( 16 );
        }
    };
      
    function geo_search()
    {
      tt.services.geocode({
                            key: '$tomtom_key',
                            query: document.getElementById( 'geo_search_input' ).value
                          }).then( geo_search_result );
      return false;                    
    }

</script>

  
END_OF_HTML

return $text;
}


1;
