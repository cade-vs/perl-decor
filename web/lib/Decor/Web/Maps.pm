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
                map_parse_xyz

                );

sub map_parse_xyz
{
  my $ll = shift;
  return () unless $ll =~ /([-+]?\d+(\.\d*)?)\s*,\s*([-+]?\d+(\.\d*)?)\s*(\@(\d+(\.\d*)?))?/;
  return ( $1, $3, ( $6 || 17 ) );
}

sub map_tomtom
{
  my $reo  = shift;
  my %args = @_;

  my $ll               = $args{ 'LL' };
  my $allow_map_select = $args{ 'ALLOW_SELECT' } ? 1 : 0;
  my $allow_nav        = $args{ 'ALLOW_NAV'  };
  my $nav_wide         = $args{ 'NAV_WIDE'   };
  my $markers_ar       = $args{ 'MARKERS'    };

  my $text;

  my $map_cfg = $reo->de_load_cfg( 'map' );
  my $tomtom_key = $map_cfg->{ '@' }{ '@' }{ 'TOMTOM_KEY' }; # FIXME

  my ( $location_form, $location_form_begin, $location_form_id );

  if( $allow_nav )
    {
    $location_form        = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
    $location_form_begin .= $location_form->begin( NAME => "form_location", DEFAULT_BUTTON => 'SELECT', CLASS => 'button act-button' );
    $location_form_id     = $location_form->get_id();
    }

  my ( $lla, $llo, $llz ) = map_parse_xyz( $ll );
  ( $lla, $llo, $llz ) = ( 42.69774, 23.3218, 11 ) unless $lla; # TODO: FIXME: args ops

  my $back_button = de_html_alink_button( $reo, 'back', "&lArr; [~Back]", "[~Return to previous screen]", BTYPE => 'nav' );;


  my $add_markers;
  my $add_markers_count = 0;

  my ( $bla1, $blo1, $bla2, $blo2 ) = ( $lla, $llo, $lla, $llo );
  if( $markers_ar )
    {
    # print STDERR Dumper( $markers_ar );
    for my $lhr ( @$markers_ar )
      {
      my $loc_ll    = $lhr->{ 'LL'   };
      my $loc_text  = $lhr->{ 'TEXT' };
      
      my ( $loc_lla, $loc_llo, $loc_llz ) = ( $1, $3, ( $6 || 17 ) ) if $loc_ll =~ /([-+]?\d+(\.\d*)?)\s*,\s*([-+]?\d+(\.\d*)?)\s*(\@(\d+(\.\d*)?))?/;
      next unless $loc_lla and $loc_llo;
      
      $add_markers_count++;
      
      $bla1 = $loc_lla if $loc_lla < $bla1;
      $blo1 = $loc_llo if $loc_llo < $blo1;
      $bla2 = $loc_lla if $loc_lla > $bla2;
      $blo2 = $loc_llo if $loc_llo > $blo2;

      $add_markers .= qq(
                        var pp = new tt.Popup( { className: 'my-class' } );
                            pp.setHTML( "$loc_text" );
                        var mm = new tt.Marker( { color: '#ff0000', draggable: false } );
                            mm.setLngLat( { lng: $loc_llo, lat: $loc_lla } );
                            mm.setPopup( pp );
                            mm.addTo( map );
                           
                        );
      }
    }

  my $lloc = ( $blo1 + $blo2 ) / 2;
  my $llac = ( $bla1 + $bla2 ) / 2;
  
  $text .= <<END_OF_HTML;

<table width=100% class=map-layout>

END_OF_HTML

my $text_zoom_ctrl .= <<END_OF_HTML;
      zoom to 
      <a href='javascript:zoom_to_country_level();'>country</a>
      |
      <a href='javascript:zoom_to_city_level();'>city</a>
      |
      <a href='javascript:zoom_to_street_level();'>street</a>
      level
      |
      <a href='javascript:marker_recenter();'>&raquo;&laquo;</a>
END_OF_HTML

if( $allow_nav )
{

my $text_select_button = $allow_map_select ? "<button form=$location_form_id name=BUTTON:SELECT class='button act-button'><img src=i/map_location.svg> Select location</button>" : "&nbsp;";

$text .= <<END_OF_HTML;
<tr>
   <td align=left>
       $location_form_begin$back_button
   </td>
   <td align=right>
       <input  form=$location_form_id id=marker_location_xyz name=marker_location_xyz>
   </td>
   <td align=left>
       <input  form=$location_form_id type=submit value='Go to X,Y' class='button nav-button'>
   </td>
   <td>
   </td>
</tr>
<tr>
   <td align=left>
      $text_select_button
   </td>
   <td align=right>
       <form id=form-geo-search onsubmit='event.preventDefault(); geo_search(event);'></form>
       <input form=form-geo-search id=geo_search_input name=geo_search_input>
   </td>
   <td align=left>
       <input form=form-geo-search type=submit value=Search class='button nav-button'>
   </td>
   <td>
       $text_zoom_ctrl
   </td>
</tr>
END_OF_HTML

$text .= $location_form->end();
}

my $map_td_colspan = $allow_nav ? 4 : 1;

$text .= <<END_OF_HTML;
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
                 
    var marker_element = document.createElement( 'div' );
    marker_element.className = 'map_marker';    
    var marker = new tt.Marker( { element: marker_element, offset: [ 0, 6 ], color: '#ff0000', draggable: true } );
    var pois_visible = 0;

    map.addControl( new tt.FullscreenControl() );
    map.addControl( new tt.NavigationControl() );
    map.setZoom( $llz );
    map.setCenter( { lng: $lloc, lat: $llac } );
    map.on( 'click',   function (ev) { on_mouse_click( ev ) } );
    map.on( 'zoomend', function (ev) { on_zoomend( ev ) } );
    marker.on( 'dragend', function (ev) { on_marker_dropped( ev ) } );
    set_marker_to_lnglat( { lng: $llo, lat: $lla }, 1 );

    if( ! $allow_map_select )
      marker.setDraggable( false );
    //show_hide_pois();

    $add_markers

    if( $add_markers_count > 0 )
      map.fitBounds( [ [ $blo1, $bla1 ], [ $blo2, $bla2 ] ], { padding: { top: 128, bottom: 128, left: 128, right: 128 } }  );

    function num_dot_reduce( c, l )
    {
      return ( Math.round( c * l ) ) / l;
    }

    function coord_reduce( c )
    {
      return num_dot_reduce( c, 100000 );
    }

    function marker_recenter()
    {
      map.setCenter( marker.getLngLat() );
    }

    function update_marker_position_and_zoom( ll )
    {
      var xyz = document.getElementById( 'marker_location_xyz' );
      if( ! xyz ) return;
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
      
    function geo_search( ev )
    {
      tt.services.geocode({
                            key: '$tomtom_key',
                            query: ev.target.elements[ 'geo_search_input' ].value
                          }).then( geo_search_result );
      return false;                    
    }

</script>

  
END_OF_HTML

return $text;
}


1;
