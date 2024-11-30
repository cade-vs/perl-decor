##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::grid_sort;
use strict;
use Tie::IxHash;
use Data::Dumper;
use Exception::Sink;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::Utils;
use Decor::Web::View;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;

my $clear_icon = 'i/input-clear.svg';

sub main
{
  my $reo = shift;

###  return unless $reo->is_logged_in();

  my $text;

  my $table   = $reo->param( 'TABLE'   );

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();
  my $rs = $reo->get_page_session( 1 );

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };

#print STDERR Dumper( "READ fields: ", \@fields );

  my $browser_window_title = qq([~Filter records from] "<b>$table_label</b>");
  $reo->ps_path_add( 'filter', $browser_window_title );

#print STDERR Dumper( "error:", \@fields, $ps->{ 'ROW_DATA' }, 'insert', $edit_mode_insert, 'allow', $tdes->allows( 'UPDATE' ) );

  return "<#access_denied>" unless @fields > 0;

  my $fields = join ',', @fields;

  my %ui_si = ( %$ui, %$si ); # merge inputs, SAFE_INPUT has priority

  # handle redirects here
  de_web_handle_redirect_buttons( $reo );

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  if( $button eq 'OK' )
    {
    my @sort = split /;/, $ui->{ 'SORT-ORDER-INPUT' };

    #$text .= $ui->{ 'SORT-ORDER-INPUT' };
    
    my %sort;
    tie %sort, 'Tie::IxHash';
    for( @sort )
      {
      next unless /^(S:\S*)\s+(\d)/ and exists $ps->{ 'SORT_MAP' }{ $1 };
      $text .= $ps->{ 'SORT_MAP' }{ $1 };
      $sort{ $ps->{ 'SORT_MAP' }{ $1 } } = $2;
      }

    my @sort_sql;
    my @sort_des;

    for( keys %sort )
      {
      my $bfdes = $bfdes{ $_ };
      my $label = $bfdes->get_attr( qw( WEB GRID LABEL ) );
      
      if( $sort{ $_ } == 1 )
        {
        push @sort_des, "$label <img class='icon' src=i/sort-dn.svg>";
        push @sort_sql, ".$_ ASC"
        }
      else
        {
        push @sort_des, "$label <img class='icon' src=i/sort-up.svg>";
        push @sort_sql, ".$_ DESC"
        }  
      }
    
    $rs->{ 'SORTS' }{ 'ACTIVE' }{ 'SQL' } = join( ',', @sort_sql );
    $rs->{ 'SORTS' }{ 'ACTIVE' }{ 'DES' } = join( ' &raquo; ', @sort_des );
    
    return $reo->forward_back();
    }

  my $filter_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $filter_form_begin;
  $filter_form_begin .= $filter_form->begin( NAME => "form_filter_$table", DEFAULT_BUTTON => 'OK' );
  my $form_id = $filter_form->get_id();
  $filter_form_begin .= "<p>";

  $text .= $filter_form_begin;
  $text .= "<input type='hidden' name='sort-order-input' id='sort-order-input' value='' form='$form_id'>";


  $text .= "<div class='record-table'>";
  $text .= "<div class='view-header view-sep record-sep fmt-center'>$browser_window_title</div>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };


  my $labels_spans;
  $labels_spans .= html_element( 'span', "<img class='icon' src=i/check-edit-0.svg>" );
  $labels_spans .= html_element( 'span', "<img class='icon' src=i/sort-dn.svg>",       style => "display: none" );
  $labels_spans .= html_element( 'span', "<img class='icon' src=i/sort-up.svg>",       style => "display: none" );

  $ps->{ 'SORT_MAP' } = {};
  for my $field ( @fields )
    {
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type      = $lfdes->{ 'TYPE'  };
    my $type_name = $lfdes->{ 'TYPE'  }{ 'NAME' };

    my $base_field = $bfdes->{ 'NAME' };

    # skip hidden, backlinks, widelinks
    next if $bfdes->get_attr( 'WEB', 'HIDE' );
    next if $type_name eq 'BACKLINK'; 
    next if $type_name eq 'WIDELINK'; 

    my $label    = $bfdes->get_attr( qw( WEB GRID LABEL ) );

#    my $label     = "$blabel";
#    if( $bfdes ne $lfdes )
#      {
#      my $llabel     = $lfdes->get_attr( qw( WEB GRID LABEL ) );
#      $label .= "/$llabel";
#      }

    my $input_data = $ui_si{ "F:$field" } || ( $rs->{ 'FILTERS' }{ 'ACTIVE' } ? $rs->{ 'FILTERS' }{ 'ACTIVE' }{ 'DATA' }{ $base_field } : undef );

    my $field_error;

    my $field_control_id   = uc $reo->create_uniq_id( 1 );
    my $field_control_name = "S:" . $field_control_id;
    $ps->{ 'SORT_MAP' }{ $field_control_name } = $field;

    my $field_input;
    my $field_input_ctrl;

    $field_input .= html_element( "input", undef, type => 'hidden', name => $field_control_name, id => $field_control_name, value => '', form => $form_id );
    $field_input .= html_element( "span", $labels_spans, 'data-stages' => 3, 'data-checkbox-input-id' => $field_control_name, onclick => 'reactor_form_sort_toggle(this,"sort-order-input")' );

    my $divider = $bfdes->get_attr( 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<div class='view-divider view-sep record-sep fmt-center'>$divider</div>";
      }

    my $input_layout = html_layout_2lr( $field_input, $field_input_ctrl, '<==1>' );

    $text .= "<div class='record-field-value'>
                <div class='view-field record-field fmt-right'>$label</div>
                <div class='view-value record-value fmt-left' >$input_layout</div>
              </div>";
    }
  $text .= "</div>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]"   );
  $text .= $filter_form->button( NAME => 'OK', VALUE => "[~OK] &rArr;" );
#  $text .= de_html_form_button( $reo, 'here', $filter_form, 'OK', "[~OK] &rArr;", "Filter records now" );
  $text .= $filter_form->end();

  return $text;
}

1;
