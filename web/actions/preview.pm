##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::preview;
use strict;

use Data::Dumper;
use Data::Tools 1.21;
use Exception::Sink;

use Web::Reactor::HTML::Utils;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

#  my $table   = $reo->param( 'TABLE'   );
#  my $id      = $reo->param( 'ID'      );

  my $core = $reo->de_connect();

  my $ps = $reo->get_page_session();

  my $table   = $ps->{ 'TABLE'   };
  my $id      = $ps->{ 'ID'      };

  return "<#e_data>" unless $table and $id;

  my $tdes = $core->describe( $table );

  my @fields           = @{ $ps->{ 'FIELDS_WRITE_AR'  } };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  push @fields, @{ $tdes->get_fields_list_by_oper( 'READ' ) };
  @fields = $tdes->sort_fields_by_order( list_uniq( @fields ) );
  
  #print STDERR Dumper( '*'x200, \@fields, $tdes );

  return "<#access_denied>" unless @fields;

  my $text .= "<br>";

  my $edit_mode_class_prefix = $edit_mode_insert ? 'insert' : 'edit';

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";
  $text .= "<table class='$edit_mode_class_prefix record' cellspacing=0 cellpadding=0>";
  $text .= "<tr class=$edit_mode_class_prefix-header>";
  $text .= "<td class='$edit_mode_class_prefix-header record-field fmt-right'>[~Field]</td>";
  $text .= "<td class='$edit_mode_class_prefix-header record-value fmt-left' >[~Value]</td>";
  $text .= "</tr>";

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;
  my $row_id = $row_data->{ '_ID' };

  my ( $calc_out, $calc_merrs )= $core->recalc( $table, $row_data, $row_id, $ps->{ 'EDIT_MODE_INSERT' }, { 'EDIT_SID' => $ps->{ 'EDIT_SID' } } );
  if( $calc_out )
    {
    $ps->{ 'ROW_DATA'      } = $calc_out;
    }
  else
    {
    return "<#e_internal>" . de_html_alink_button( $reo, 'back', "&lArr; [~Go back]", "[~Go back to the previous screen]"   );
    }

  if( $calc_merrs->{ '#' } )
    {
    $text .= "<div class=error-text><#review_errors></div>";
    if( $calc_merrs->{ '*' } )
      {
      $text .= "<div class=error-text>";
      $text .= "$_<br>\n" for @{ $calc_merrs->{ '*' } };
      $text .= "</div>";
      $text .= "<br>";
      }
    }

  $text .= "<br>";

  @fields = grep { /^_/ ? $reo->user_has_group( 1 ) ? 1 : 0 : 1 } @fields;

  for my $field ( @fields )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $bfdes     = $fdes; # keep sync code with view/grid, bfdes is begin/origin-field
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->get_attr( qw( WEB PREVIEW LABEL ) );
    
    next if $fdes->get_attr( qw( WEB PREVIEW SKIP ) );

    my $base_field = $field;

    my $data = $row_data->{ $field };
    my $data_fmt = de_web_format_field( $data, $fdes, 'PREVIEW' );
    my $field_error;
    
    $field_error .= "$_<br>\n" for @{ $calc_merrs->{ $field } };

    if( $bfdes->is_linked() or $bfdes->is_widelinked() )
      {
      
      my ( $linked_table, $linked_id, $linked_field );
      if( $bfdes->is_widelinked() ) 
        {
        ( $linked_table, $linked_id, $linked_field ) = type_widelink_parse2( $data );

        my $ltdes = $core->describe( $linked_table );
        if( $ltdes )
          {
          my $linked_table_label = $ltdes->get_label();
          if( $linked_field )
            {
            $data_fmt = $core->read_field( $linked_table, $linked_field, $linked_id );
            my $lfdes = $ltdes->get_field_des( $linked_field );
            $data_fmt  = de_web_format_field( $data_fmt, $lfdes, 'VIEW', { ID => $linked_id } );
            }
          else
            {
            $data_fmt = "[~Linked to a record from:] $linked_table_label";
            }  
          } # ltdes  
        else
          {
          $data_fmt = "&empty; ( $linked_table | $linked_id | $linked_field ) $data";
          }  
        }
      else
        {
        ( $linked_table, $linked_field ) = $bfdes->link_details();
        my $ldes = $core->describe( $linked_table );
        my ( $linked_field_x, $linked_field_x_des ) = $ldes->get_field_des( $linked_field )->expand_field_path();

        my $linked_field_x_data = $core->read_field( $linked_table, $linked_field_x, $data );

        $data_fmt = de_web_format_field( $linked_field_x_data, $linked_field_x_des, 'PREVIEW' );
        }  
      }
    elsif( $bfdes->is_backlinked() )
      {
      my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table );
      my $linked_table_label = $bltdes->get_label();

      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
      $count = 'Unknown' if $count eq '';

      $data_fmt = qq( <b class=hi>$count</b> [~records from] <b class=hi>$linked_table_label</b> );
      }

    $field_error = "<div class=warning align=right>$field_error</div>" if $field_error;

    my $base_field_class = lc "css_preview_class_$base_field";
    $text .= "<tr class=view>";
    $text .= "<td class='$edit_mode_class_prefix-field record-field $base_field_class' >$label$field_error</td>";
    $text .= "<td class='$edit_mode_class_prefix-value record-value $base_field_class' >$data_fmt</td>";
    $text .= "</tr>";
    }
  $text .= "</table>";

  my $ok_hint = $edit_mode_insert ? "[~Confirm new record insert]" : "[~Confirm record update]";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]"                                        );
  $text .= de_html_alink_button( $reo, 'here', "[~Edit] &uArr;",   "[~Back to data edit screen]", BTYPE => 'mod', ACTION => 'edit'   );
  $text .= de_html_alink_button( $reo, 'here', "[~OK] &radic;",     { HINT => $ok_hint, DISABLED => $calc_merrs->{ '#' }, DISABLE_ON_CLICK => 10, DISABLE_ON_CLICK_CLASS => 'button disabled-button' }, ACTION => 'commit' );

  return $text;
}

1;
