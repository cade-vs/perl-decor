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
use Decor::Shared::Describe;
use Decor::Web::Utils;

use Data::Dumper;
use Data::Tools 1.21;
use Exception::Sink;

use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML; # elements, attributes, escaping, no longer exported by HTML::Utils

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
  my $table_label = des_table_label( $tdes );

  my @fields           = @{ $ps->{ 'FIELDS_WRITE_AR'  } };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };
  
  #push @fields, @{ des_fields_list_by_oper( $tdes, 'READ', de_web_profile() ) };
  @fields = des_sort_fields_by_order( $tdes, list_uniq( @fields ) );
  
  #print STDERR Dumper( '*'x200, \@fields, $tdes );

  return "<#access_denied>" unless @fields;

  my $browser_window_title;
  if( $edit_mode_insert )
    {
    $browser_window_title = qq([~Preview data for the new record into] "<b>$table_label</b>"); # translated
    $reo->ps_path_add( 'insert', $browser_window_title );
    }
  else
    {
    $browser_window_title = qq([~Preview modified data from] "<b>$table_label</b>"); # translated
    $reo->ps_path_add( 'edit', $browser_window_title );
    }

  $text .= "<p>";
  $text .= de_master_record_view( $reo );
  $text .= "<p>";

  my $edit_mode_class_prefix = $edit_mode_insert ? 'insert' : 'update';

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;

  $text .= "<div class='record-table'>";
#-  $text .= "<div class='$edit_mode_class_prefix-header record-sep fmt-center'>$browser_window_title</div>"; # cc20261110-5
  $text .= html_element( 'div', $browser_window_title, class => "$edit_mode_class_prefix-header record-sep fmt-center" ); # cc20261110-5

  my $row_id = $row_data->{ '_ID' };

#-  my ( $calc_out, $calc_merrs )= $core->recalc( $table, $row_data, $row_id, $ps->{ 'EDIT_MODE_INSERT' }, { 'EDIT_SID' => $ps->{ 'EDIT_SID' } } ); # cc20261109-2
  my $calc_in = { map { $_ => $row_data->{ $_ } } @{ $ps->{ 'FIELDS_WRITE_AR' } } }; # only writable fields, the same as edit.pm, the core checks field access # cc20261109-2
  my ( $calc_out, $calc_merrs )= $core->recalc( $table, $calc_in, $row_id, $ps->{ 'EDIT_MODE_INSERT' }, { 'EDIT_SID' => $ps->{ 'EDIT_SID' } } ); # cc20261109-2
  if( $calc_out )
    {
    $ps->{ 'ROW_DATA'      } = $calc_out;
    $row_data                = $calc_out; # show the recalculated data, the same that will be committed
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
#-      $text .= html_escape( $_ ) . "<br>\n" for @{ $calc_merrs->{ '*' } }; # method messages are text, not html # cc20261110-4
      $text .= html_text( $_ ) . "<br>\n" for @{ $calc_merrs->{ '*' } }; # method messages are text, not html # cc20261110-4
      $text .= "</div>";
      $text .= "<br>";
      }
    }

  $text .= "<br>";

  my %advise = map { $_ => 1 } @{ des_fields_list_by_oper( $tdes, 'READ', de_web_profile() ) };

  @fields = list_uniq( @fields, keys %advise );
  @fields = grep { /^_/ ? $reo->user_has_group( 1 ) ? 1 : 0 : 1 } @fields; # after the readable fields are added, they had the underscore fields back

  my $record_first = 1;
  for my $field ( des_sort_fields_by_order( $tdes, @fields ) )
    {
    my $fdes      = des_fld( $tdes, $field );
    # no $bfdes, preview has no linked field paths, the begin/origin field is the field itself
    my $type_name = des_type_name( $fdes );
    my $label     = des_attr( $fdes, qw( WEB PREVIEW LABEL ) );
    

    next if des_attr( $fdes, qw( WEB HIDE         ) ); # HIDDEN is no description attribute, it was always undef
    next if des_attr( $fdes, qw( WEB PREVIEW HIDE ) );
    next if des_attr( $fdes, qw( NO_PREVIEW ) );

    #my $advise = $fdes->{ 'ADVISE' };
    #next unless $advise eq $edit_mode or $advise eq 'ALL';

    my $base_field = $field;

    my $data = $row_data->{ $field };
    next if des_attr( $fdes, qw( WEB VIEW HIDE_IF_EMPTY ) ) and type_is_empty( $type_name, $data );

    my $data_fmt = de_web_format_field( $data, $fdes, 'PREVIEW', { CORE => $core, NO_EDIT => 1, ID => $id } );
    my $field_error;
    
#-    $field_error .= html_escape( $_ ) . "<br>\n" for @{ $calc_merrs->{ $field } }; # method messages are text, not html # cc20261110-4
    $field_error .= html_text( $_ ) . "<br>\n" for @{ $calc_merrs->{ $field } }; # method messages are text, not html # cc20261110-4

    # the old linked/backlinked formatting (=pod block, already disabled) is removed, de_web_format_field() above does it

    my $divider = des_attr( $fdes, 'WEB', 'DIVIDER' );
    if( $divider )
      {
#-      $text .= "<div class='$edit_mode_class_prefix-divider record-sep fmt-center'>$divider</div>"; # cc20261110-5
      $text .= html_element( 'div', $divider, class => "$edit_mode_class_prefix-divider record-sep fmt-center" ); # cc20261110-5
      $record_first = 1;
      }

    $field_error = html_element( 'div', $field_error, class => 'warning', style => 'text-align: right;' ) if $field_error; # no obsolete align attribute

    my $base_field_class = lc "css_preview_class_$base_field";

    my $record_first_class = $record_first ? 'record-first' : ''; # no "my ... if", it may keep the value from the previous loop pass
    $record_first = 0;
#-    $text .= "<div class='record-field-value'> # cc20261110-5
#-                <div class='$edit_mode_class_prefix-field record-field $record_first_class $base_field_class' >$label$field_error</div> # cc20261110-5
#-                <div class='$edit_mode_class_prefix-value record-value $record_first_class $base_field_class' >$data_fmt</div> # cc20261110-5
#-              </div>"; # cc20261110-5
    $text .= html_element( 'div', "\n" # cc20261110-5
                . html_element( 'div', "$label$field_error", class => "$edit_mode_class_prefix-field record-field $record_first_class $base_field_class" ) . "\n" # cc20261110-5
                . html_element( 'div', $data_fmt,            class => "$edit_mode_class_prefix-value record-value $record_first_class $base_field_class" ) . "\n", # cc20261110-5
              class => 'record-field-value' ); # cc20261110-5

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
