##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::edit;
use strict;
use Decor::Shared::Describe;
use Data::Dumper;
use Data::Tools;
use Exception::Sink;

use Decor::Shared::Types;
use Decor::Shared::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::Utils;
use Decor::Web::View;
use Decor::Web::Grid;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML; # elements, attributes, escaping, no longer exported by HTML::Utils
use Web::Reactor::HTML::More; # extended elements, hover and popup layers, no longer exported by HTML::Utils
use Web::Reactor::HTML::Layout;

my $clear_icon = 'i/input-clear.svg';

sub main
{
  my $reo = shift;

##  return unless $reo->is_logged_in();

  my $text;

  my $table   = $reo->param( 'TABLE'   );
  my $id      = $reo->param( 'ID'      );
  my $copy_id = $reo->param( 'COPY_ID' );

  my $mode_insert = !! ( $id < 0 );

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $rs = $reo->get_page_session(1);
  my $ps = $reo->get_page_session();
  my $us = $reo->get_user_session();

#-  $ps->{ 'EDIT_SID' } = $us->{ ':ID' } . '.' . $ps->{ ':ID' } . '.' . create_random_id( 64 ) unless $ps->{ 'EDIT_SID' }; # cc20261110-1
  $ps->{ 'EDIT_SID' } = $us->{ ':ID' } . '.' . $ps->{ ':ID' } . '.' . de_create_random_id() unless $ps->{ 'EDIT_SID' }; # cc20261110-1

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  # save extra args
  $reo->param( $_ ) for qw( LINK_TO_TABLE LINK_TO_FIELD LINK_TO_ID RETURN_DATA_FROM RETURN_DATA_TO );

  my $link_field_disable = uc $reo->param( 'LINK_FIELD_DISABLE' );
  my $link_field_id      =    $reo->param( 'LINK_FIELD_ID' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = des_table_des( $tdes ); # table "Self" description

  my $table_label = des_table_label( $tdes );

  if( $id == 0 )
    {
    $id = $core->select_first1_field( $table, '_ID', { ORDER_BY => 'DESC' } );

    #return "<#access_denied>" if $id == 0;
    }

  my $edit_mode_insert;
  my $edit_mode;
  my $fields_ar;

  if( ! $ps->{ 'INIT_DONE' } )
    {
    # check rights before INIT work (next_id, INIT method, record read), the checks below the INIT block stay for later requests
    return "<#access_denied>" if   $mode_insert and ! de_web_profile()->allows( $tdes, 'INSERT' );
    return "<#access_denied>" if ! $mode_insert and ! de_web_profile()->allows( $tdes, 'UPDATE' );
    return "<#access_denied>" if ! $mode_insert and ! $core->access( 'UPDATE', $table, $id );

    $ps->{ 'INIT_DONE' } = 1;
    if( $mode_insert )
      {
      # insert
      $edit_mode_insert = 1;
      $edit_mode        = 'INSERT';

      $id = $core->next_id( $table );
      my $status_ref = $core->status_ref();
      return "<#e_internal>[$status_ref]" unless $id > 0;

      $fields_ar = des_fields_list_by_oper( $tdes, 'INSERT', de_web_profile() );

      if( $copy_id )
        {
        # insert with copy
        my $row_data = $core->select_first1_by_id( $table, $fields_ar, $copy_id );
        delete $row_data->{ $_ } for grep { des_attr( des_fld( $tdes, $_ ), 'NO_COPY' ) } @$fields_ar;

        $ps->{ 'ROW_DATA' } = $row_data;
        $ps->{ 'ROW_DATA' }{ '_ID' } = $id;
        }
      else
        {
        # regular insert

        # exec init method
        $ps->{ 'ROW_DATA' } = $core->init( $table, $id );
        $ps->{ 'ROW_DATA' }{ '_ID' } = $id;
        }
      }
    else
      {
      # update
      $edit_mode_insert = 0;
      $edit_mode        = 'UPDATE';

      my $fields_rd;
      $fields_ar = des_fields_list_by_oper( $tdes, 'UPDATE', de_web_profile() );
      $fields_rd = des_fields_list_by_oper( $tdes, 'READ', de_web_profile() );

      my $row_data;
      # ID 0 is already resolved to the last record at the top, an empty table is denied by the access check above
      $row_data = $core->select_first1_by_id( $table, $fields_rd, $id );
      $ps->{ 'ROW_DATA' } = { map { $_ => $row_data->{ $_ } } @$fields_ar };
      }

    $ps->{ 'FIELDS_WRITE_AR'  } = $fields_ar;
    $ps->{ 'EDIT_MODE_INSERT' } = $edit_mode_insert;
    $ps->{ 'EDIT_MODE'        } = $edit_mode;

    $ps->{ 'TABLE' } = $table;
    $ps->{ 'ID'    } = $id;
    }
  else
    {
    $fields_ar        = $ps->{ 'FIELDS_WRITE_AR' };
    $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };
    $edit_mode        = $ps->{ 'EDIT_MODE'        };

    $table = $ps->{ 'TABLE' };
    $id    = $ps->{ 'ID'    };
    }

  my ( $browser_window_title ) = $reo->ps_path_add_by_cue( $sdes, $edit_mode, $ps->{ 'ROW_DATA' } ); # the hint is not used

  return "<#access_denied>" unless @$fields_ar;
  return "<#access_denied>" if   $edit_mode_insert and ! de_web_profile()->allows( $tdes, 'INSERT' );
  return "<#access_denied>" if ! $edit_mode_insert and ! de_web_profile()->allows( $tdes, 'UPDATE' );
  return "<#access_denied>" if ! $edit_mode_insert and ! $core->access( 'UPDATE', $table, $id );

  my $fields = join ',', @$fields_ar;

  my %ui_si = ( %$ui, %$si ); # merge inputs, SAFE_INPUT has priority

  if( $edit_mode_insert and $link_field_disable and $link_field_id and ! exists $ui_si{ "F:$link_field_disable" } )
    {
    # link field disable always requires to be filled on insert, unless already passed in the params
    $ui_si{ "F:$link_field_disable" } = $link_field_id;
    }

  my %upload_errors; # field => [ messages ], reported with the recalc field errors
  my $uploads = $reo->get_user_uploads(); # file inputs are never in the user input, see Web::Reactor get_user_uploads() # cc20261109-6

  # input data
  for my $field ( @$fields_ar )
    {
#-    next unless exists $ui_si{ "F:$field" }; # cc20261109-6
    next unless exists $ui_si{ "F:$field" } or exists $uploads->{ "F:$field" }; # cc20261109-6
    my $input_data = $ui_si{ "F:$field" };

    $input_data =~ s/^\s*//;
    $input_data =~ s/\s*\z//;

    my $fdes       = des_fld( $tdes, $field );
    my $type       = $fdes->{ 'TYPE'  };
    my $type_name  = des_type_name( $fdes );
    my $type_lname = $fdes->{ 'TYPE'  }{ 'LNAME' };

    my $pass_type  = ( des_attr( $fdes, 'PASSWORD' ) or $field =~ /^PASSWORD/ );
    # password inputs are rendered empty, empty input means "not changed", keep the current value
    next if $pass_type and $input_data eq '';

    if( $type_name eq 'LINK' and $type_lname eq 'FILE' )
      {
#-      my $upload = $ui_si{ "F:$field:UPLOADS" } || []; # cc20261109-6
#-      next unless @$upload; # cc20261109-6
#-      $upload = shift @$upload; # cc20261109-6
      my $upload = ( $uploads->{ "F:$field" } || [] )->[0]; # Plack::Request::Upload, the list is cached in $reo, not shifted # cc20261109-6
      next unless $upload and $upload->filename ne '' and $upload->size > 0; # no file chosen, keep the current one # cc20261109-6

      my ( $linked_table, $linked_field ) = des_link_details( $fdes );

#-      my $upload_fn = file_name_ext( $upload->{ 'filename' } ); # cc20261109-6
#-      my $mime      = $upload->{ 'headers' }{ 'content-type' }; # cc20261109-6
      my $upload_fn = file_name_ext( $upload->filename ); # cc20261109-6
      my $mime      = $upload->content_type; # cc20261109-6

#-      my $new_id    = $core->file_save( $upload->{ 'tempname' }, $linked_table, $upload_fn, undef, { MIME => $mime } ); # cc20261109-6
      my $new_id    = $core->file_save( $upload->path, $linked_table, $upload_fn, undef, { MIME => $mime } ); # cc20261109-6

      # file_save() gives undef on failure: keep the current file, report the upload
      if( $new_id > 0 )
        {
        $ps->{ 'ROW_DATA' }{ $field } = $new_id;
        }
      else
        {
        push @{ $upload_errors{ $field } }, "[~File upload failed]!";
        }
      next;
      }

    my $raw_input_data = type_revert( $input_data, $type );

    # TODO: handle passwords
    if( $pass_type )
      {
      ## $ps->{ 'PASS_SALT' } ||= create_random_id( 128 );
      ## # TODO: check for pass strength here
      ## $raw_input_data = de_password_salt_hash( $raw_input_data, $ps->{ 'PASS_SALT' } );

      # TODO: RSA encrypt here! decrypt in methods
      }

    $ps->{ 'ROW_DATA' }{ $field } = $raw_input_data;
    }

  # recalc data
  #$fields_ar        = $ps->{ 'FIELDS_WRITE_AR' };
  #$edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  # once per page: going back to the fill link must not replace data entered since
  if( $edit_mode_insert and $si->{ 'USE_LAST_DATA' } and exists $us->{ 'LAST_ROW_DATA' }{ $table } and ! $ps->{ 'ALREADY_USED_LAST_DATA' } )
    {
    $ps->{ 'ROW_DATA'      } = $us->{ 'LAST_ROW_DATA' }{ $table };
    $ps->{ 'ALREADY_USED_LAST_DATA' } = 1;
    }

  my $calc_in  = { map { $_ => $ps->{ 'ROW_DATA' }{ $_ } } @$fields_ar };
  my ( $calc_out, $calc_merrs )= $core->recalc( $table, $calc_in, $id, $edit_mode_insert, { %{ $ps }{ 'EDIT_SID', 'PASS_SALT' } } );

  if( $calc_out )
    {
    $ps->{ 'ROW_DATA'      } = $calc_out;
    }
  else
    {
    return "<#e_internal>" . de_html_alink_button( $reo, 'back', "&lArr; [~Go back]", "[~Go back to the previous screen]"   );
    }


  $calc_merrs ||= {};
  for my $field ( keys %upload_errors )
    {
    push @{ $calc_merrs->{ $field } }, @{ $upload_errors{ $field } };
    $calc_merrs->{ '#' }++;
    }

  for my $field ( @$fields_ar )
    {
    my $raw_data = $ps->{ 'ROW_DATA' }{ $field };
    my $fdes     = des_fld( $tdes, $field );
    my $type     = $fdes->{ 'TYPE'  };
    next unless des_is_required( $fdes );
    my $type_name = des_type_name( $fdes );
    next if $type_name eq 'CHAR' and $raw_data =~ /\S/;
    next if $type_name ne 'CHAR' and $raw_data != 0;

    push @{ $calc_merrs->{ $field } }, "[~This field is required]!";
    $calc_merrs->{ '#' }++;
    }

  if( $button_id eq 'PREVIEW' or $button_id eq 'OK' )
    {
    $us->{ 'LAST_ROW_DATA' }{ $table } = $calc_out if $edit_mode_insert;
    }

  if( ( $button_id eq 'PREVIEW' or $button_id eq 'OK' ) and ( $calc_merrs->{ '#' } > 0 ) )
    {
    $text .= "<p><div class=error-text><#review_errors></div>";
    }
  else
    {
    # handle redirects here
    de_web_handle_redirect_buttons( $reo );
    }


###  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  my $info_message  = $si->{ 'INFO_MESSAGE'  } || $si->{ 'MESSAGE' };
  my $error_message = $si->{ 'ERROR_MESSAGE' };
  $text .= "<div class=info-text>$info_message</div>"   if $info_message;
  $text .= "<div class=error-text>$error_message</div>" if $error_message;
  $text .= de_master_record_view( $reo );

  if( $button and $calc_merrs->{ '*' } )
    {
    $text .= "<div class=error-text>";
    $text .= html_escape( $_ ) . "<br>\n" for @{ $calc_merrs->{ '*' } }; # method messages are text, not html
    $text .= "</div>";
    $text .= "<br>";
    }

  my $edit_form = new Web::Reactor::HTML::Form( $reo );
  my $edit_form_begin;
  $edit_form_begin .= $edit_form->begin( NAME => "form_edit_$table", DEFAULT_BUTTON => 'REDIRECT:PREVIEW' );
  $edit_form_begin .= $edit_form->input( NAME => "ACTION", RETURN => "edit", HIDDEN => 1 );
  my $form_id = $edit_form->get_id();
  $edit_form_begin .= "<p>";

  $text .= $edit_form_begin;

  my $edit_mode_class_prefix = $edit_mode_insert ? 'insert' : 'update';

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";
#  $text .= "<table class='$edit_mode_class_prefix record' cellspacing=0 cellpadding=0>";
#  $text .= "<tr class=$edit_mode_class_prefix-header>";
#  $text .= "<td class='$edit_mode_class_prefix-header record-field fmt-center' colspan=2>$browser_window_title</td>";
#  $text .= "</tr>";

  $text .= "<div class='record-table'>";
  $text .= "<div class='$edit_mode_class_prefix-header record-sep fmt-center'>$browser_window_title</div>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };

  my @backlinks_text;

  my $record_first = 1;
  my @parts; # html strings (dividers, details) and field rows [ first, label html, input html, base class ], the last row is known after the loop
  my %advise = map { $_ => 1 } @{ des_fields_list_by_oper( $tdes, 'READ', de_web_profile() ) };
  my @fields = des_sort_fields_by_order( $tdes, list_uniq( @$fields_ar, keys %advise ) );
  for my $field ( @fields )
    {
    my $fdes       = des_fld( $tdes, $field );
    my $label      = des_attr( $fdes, 'WEB', $edit_mode, 'LABEL' ) || $field;
    my $type_name  = des_type_name( $fdes );
    my $required   = des_is_required( $fdes ) ? "<span class='required' title='[~Required field]'>*</span>" : undef; # as the required checks at 269 and 677

    next if des_attr( $fdes, 'WEB', $edit_mode, 'HIDE' );

    my $base_field = $field;

    my $field_data = $ps->{ 'ROW_DATA' }{ $field };

    next if des_attr( $fdes, 'WEB', $edit_mode, 'HIDE_IF_EMPTY' ) and type_is_empty( $type_name, $field_data );

    my $field_error;

    if( $button )
      {
      $field_error .= html_escape( $_ ) . "<br>\n" for @{ $calc_merrs->{ $field } }; # method messages are text, not html
      }

    my ( $field_input, $field_input_ctrl, $field_details, $backlinks_text );
    if( ! de_web_profile()->allows( $fdes, $edit_mode ) or $link_field_disable eq $field )
      {
      my $advise = uc des_attr( $fdes, 'ADVISE' );
      next unless $advise eq $edit_mode or $advise eq 'ALL';
      my $field_data_usr_format = de_web_format_field( $field_data, $fdes, 'VIEW', { CORE => $core, ID => $id } );
      #$field_input = $edit_form->input(
      #                                   NAME     => "F:$field:DISABLED",
      #                                   VALUE    => $field_data_usr_format,
      #                                   DISABLED => 1,
      #                                 );
      $field_input = $field_data_usr_format;
      }
    else
      {
      ( $field_input, $field_input_ctrl, $field_details, $backlinks_text ) = edit_get_field_control_info( $reo, $core, $id, $edit_form, $fdes, $field_data, undef );
      }

    # backlink grids first: a BACKLINK with DETAIL_FIELDS returns its grid with no input on purpose
    push @backlinks_text, @$backlinks_text if $backlinks_text;

    next unless defined $field_input;

    my $divider = des_attr( $fdes, 'WEB', 'DIVIDER' );
    if( $divider )
      {
      push @parts, "<div class='$edit_mode_class_prefix-divider record-sep fmt-center'>$divider</div>";
      $record_first = 1;
      }

    $field_error = html_element( 'div', $field_error, class => 'warning', style => 'text-align: left;' ) if $field_error; # no obsolete align attribute

#    my $input_layout = html_layout_2lr( $field_input, '&nbsp;&nbsp;' . $field_input_ctrl, '<==1>' );
    my $input_layout = html_hbox( '<100,1n>', $field_input, $field_input_ctrl );
    my $base_field_class = lc "css_edit_class_$base_field";

#    $text .= "<tr class=view>\n";
#    $text .= "<td class='$edit_mode_class_prefix-field record-field $base_field_class'>$label$field_error</td>\n";
#    $text .= "<td class='$edit_mode_class_prefix-value record-value $base_field_class' >$input_layout</td>\n";
#    $text .= "</tr>\n";

    # first shown row of the record or after a divider, as in view.pm
    # $required has its own translated title, no outer span with a second one
    push @parts, [ $record_first, "$label$required$field_error", $input_layout, $base_field_class ];
    $record_first = 0;


    if( $field_details )
      {
      push @parts, "<div class='$edit_mode_class_prefix-details record-details'>$field_details</div>";

#      $text .= "<tr class=view>";
#      $text .= "<td colspan=2 class='details-fields' >$field_details</td>";
#      $text .= "</tr>\n";
      #$data_layout .= $field_details;
      }
    }

  # the last shown row gets record-last, skipped (hidden) fields do not count
  my ( $last_row ) = grep { ref $parts[ $_ ] } reverse 0 .. $#parts;
  for my $i ( 0 .. $#parts )
    {
    my $part = $parts[ $i ];
    if( ! ref $part ) { $text .= $part; next; }
    my ( $first, $label_html, $input_html, $base_field_class ) = @$part;
    my $record_fl_class = join ' ', ( $first ? 'record-first' : () ), ( $i == $last_row ? 'record-last' : () );
    $text .= html_element( 'div',
                           html_element( 'div', $label_html, class => "$edit_mode_class_prefix-field record-field $record_fl_class $base_field_class" )
                         . html_element( 'div', $input_html, class => "$edit_mode_class_prefix-value record-value $record_fl_class $base_field_class" ),
                           class => 'record-field-value' );
    }
#  $text .= "</table>";
  $text .= "</div>";

  $text .= "<p>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]", BTYPE => 'nav'   );

  if( $edit_mode_insert and exists $us->{ 'LAST_ROW_DATA' }{ $table } and ! $ps->{ 'ALREADY_USED_LAST_DATA' } )
    {
    $text .= de_html_alink_button( $reo, 'here', "&copy; [~Fill last used data]", "[~Fill last used data]", BTYPE => 'nav', USE_LAST_DATA => 1   );
    }

  if( des_attr( $sdes, 'NO_PREVIEW' ) )
    {
    $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, "[~OK] &rArr;", { BTYPE => 'act', HINT => "[~Save data]" }, BUTTON_ID => 'OK', ACTION => 'commit' );
    }
  else
    {
    $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, "[~Preview] &rArr;", { BTYPE => 'act', HINT => "[~Preview data before save]" }, BUTTON_ID => 'PREVIEW', ACTION => 'preview' );
    }
  $text .= $edit_form->end();

  $text .= "<div class='record-table-envelope'>";
  $text .= join '', @backlinks_text;
  $text .= "</div>";

  return $text;
}

