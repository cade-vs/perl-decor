##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::Utils;
use strict;

use Exception::Sink;
use Data::Tools;
use Web::Reactor::HTML::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_web_handle_redirect_buttons
                
                de_web_get_cue
                
                de_web_update_record_with_id
                
                de_web_read_map_field_data
                de_web_read_map_far_table_data
                de_get_selected_map_names
                );

##############################################################################

sub de_web_handle_redirect_buttons
{
  my $reo   = shift; # web::reactor object

  my $button    = $reo->get_input_button();
  return unless $button eq 'REDIRECT';

  my $button_id = $reo->get_input_button_id();
  my $ps        = $reo->get_page_session();

  if( ! exists $ps->{ 'BUTTON_REDIRECT' }{ $button_id } )
    {
    my $psid        = $reo->get_page_session_id();
    my $usid        = $reo->get_user_session_id();
    $reo->log( "error: requesting unknown REDIRECT [$button_id] usid [$usid] psid [$psid]" );
    return undef;
    }
    
  return $reo->forward_type( @{ $ps->{ 'BUTTON_REDIRECT' }{ $button_id } } );  
}

##############################################################################

sub de_web_get_cue
{
  my $des_obj = shift;
  
  my $cue = $des_obj->get_attr( @_ );
  if( ! $cue and ! $des_obj->is_self_category() )
    {
#use Data::Dumper;
#print STDERR Dumper( '+-*-' x 200, $des_obj->is_self_category(), $des_obj );

    $cue = $des_obj->get_self_des()->get_attr( @_ );
    }
  
  my @cue = split /\s*;\s*/, $cue;
  
  s/%t/$des_obj->get_label()/gie for @cue;
  
  if( wantarray() )
    {
    if( @cue > 1 )
      {
      return @cue[ 0 ] if $cue[ 1 ] eq '-';
      return @cue[ 0, 1 ];
      }
    else
      {
      return @cue[ 0, 0 ];
      }  
    }
  else
    {
    return $cue[ 0 ];
    }  
}

##############################################################################

sub de_web_update_record_with_id
{
  my $core  = shift;
  my $table = shift;
  my $id    = shift;
  my $si    = shift;
  
  my %data;

  while( my ( $k, $v ) = each %$si )
    {
    next unless $k =~ /^F:([A-Z_0-9]+)$/;
    $data{ $1 } = $v;
    }

  my $res = $core->update( $table, \%data, { ID => $id } );
  
  return $res;
}

##############################################################################

# returns array ref with expanded map data from the map pointed by bfdes field description

sub de_web_read_map_field_data
{
  my $core  = shift;
  my $table = shift;
  my $field = shift;
  my $local_id = shift;

  my $tdes  = $core->describe( $table ) or return [];
  my $fdes  = $tdes->get_field_des( $field );
  my ( $map_table, $map_near_field, $map_far_field ) = $fdes->map_details();

  my $ar = $core->select_arhr( $map_table, [ '_ID', $map_far_field, 'STATE' ], { FILTER => { $map_near_field => $local_id }, ORDER_BY => '_ID' } );
  
  return $ar;
}

sub de_web_read_map_far_table_data
{
  my $core  = shift;
  my $table = shift;
  my $field = shift;

  my $tdes  = $core->describe( $table ) or return [];
  my $fdes  = $tdes->get_field_des( $field );
  my ( $map_table, $map_near_field, $map_far_field, $far_table, $far_field ) = $fdes->map_details();

  my $far_orderby = $fdes->get_attr( qw( WEB EDIT FAR_ORDERBY ) ) || '_ID';
  $far_orderby = '_ID' unless $far_orderby or $far_orderby == 1;

#  my $mtdes  = $core->describe( $map_table ) or return [];
#  my $mffdes = $mtdes->get_field_des( $map_far_field );

#  my ( $far_table, $far_field ) = $mffdes->link_details();

  my $ar = $core->select_arhr( $far_table, [ '_ID', $far_field, @_ ], { ORDER_BY => $far_orderby } );
  
  return wantarray ? ( $ar, $far_field ) : $ar;
}

sub de_get_selected_map_names
{
  my $core  = shift;
  my $bfdes = shift;
  my $id    = shift;
  
  my $table = $bfdes->table();
  my $field = $bfdes->name();

  my ( $map_table, $map_near_field, $map_far_field, $far_table, $far_field ) = $bfdes->map_details();

  my $far_orderby = $bfdes->get_attr( qw( WEB EDIT FAR_ORDERBY ) ) || '_ID';
  $far_orderby = '_ID' unless $far_orderby or $far_orderby == 1;

  my $map_data_ar = de_web_read_map_field_data( $core, $table, $field, $id );
  my @state_ids = map { $_->{ 'STATE' } ? $_->{ $map_far_field } : () } @$map_data_ar;

  #$field_input      .= "<xmp>" . Dumper( $map_data_ar, \@state_ids ) . "</xmp>";
  my $map_selected = $core->select_field_ar( $far_table, $far_field, { FILTER => { '_ID' => [ { OP => 'IN', VALUE => \@state_ids } ] }, ORDER_BY => $far_orderby } );
  
  return $map_selected;
}

### EOF ######################################################################
1;
