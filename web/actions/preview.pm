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

###  return unless $reo->is_logged_in();

  my $text;

#  my $table   = $reo->param( 'TABLE'   );
#  my $id      = $reo->param( 'ID'      );

  my $core = $reo->de_connect();

  my $ps = $reo->get_page_session();

  my $table   = $ps->{ 'TABLE'   };
  my $id      = $ps->{ 'ID'      };

  return "<#e_data>" unless $table and $id;

  my $tdes        = $core->describe( $table );
  my $table_label = $tdes->get_label();

  my @fields           = @{ $ps->{ 'FIELDS_WRITE_AR'  } };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };
  
  my $edit_mode        = $edit_mode_insert ? 'INSERT' : 'UPDATE';

  #push @fields, @{ $tdes->get_fields_list_by_oper( 'READ' ) };
  @fields = $tdes->sort_fields_by_order( list_uniq( @fields ) );
  
  #print STDERR Dumper( '*'x200, \@fields, $tdes );

  return "<#access_denied>" unless @fields;

  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  my $browser_window_title;
  if( $edit_mode_insert )
    {
    $browser_window_title = qq(Preview data for the new record into "<b>$table_label</b>");
    $reo->ps_path_add( 'insert', $browser_window_title );
    }
  else
    {
    $browser_window_title = qq(Preview modified data from "<b>$table_label</b>");
    $reo->ps_path_add( 'edit', $browser_window_title );
    }

  my $text;

  $text .= "<p>";
  $text .= de_master_record_view( $reo );
  $text .= "<p>";

  my $edit_mode_class_prefix = $edit_mode_insert ? 'insert' : 'edit';

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;

  $text .= "<div class='record-table'>";
  $text .= "<div class='edit-header view-sep record-sep fmt-center'>$browser_window_title</div>";

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

  my %advise = map { $_ => 1 } @{ $tdes->get_fields_list_by_oper( 'READ' ) };

  my $record_first = 1;
  for my $field ( $tdes->sort_fields_list_by_order( list_uniq( @fields, keys %advise ) ) )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $bfdes     = $fdes; # keep sync code with view/grid, bfdes is begin/origin-field
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->get_attr( qw( WEB PREVIEW LABEL ) );
    
    next if $fdes->get_attr( qw( WEB HIDDEN       ) );
    next if $fdes->get_attr( qw( WEB PREVIEW HIDE ) );

    #my $advise = $fdes->{ 'ADVISE' };
    #next unless $advise eq $edit_mode or $advise eq 'ALL';

    my $base_field = $field;

    my $data = $row_data->{ $field };
    my $data_fmt = de_web_format_field( $data, $fdes, 'PREVIEW', { CORE => $core, NO_EDIT => 1, ID => $id } );
    my $field_error;
    
    $field_error .= "$_<br>\n" for @{ $calc_merrs->{ $field } };

=pod
    # FIXME: remove this and replace with plain de_web_format_field
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
=cut

    my $divider = $bfdes->get_attr( 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<div class='$edit_mode_class_prefix-divider $edit_mode_class_prefix-sep record-sep fmt-center'>$divider</div>";
      $record_first = 1;
      }

    $field_error = "<div class=warning align=right>$field_error</div>" if $field_error;

    my $base_field_class = lc "css_preview_class_$base_field";

    my $record_first_class = 'record-first' if $record_first;
    $record_first = 0;
    $text .= "<div class='record-field-value'>
                <div class='$edit_mode_class_prefix-field record-field $record_first_class $base_field_class' >$label$field_error</div>
                <div class='$edit_mode_class_prefix-value record-value $record_first_class $base_field_class' >$data_fmt</div>
              </div>";

    }
  $text .= "</div>";

  my $ok_hint = $edit_mode_insert ? "[~Confirm new record insert]" : "[~Confirm record update]";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]"                                        );
  $text .= de_html_alink_button( $reo, 'here', "[~Edit] &uArr;",   "[~Back to data edit screen]", BTYPE => 'mod', ACTION => 'edit'   );
  $text .= de_html_alink_button( $reo, 'here', "[~OK] &radic;",     { HINT => $ok_hint, DISABLED => $calc_merrs->{ '#' }, DISABLE_ON_CLICK => 10, DISABLE_ON_CLICK_CLASS => 'button disabled-button' }, ACTION => 'commit' );

  return $text;
}

1;