##############################################################################

sub edit_get_field_control_info
{
    my $reo        = shift;
    my $core       = shift;
    my $id         = shift;
    my $edit_form  = shift;
    my $fdes       = shift;
    my $field_data = shift;
    my $field_disabled = shift;

    # no LINK_FIELD_DISABLE check here: main() shows that field read-only and never calls this for it

    my $ps = $reo->get_page_session();

    my $table = des_item_table( $fdes );
    my $field = des_item_name( $fdes );

    my $bfdes      = $fdes; # keep sync code with view/preview/grid, bfdes is begin/origin-field
    my $type       = $fdes->{ 'TYPE'  };
    my $type_name  = des_type_name( $fdes );
    my $type_lname = $fdes->{ 'TYPE'  }{ 'LNAME' };
    my $flen       = $type->{ 'LEN' };

    my $field_data_placeholder_info = type_get_format_placeholder_info( $type );
    my $field_data_usr_format = type_format( $field_data, $type );

    my $field_id = "F:$table:$field:" . $reo->create_uniq_id();

    my $field_input;
    my $field_input_ctrl;
    my $field_details;

    my @backlinks_text;

    if( $type_name eq 'CHAR' )
      {
      my $pass_type = !! ( des_attr( $fdes, 'PASSWORD' ) or $field =~ /^PASSWORD/ );
      my $rows = des_attr( $fdes, 'WEB', 'ROWS' );
      my $field_size = $flen;
      my $field_maxlen = $field_size;
      $field_size = 42 if $field_size > 42; # TODO: fixme
      $field_data_usr_format = undef if $pass_type;
      if( $rows > 1 )
        {
        $field_input .= $edit_form->textarea(
                                         NAME     => "F:$field",
                                         ID       => $field_id,
                                         VALUE    => $field_data_usr_format,
                                         COLS     => $field_size,
                                         ROWS     => $rows,
                                         MAXLEN   => $field_maxlen,
                                         DISABLED => $field_disabled,
                                         );
        }
      else
        {
        $field_input .= $edit_form->input(
                                         NAME     => "F:$field",
                                         ID       => $field_id,
                                         PASS     => $pass_type,
                                         VALUE    => $field_data_usr_format,
                                         SIZE     => $field_size,
                                         MAXLEN   => $field_maxlen,
                                         DISABLED => $field_disabled,
                                         CLEAR    => $clear_icon,
                                         );
        }

      if( $type_lname eq 'LOCATION' )
        {
        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "map_location.svg", "[~Select map location]", ACTION => 'map_location', RETURN_DATA_TO => $field, LL => $field_data );
        }
      }
    elsif( $type_name eq 'LINK' and $type_lname eq 'FILE' )
      {
      $field_input = undef;

      if( $field_data > 0 )
        {
        my ( $linked_table, $linked_field ) = des_link_details( $fdes );
        my $ltdes = $core->describe( $linked_table );
        my $file_name = $core->read_field( $linked_table, 'NAME', $field_data );
        $field_input .= html_text( $file_name ); # the file name is user data
        $field_input .= "<p>";

        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_dn.svg", "[~Download current file]",           ACTION => 'file_dn', TABLE => $linked_table, ID => $field_data ) if de_web_profile()->allows( $ltdes, 'READ' );

        # FIXME: TODO: set option
        $field_input .= ' ' . html_element( 'iframe', '', src => '?_=' . $reo->args_type( 'new', ACTION => 'file_dn', TABLE => $linked_table, ID => $field_data ), width => '100%', height => '700px' ) . '<p> ';
        }

      $field_input .= "[~Upload new file:] " . $edit_form->file_upload( NAME     => "F:$field", ID => $field_id, );
      }
    elsif( $type_name eq 'LINK' )
      {

      my ( $linked_table, $linked_field ) = des_link_details( $fdes );
      my $ltdes = $core->describe( $linked_table );
      my $enum  = des_table_type( $ltdes ) eq 'ENUM';

      my $select_filter_name = uc des_attr( $fdes, 'WEB', 'SELECT_FILTER_NAME' );
      my $select_filter_bind = uc des_attr( $fdes, 'WEB', 'SELECT_FILTER_BIND' );
      my @select_filter_bind = map { $ps->{ 'ROW_DATA' }{ $_ } || 0 } split /[\s,]+/, $select_filter_bind;

      my $search = des_attr( $fdes, qw( WEB SEARCH ) );
      my $combo  = des_attr( $fdes, qw( WEB COMBO  ) );
      my $radio  = des_attr( $fdes, qw( WEB RADIO  ) );
      if( $radio or $combo or $search )
        {
        my $spf_fmt;
        my @spf_fld;
        my @ord_fld;
        if( $combo == 1 or $radio == 1 or $search == 1 )
          {
          $spf_fmt = "%s";
          @spf_fld = ( $linked_field );
          @ord_fld = ( '_ID' );
          }
        else
          {
          my @v = split /\s*;\s*/, ( $search || $combo );
          $spf_fmt = shift @v;
          $_ = uc $_ for @v;
          @spf_fld = @v;
          @ord_fld = @v;
          }

        for( @spf_fld )
          {
          $_ = des_expand_path( $ltdes, $_ );
          }

        my @combo_data;
        my $sel_hr     = {};
        $sel_hr->{ $field_data } = 1;

#        my @lfields = @{ des_fields_list_by_oper( $ltdes, 'READ', de_web_profile() ) };
        my @lfields = @spf_fld;
        unshift @lfields, '_ID', $linked_field;

##        return "<#access_denied>" unless @fields;

        my %bfdes; # base/begin/origin field descriptions, indexed by field path
        my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
        my %basef; # base fields map, return base field NAME by field path

        de_web_expand_resolve_fields_in_place( \@lfields, $ltdes, \%bfdes, \%lfdes, \%basef );

      #$text .= Dumper( \%basef );

        my $lfields = join ',', @lfields, values %basef;

        my $combo_orderby = des_attr( $fdes, qw( WEB COMBO ORDERBY ) ) || join( ',', @ord_fld );

        my $combo_select = $core->select( $linked_table, $lfields, { 'FILTER_NAME' => $select_filter_name, 'FILTER_BIND' => \@select_filter_bind, ORDER_BY => $combo_orderby, CHECK_ROW_LINK_ACCESS => 1 } );
        push @combo_data, { KEY => '*', VALUE => 0, LABEL => '&#8709;' } unless $search; # numeric reference, the label decoder has no &empty;
#$text .= "my $combo_select = $core->select( $linked_table, $lfields )<br>";
        while( my $hr = $core->fetch( $combo_select ) )
          {
          my @label = map { $hr->{ $_ } } @spf_fld;
          my $label = sprintf( $spf_fmt, @label );
          my $lid   = $hr->{ '_ID' }; # linked record id, not the edited record's $id

          $label = substr( $label, 0, 1021 ) . '...' if length( $label ) > 1021;

          push @combo_data, { KEY => '*', VALUE => $lid, LABEL => $label };
          }

        # auto-select single item if field is required
        if( des_is_required( $fdes ) and @combo_data == 2 )
          {
          $sel_hr->{ $combo_data[1]{ 'VALUE' } } = 1; # SELECTED matches VALUE, KEY is '*'
          }

        my $fmt_class; # " fmt-mono" or nothing, added to each input's own class: CLASS replaces Form's default class
        if( des_attr( $fdes, 'WEB', 'EDIT', 'MONO' ) )
          {
          $fmt_class .= " fmt-mono";
          }

        my $recalc_on_change; # no "my ... if", it may keep the previous field's value
        $recalc_on_change = 'http_form_submit( this.form, null, null )' if des_attr( $fdes, qw( WEB RECALC_ON_CHANGE ) );

        if( $search )
          {
          $field_data ||= 0;
          my $field_size = 42;
          my $field_maxlen = 1024;
          $field_size = 1024 if $field_size > 1024; # TODO: the size will be read from the description, may also enable overflow(?)
          $field_input .= $edit_form->input(
                                               NAME      => "F:$field",
                                               ID        => $field_id,
                                               CLASS     => "line$fmt_class", # Form's input default is "line"
                                               DATALIST  => \@combo_data,
                                               # Form finds the selected entry and shows its label, VALUE is not used with DATALIST # FIXME: needs review
                                               DATALIST_SELECTED_VALUE => $field_data, # FIXME: needs review
                                               EMPTY_KEY => 0,
                                               SIZE      => $field_size,
                                               MAXLEN    => $field_maxlen,
                                               SUBMIT_ON_CHANGE => $recalc_on_change,
                                               DISABLED  => $field_disabled,
                                               );
          }
        else
          {
          $field_input = $edit_form->combo(    NAME     => "F:$field",
                                               ID       => $field_id, # as the other field inputs
                                               CLASS    => "select$fmt_class",
                                               DATA     => \@combo_data,
                                               SELECTED => $sel_hr,
                                               # RADIO removed, Form select() has no radio mode
                                               SUBMIT_ON_CHANGE => $recalc_on_change,
                                               DISABLED  => $field_disabled,
                                               );
#$field_input .= "<xmp>".Dumper( $field, $field_data, $combo_data, $sel_hr )."</xmp>";

          }
        # end combo
        }
      else
        {
        # is not combo, i.e. regular LINK
        my $lfdes = des_describe_linked_field( $fdes );
        my ( $link_path, $llfdes ) = des_field_expand_path( $lfdes );
        my $link_data_fmt;
        my $link_data_class = 'link-data';

        if( $field_data > 0 )
          {
          my $link_data = $core->read_field( $linked_table, $link_path, $field_data ); # only a linked record can be read
          $link_data_fmt = de_web_format_field( $link_data, $llfdes, 'VIEW' );
          }
        else
          {
          $link_data_fmt = '&empty;';
          $link_data_class = 'link-empty';
          }

        $field_input = html_element( 'div', $link_data_fmt, class => $link_data_class );
        }

      if( ! $combo and ! $radio )
        {
        if( $field_data > 0 )
          {
          my $detach_cue = des_attr( $bfdes, qw( WEB EDIT DETACH_LINK_CUE ) ) || "[~Detach linked record]"; # the FIELD attribute is DETACH_LINK_CUE
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'here', $edit_form, "detach.svg",      $detach_cue, "F:$field" => 0 );
          }

        if( des_table_type( $ltdes ) eq 'FILE' )
          {
          if( $field_data > 0 )
            {
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_up.svg", "[~Upload and replace current file]", ACTION => 'file_up', TABLE => $linked_table, ID => $field_data ) if de_web_profile()->allows( $ltdes, 'UPDATE' );
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_dn.svg", "[~Download current file]",           ACTION => 'file_dn', TABLE => $linked_table, ID => $field_data ) if de_web_profile()->allows( $ltdes, 'READ' );
            }
          else
            {
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_new.svg", "[~Upload new file]", ACTION => 'file_up', TABLE => $linked_table, ID => -1, RETURN_DATA_TO => $field ) if de_web_profile()->allows( $ltdes, 'INSERT' );
            }
          }
        else
          {
          if( $field_data > 0 )
            {
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "view.svg", "[~View linked data]", ACTION => 'view', TABLE => $linked_table, ID => $field_data ) if de_web_profile()->allows( $ltdes, 'READ' ) and ! $enum;
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "edit.svg", "[~Edit linked data]", ACTION => 'edit', TABLE => $linked_table, ID => $field_data ) if de_web_profile()->allows( $ltdes, 'UPDATE' );
            }
          my $select_cue = des_attr( $bfdes, qw( WEB EDIT SELECT_LINK_CUE ) ) || "[~Select linked record]"; # SELECT_CUE was never a FIELD attribute
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "select-from.svg", $select_cue, ACTION => 'grid', TABLE => $linked_table, ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => $field, GRID_MODE => 'SELECT', SELECT_KEY_DATA => $field_data, ORDER_BY => '_ID', FILTER_NAME => $select_filter_name, FILTER_BIND => \@select_filter_bind ) if de_web_profile()->allows( $ltdes, 'READ' );
          }
        }
      # insert and link: for every LINK, combo and search too, outside the "! $combo and ! $radio" block above
      my $insert_cue = des_attr( $bfdes, qw( WEB EDIT INSERT_LINK_CUE ) ) || "[~Insert and link a new record]"; # INSERT_CUE is a table attribute, the FIELD one is INSERT_LINK_CUE
      $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "insert.svg",      $insert_cue, ACTION => 'edit', TABLE => $linked_table, ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => $field ) if de_web_profile()->allows( $ltdes, 'INSERT' );
      }
    elsif( $type_name eq 'MAP' )
      {
      my $map_edit_cue = des_attr( $bfdes, qw( WEB EDIT MAP_EDIT_CUE ) ) || "[~Edit map]";
      $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "map-edit.svg",      $map_edit_cue, ACTION => 'edit_map', TABLE => $table, FIELD => $field, ID => $id, MASTER_RECORD => "$table:$id" ); # TODO: if de_web_profile()->allows( $ltdes, 'INSERT' );

      $field_input .= join '', map { '* ' . html_text( $_ ) . '<br>' } @{ de_get_selected_map_names( $core, $bfdes, $id ) }; # map names are data
      }
    elsif( $type_name eq 'BACKLINK' )
      {
      my ( $backlinked_table, $backlinked_field ) = des_backlink_details( $bfdes );
      my $bltdes = $core->describe( $backlinked_table ) or return ();
      my $linked_table_label = des_table_label( $bltdes );

      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });

      my $detail_fields = des_attr( $bfdes, qw( WEB EDIT DETAIL_FIELDS ) );
      if( $detail_fields and $count > 0)
        {
        my $backlink_text;

        $detail_fields = join ',', @{ des_fields_list_by_oper( $bltdes, 'READ', de_web_profile() ) } if $detail_fields eq '*'; # only fields the user may read

        my $sub_de_data_grid_cb = sub
          {
          my $bid = shift; # backlinked record id from de_data_grid(), not the edited record's $id
          my $text;
          $text .= de_html_form_button_redirect( $reo, 'new', $edit_form, "view.svg", "[~View linked data]", ACTION => 'view', TABLE => $backlinked_table, ID => $bid, );
          $text .= de_html_form_button_redirect( $reo, 'new', $edit_form, "edit.svg", "[~Edit linked data]", ACTION => 'edit', TABLE => $backlinked_table, ID => $bid ) if de_web_profile()->allows( $bltdes, 'UPDATE' );
          return $text;
          };

        my $details_limit = des_attr( $bfdes, qw( WEB EDIT DETAILS_LIMIT ) ) || 16;
        $field_details .= "<p>" . de_data_grid( $core, $backlinked_table, $detail_fields, { FILTER => { $backlinked_field => $id }, LIMIT => $details_limit, CLASS => 'grid view record', TITLE => "[~Related] $linked_table_label", CTRL_CB => $sub_de_data_grid_cb } ) ;

        my ( $insert_cue, $insert_cue_hint ) = des_cue( des_table_des( $bltdes ), qw( WEB GRID INSERT_CUE ) );
        # BTYPE goes in the options hash (5th argument), the rest is redirect data
        # only when the grid above is cut by its limit, the block runs only for $count > 0
        $field_details .= de_html_form_button_redirect( $reo, 'new', $edit_form, "[~View all records]",  { HINT => "[~View all backlinked records from] <b>$linked_table_label</b>", BTYPE => 'nav' }, ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } ) if de_web_profile()->allows( $bltdes, 'READ' ) and $count > $details_limit;
        $field_details .= de_html_form_button_redirect( $reo, 'new', $edit_form, $insert_cue, { HINT => $insert_cue_hint, BTYPE => 'act' }, ACTION => 'edit', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, ID => -1, "F:$backlinked_field" => $id ) if de_web_profile()->allows( $bltdes, 'INSERT' );

        $backlink_text .= $field_details;

        push @backlinks_text, $backlink_text;
        $field_details = undef;
        $field_input   = undef; # skip from edit screen
        }
      else
        {
        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "grid.svg",   "[~View all backlinked records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } ) if de_web_profile()->allows( $bltdes, 'READ' ) and $count > 0;
        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "insert.svg", "[~Insert and link a new record into] <b>$linked_table_label</b>", ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field ) if de_web_profile()->allows( $bltdes, 'INSERT' );

        $count = '[~Unknown]' if $count eq '';

        $field_input = html_element( 'b', $count, class => 'hi' ) . ' [~records from] ' . html_element( 'b', $linked_table_label, class => 'hi' );
        }
      # EXPERIMENT: :)) $field_input .= "<p><div class=vframe><reactor_new_a=?action=grid&table=$backlinked_table>show</a></div>";
      }
    elsif( $type_name eq 'WIDELINK' )
      {
      # TODO: nothing for now, could display view information as in action view
      return ();
      }
    elsif( $type_lname eq 'BOOL' )
      {
      $field_input .= $edit_form->checkbox_multi(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data,
                                       # no RET or CLEAR, checkbox_multi() has neither, it sends the stage number
                                       LABELS   => [ map { html_element( 'img', undef, class => 'checkbox', src => "i/check-edit-$_.svg" ) } 0, 1 ],
                                       DISABLED => $field_disabled, # as the other field types
                                       );
      }
    elsif( $type_name eq 'INT' or $type_name eq 'REAL' ) # REAL has the same input as INT
      {
      my $field_size = $flen < 32 ? $flen : 32;
      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => $field_size,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       CLEAR    => $clear_icon,
                                       );
      }
    elsif( $type_name eq 'DATE' )
      {
      my $date_picker_div = html_element( 'div', '', id => "$field_id:DATE_SELECT_DIV" );

      # $field_input_ctrl .= qq( <input type=image class=icon src=i/set-time.svg $row_vec_handle> );

      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => 32,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       ATTRS    => { -ctxmenu => $date_picker_div }, # the picker opens on the context menu (right click)
                                       CLEAR    => $clear_icon,
                                       PHI      => $field_data_placeholder_info,
                                       );
      my $date_format = type_get_format( $type );
#      $field_input_ctrl .= qq( <input type=image class=icon src=i/set-time.svg onmouseover='$hl_handle' onClick='set_value( "$field_id", current_date( "$date_format" ) ); return false;'> );
      $field_input_ctrl .= ' ' . html_element_x( 'input', undef, type => 'image', class => 'icon', src => 'i/set-time.svg', onclick => 'set_value( ' . html_js_str( $field_id ) . ', current_date( ' . html_js_str( $date_format ) . ' ) ); return false;', -hint => '[~Set current date]', -reo => $reo ) . ' ';

      my $date_picker_icon_div = html_element( 'div', '', id => "$field_id:DATE_SELECT_DIV:ICON" );
      $field_input_ctrl .= ' ' . html_element_x( 'input', undef, type => 'image', class => 'icon', src => 'i/calendar.svg', id => "$field_id:cal-icon", -popup => $date_picker_icon_div, -reo => $reo ) . ' ';

      $reo->html_hold_kit_add( 'ACCUMULATOR_JS_ONLOAD', 'nz_setup_picker( ' . html_js_str( "$field_id:DATE_SELECT_DIV" )      . ', ' . html_js_str( $field_id ) . ', new Date( Date.now() ), ' . html_js_str( $date_format ) . ', function() { reactor_popup_hide_by_id( ' . html_js_str( $field_id ) . ' ) } );' . "\n" );
      $reo->html_hold_kit_add( 'ACCUMULATOR_JS_ONLOAD', 'nz_setup_picker( ' . html_js_str( "$field_id:DATE_SELECT_DIV:ICON" ) . ', ' . html_js_str( $field_id ) . ', new Date( Date.now() ), ' . html_js_str( $date_format ) . ', function() { reactor_popup_hide_by_id( ' . html_js_str( "$field_id:cal-icon" ) . ' ) } );' . "\n" );
      }
    elsif( $type_name eq 'TIME' )
      {
      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => 32,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       CLEAR    => $clear_icon,
                                       PHI      => $field_data_placeholder_info,
                                       );
      $field_input_ctrl .= ' ' . html_element_x( 'input', undef, type => 'image', class => 'icon', src => 'i/set-time.svg', onclick => 'set_value( ' . html_js_str( $field_id ) . ', current_time() ); return false;', -hint => '[~Set current time]', -reo => $reo );
      }
    elsif( $type_name eq 'UTIME' )
      {
      my $date_picker_div = html_element( 'div', '', id => "$field_id:UTIME_SELECT_DIV" );

      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => 32,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       ATTRS    => { -ctxmenu => $date_picker_div }, # the picker opens on the context menu (right click)
                                       CLEAR    => $clear_icon,
                                       PHI      => $field_data_placeholder_info,
                                       );
      my $date_format = type_get_format( $type );
      $field_input_ctrl .= html_element_x( 'input', undef, type => 'image', class => 'icon', src => 'i/set-time.svg', onclick => 'set_value( ' . html_js_str( $field_id ) . ', current_utime( ' . html_js_str( $date_format ) . ' ) ); return false;', -hint => '[~Set current date+time]', -reo => $reo );

      my $date_picker_icon_div = html_element( 'div', '', id => "$field_id:UTIME_SELECT_DIV:ICON" );
      $field_input_ctrl .= ' ' . html_element_x( 'input', undef, type => 'image', class => 'icon', src => 'i/calendar.svg', id => "$field_id:cal-icon", -popup => $date_picker_icon_div, -reo => $reo ) . ' ';

      $reo->html_hold_kit_add( 'ACCUMULATOR_JS_ONLOAD', 'nz_setup_picker( ' . html_js_str( "$field_id:UTIME_SELECT_DIV" )      . ', ' . html_js_str( $field_id ) . ', new Date( Date.now() ), ' . html_js_str( $date_format ) . ', function() { reactor_popup_hide_by_id( ' . html_js_str( $field_id ) . ' ) } );' . "\n" );
      $reo->html_hold_kit_add( 'ACCUMULATOR_JS_ONLOAD', 'nz_setup_picker( ' . html_js_str( "$field_id:UTIME_SELECT_DIV:ICON" ) . ', ' . html_js_str( $field_id ) . ', new Date( Date.now() ), ' . html_js_str( $date_format ) . ', function() { reactor_popup_hide_by_id( ' . html_js_str( "$field_id:cal-icon" ) . ' ) } );' . "\n" );
      }
    else
      {
      $field_input = '[~(unknown)]'; # translated, the type name is internal and never shown
      }

  return ( $field_input, $field_input_ctrl, $field_details, \@backlinks_text );
}

##############################################################################

1;
