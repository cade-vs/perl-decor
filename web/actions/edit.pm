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

  my $mode_insert = 1 if $id < 0;

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();
  my $us = $reo->get_user_session();
  
  $ps->{ 'EDIT_SID' } = $us->{ ':ID' } . '.' . $ps->{ ':ID' } . '.' . create_random_id( 64 ) unless $ps->{ 'EDIT_SID' };

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  # save extra args
  $reo->param( $_ ) for qw( LINK_TO_TABLE LINK_TO_FIELD LINK_TO_ID RETURN_DATA_FROM RETURN_DATA_TO );

  my $link_field_disable = $reo->param( 'LINK_FIELD_DISABLE' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = $tdes->get_table_des(); # table "Self" description

  my $table_label = $tdes->get_label();

  if( $id == 0 )
    {
    $id = $core->select_first1_field( $table, '_ID', { ORDER_BY => 'DESC' } );

    return "<#access_denied>" if $id == 0;
    }

  my $edit_mode_insert;
  my $fields_ar;

  if( ! $ps->{ 'INIT_DONE' } )
    {
    $ps->{ 'INIT_DONE' } = 1;
    if( $mode_insert )
      {
      # insert
      $edit_mode_insert = 1;

      $id = $core->next_id( $table );
      my $status_ref = $core->status_ref();
      return "<#e_internal>[$status_ref]" unless $id > 0;

      $fields_ar = $tdes->get_fields_list_by_oper( 'INSERT' );

      if( $copy_id )
        {
        # insert with copy
        my $row_data = $core->select_first1_by_id( $table, $fields_ar, $copy_id );
        $ps->{ 'ROW_DATA' } = $row_data;
        $ps->{ 'ROW_DATA' }{ '_ID' } = $id;
        }
      else
        {
        # regular insert

        # exec default method
        $ps->{ 'ROW_DATA' } = {};
        $ps->{ 'ROW_DATA' }{ '_ID' } = $id;
        }
      }
    else
      {
      # update
      $edit_mode_insert = 0;
      $fields_ar = $tdes->get_fields_list_by_oper( 'UPDATE' );
      my $row_data = $core->select_first1_by_id( $table, $fields_ar, $id );
      $ps->{ 'ROW_DATA' } = $row_data;
      }

    $ps->{ 'FIELDS_WRITE_AR'  } = $fields_ar;
    $ps->{ 'EDIT_MODE_INSERT' } = $edit_mode_insert;

    $ps->{ 'TABLE' } = $table;
    $ps->{ 'ID'    } = $id;
    }
  else
    {
    $fields_ar        = $ps->{ 'FIELDS_WRITE_AR' };
    $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

    $table = $ps->{ 'TABLE' };
    $id    = $ps->{ 'ID'    };
    }

  my $browser_window_title;
  if( $edit_mode_insert )
    {
    my ( $insert_cue, $insert_cue_hint ) = de_web_get_cue( $sdes, qw( WEB INSERT INSERT_CUE ) );
    $browser_window_title = $insert_cue || qq(Insert new record into "<b>$table_label</b>");
    $reo->ps_path_add( 'insert', $browser_window_title );
    }
  else
    {
    my ( $update_cue, $update_cue_hint ) = de_web_get_cue( $sdes, qw( WEB UPDATE UPDATE_CUE ) );
    $browser_window_title = $update_cue || qq(Edit record data from "<b>$table_label</b>");
    $reo->ps_path_add( 'edit', $browser_window_title );
    }

  return "<#access_denied>" unless @$fields_ar;
  return "<#access_denied>" if   $edit_mode_insert and ! $tdes->allows( 'INSERT' );
  return "<#access_denied>" if ! $edit_mode_insert and ! $tdes->allows( 'UPDATE' );
  return "<#access_denied>" if ! $edit_mode_insert and ! $core->access( 'UPDATE', $table, $id );

  my $fields = join ',', @$fields_ar;

  my %ui_si = ( %$ui, %$si ); # merge inputs, SAFE_INPUT has priority

  # input data
  for my $field ( @$fields_ar )
    {
    next unless exists $ui_si{ "F:$field" };
    my $input_data = $ui_si{ "F:$field" };

    my $fdes       = $tdes->{ 'FIELD' }{ $field };
    my $type       = $fdes->{ 'TYPE'  };
    my $type_name  = $fdes->{ 'TYPE'  }{  'NAME' };
    my $type_lname = $fdes->{ 'TYPE'  }{ 'LNAME' };

    if( $type_name eq 'LINK' and $type_lname eq 'FILE' )
      {
      my $upload = $ui_si{ "F:$field:UPLOADS" } || [];
      next unless @$upload;
      $upload = shift @$upload;

      my ( $linked_table, $linked_field ) = $fdes->link_details();

      my $upload_fn = file_name_ext( $upload->{ 'filename' } );
      my $mime      = $upload->{ 'headers' }{ 'content-type' };
  
      my $new_id    = $core->file_save( $upload->{ 'tempname' }, $linked_table, $upload_fn, undef, { MIME => $mime } );

      $ps->{ 'ROW_DATA' }{ $field } = $new_id;
      next;
      }

    my $raw_input_data = type_revert( $input_data, $type );

    # TODO: handle passwords
    if( $fdes->{ 'PASSWORD' } or $field =~ /^PASSWORD/ )
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

  if( $edit_mode_insert and $si->{ 'USE_LAST_DATA' } and exists $us->{ 'LAST_ROW_DATA' }{ $table } )
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
  for my $field ( @$fields_ar )
    {
    my $raw_data = $ps->{ 'ROW_DATA' }{ $field };
    my $fdes     = $tdes->{ 'FIELD' }{ $field };
    my $type     = $fdes->{ 'TYPE'  };
    next unless $fdes->{ 'REQUIRED' };
    my $type_name = $type->{ 'NAME' };
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
    $text .= "<div class=error-text><#review_errors></div>";
    }
  else  
    {
    # handle redirects here
    de_web_handle_redirect_buttons( $reo );
    }  

###  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  $text .= "<br>";

  if( $link_field_disable )
    {
    # this should be really master record, not just disabled
    my $bfdes = $tdes->get_field_des( $link_field_disable );
    my ( $linked_table, $linked_field ) = $bfdes->link_details();
    my $link_id = $ps->{ 'ROW_DATA' }{ $link_field_disable };
    my $ltdes = $core->describe( $linked_table );
    my $lsdes = $ltdes->get_table_des(); # table "Self" description
    my $linked_table_label = $ltdes->get_label();
    my $master_fields = uc $lsdes->get_attr( qw( WEB MASTER_FIELDS ) );
    #$text .= de_data_grid( $core, $linked_table, $master_fields, { FILTER => { '_ID' => $link_id }, LIMIT => 1, CLASS => 'grid view record', TITLE => "[~Master record from] $linked_table_label" } ) if $master_fields;
    $text .= de_data_view( $core, $linked_table, $master_fields, $link_id, { CLASS => 'grid view record', TITLE => "[~Master record from] $linked_table_label" } ) if $master_fields;
    $text .= "<p>";
    }

  if( $button and $calc_merrs->{ '*' } )
    {
    $text .= "<div class=error-text>";
    $text .= "$_<br>\n" for @{ $calc_merrs->{ '*' } };
    $text .= "</div>";
    $text .= "<br>";
    }

  my $edit_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $edit_form_begin;
  $edit_form_begin .= $edit_form->begin( NAME => "form_edit_$table", DEFAULT_BUTTON => 'REDIRECT:PREVIEW' );
  $edit_form_begin .= $edit_form->input( NAME => "ACTION", RETURN => "edit", HIDDEN => 1 );
  my $form_id = $edit_form->get_id();
  $edit_form_begin .= "<p>";

  $text .= $edit_form_begin;

  my $edit_mode_class_prefix = $edit_mode_insert ? 'insert' : 'edit';

  my $custom_css = lc "css_$table";
  $text .= "<#$custom_css>";
#  $text .= "<table class='$edit_mode_class_prefix record' cellspacing=0 cellpadding=0>";
#  $text .= "<tr class=$edit_mode_class_prefix-header>";
#  $text .= "<td class='$edit_mode_class_prefix-header record-field fmt-center' colspan=2>$browser_window_title</td>";
#  $text .= "</tr>";

  $text .= "<div class='record-table'>";
  $text .= "<div class='edit-header view-sep record-sep fmt-center'>$browser_window_title</div>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };

  my @backlinks_text;

  my $record_first = 1;
  for my $field ( @$fields_ar )
    {
    my $fdes       = $tdes->{ 'FIELD' }{ $field };
    my $bfdes      = $fdes; # keep sync code with view/preview/grid, bfdes is begin/origin-field
    my $type       = $fdes->{ 'TYPE'  };
    my $type_name  = $fdes->{ 'TYPE'  }{  'NAME' };
    my $type_lname = $fdes->{ 'TYPE'  }{ 'LNAME' };
    my $label      = $fdes->{ 'LABEL' } || $field;
    my $flen       = $type->{ 'LEN' };

    next if $fdes->get_attr( 'WEB', ( $edit_mode_insert ? 'INSERT' : 'UPDATE' ), 'HIDE' );

    my $base_field = $field;

    my $field_data = $ps->{ 'ROW_DATA' }{ $field };
    my $field_data_usr_format = type_format( $field_data, $type );

    my $field_error;

    if( $button )
      {
      $field_error .= "$_<br>\n" for @{ $calc_merrs->{ $field } };
      }

    my $field_id = "F:$table:$field:" . $reo->create_uniq_id();

    my $field_input;
    my $field_input_ctrl;
    my $input_tag_args;
    my $field_disabled;
    my $field_details;

    if( $type_name eq 'CHAR' )
      {
      my $pass_type = 1 if $fdes->{ 'PASSWORD' } or $field =~ /^PASSWORD/;
      my $rows = $fdes->get_attr( 'WEB', 'ROWS' );
      my $field_size = $flen;
      my $field_maxlen = $field_size;
      $field_size = 40 if $field_size > 40; # TODO: fixme
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
                                         ARGS     => $input_tag_args,
                                         CLEAR    => $clear_icon,
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
                                         ARGS     => $input_tag_args,
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
        my ( $linked_table, $linked_field ) = $fdes->link_details();
        my $ltdes = $core->describe( $linked_table );
        my $file_name = $core->read_field( $linked_table, 'NAME', $field_data );
        $field_input .= $file_name;
        $field_input .= "<br><br>";

        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_dn.svg", "[~Download current file]",           ACTION => 'file_dn', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'READ' );
        }

      $field_input .= "[~Upload new file:] " . $edit_form->file_upload(
                                         NAME     => "F:$field",
                                         ID       => $field_id,
                                         );
      }
    elsif( $type_name eq 'LINK' )
      {
      my ( $linked_table, $linked_field ) = $fdes->link_details();
      my $ltdes = $core->describe( $linked_table );
      my $enum  = $ltdes->get_table_type() eq 'ENUM';

      my $select_filter_name = uc $fdes->get_attr( 'WEB', 'SELECT_FILTER_NAME' );
      my $select_filter_bind = uc $fdes->get_attr( 'WEB', 'SELECT_FILTER_BIND' );
      my @select_filter_bind = map { $ps->{ 'ROW_DATA' }{ $_ } || 0 } split /[\s,]+/, $select_filter_bind;

      my $search = $fdes->get_attr( qw( WEB SEARCH ) );
      my $combo  = $fdes->get_attr( qw( WEB COMBO  ) );
      my $radio  = $fdes->get_attr( qw( WEB RADIO  ) );
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
          @spf_fld = @v;
          @ord_fld = @v;
          }


        my $combo_data = [];
        my $sel_hr     = {};
        $sel_hr->{ $field_data } = 1;

        my @lfields = @{ $ltdes->get_fields_list_by_oper( 'READ' ) };
        unshift @lfields, $linked_field;

##        return "<#access_denied>" unless @fields;

        my %bfdes; # base/begin/origin field descriptions, indexed by field path
        my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
        my %basef; # base fields map, return base field NAME by field path

        de_web_expand_resolve_fields_in_place( \@lfields, $ltdes, \%bfdes, \%lfdes, \%basef );

      #$text .= Dumper( \%basef );
        my $selected_search_value;

        my $lfields = join ',', '_ID', @lfields, values %basef;

        my $combo_orderby = $fdes->get_attr( qw( WEB COMBO ORDERBY ) ) || join( ',', @ord_fld );

        my $combo_select = $core->select( $linked_table, $lfields, { 'FILTER_NAME' => $select_filter_name, 'FILTER_BIND' => \@select_filter_bind, ORDER_BY => $combo_orderby } );
        push @$combo_data, { KEY => 0, VALUE => '&empty;' } unless $search;
#$text .= "my $combo_select = $core->select( $linked_table, $lfields )<br>";
        while( my $hr = $core->fetch( $combo_select ) )
          {
          my @value = map { $hr->{ $_ } } @spf_fld;
          my $key   = $hr->{ '_ID' };
          my $value = sprintf( $spf_fmt, @value );

          $selected_search_value = $value if $key eq $field_data;
#$text .= "$key -- [$spf_fmt][@spf_fld][$value][@value]<br>";
          $value =~ s/\s/&nbsp;/g;
          push @$combo_data, { KEY => $key, VALUE => $value };
          }

        my $fmt_class;
        if( $fdes->get_attr( 'WEB', 'EDIT', 'MONO' ) )
          {
          $fmt_class .= " fmt-mono";
          }


        my $recalc_on_change = $fdes->get_attr( qw( WEB RECALC_ON_CHANGE ) );

        if( $search )
          {
          $field_data ||= 0;
          my $field_size = 42;
          my $field_maxlen = $field_size;
          $field_size = 42 if $field_size > 42; # TODO: fixme
          $field_input .= $edit_form->input(
                                               NAME      => "F:$field",
                                               ID        => $field_id,
                                               VALUE     => $selected_search_value,
                                               KEY       => $field_data,
                                               EMPTY_KEY => 0,
                                               DATALIST  => $combo_data,
                                               SIZE      => $field_size,
                                               MAXLEN    => $field_maxlen,
                                               RESUBMIT_ON_CHANGE => $recalc_on_change,
                                               );
          }
        else
          {  
          $field_input = $edit_form->combo(    NAME     => "F:$field", 
                                               CLASS    => $fmt_class, 
                                               DATA     => $combo_data, 
                                               SELECTED => $sel_hr,
                                               RADIO    => $radio,
                                               RESUBMIT_ON_CHANGE => $recalc_on_change,
                                               );
          }
        # end combo
        }
      else
        {
        # is not combo, i.e. regular LINK
        my $lfdes = $fdes->describe_linked_field();
        my ( $link_path, $llfdes ) = $lfdes->expand_field_path();
        my $link_data = $core->read_field( $linked_table, $link_path, $field_data );
        my $link_data_fmt;
        my $link_data_class = 'link-data';

        if( $field_data > 0 )
          {
          $link_data_fmt = de_web_format_field( $link_data, $llfdes, 'VIEW' );
          }
        else
          {
          $link_data_fmt = '&empty;';
          $link_data_class = 'link-empty';
          }

        $field_input = "<div class='$link_data_class'>$link_data_fmt</div>";
        }

      next if $link_field_disable and $link_field_disable eq $field;

      if( ! $combo and ! $radio )  
        {
        if( $field_data > 0 )
          {
          my $detach_cue = $bfdes->get_attr( qw( WEB EDIT DETACH_LINKED_CUE ) ) || "[~Detach linked record]";
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'here', $edit_form, "detach.svg",      $detach_cue, "F:$field" => 0 );
          }
        
        if( $ltdes->get_table_type() eq 'FILE' )
          {
          if( $field_data > 0 )
            {
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_up.svg", "[~Upload and replace current file]", ACTION => 'file_up', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'UPDATE' );
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_dn.svg", "[~Download current file]",           ACTION => 'file_dn', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'READ' );
            }
          else
            {
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "file_new.svg", "[~Upload new file]", ACTION => 'file_up', TABLE => $linked_table, ID => -1, RETURN_DATA_TO => $field ) if $ltdes->allows( 'INSERT' );
            }
          }
        else
          {
          if( $field_data > 0 )
            {
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "view.svg", "[~View linked data]", ACTION => 'view', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'READ'   ) and ! $enum;
            $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "edit.svg", "[~Edit linked data]", ACTION => 'edit', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'UPDATE' );
            }
          my $insert_cue = $bfdes->get_attr( qw( WEB EDIT INSERT_CUE ) ) || "[~Insert and link a new record]";
          my $select_cue = $bfdes->get_attr( qw( WEB EDIT SELECT_CUE ) ) || "[~Select linked record]";
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "insert.svg",      $insert_cue, ACTION => 'edit', TABLE => $linked_table, ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => $field ) if $ltdes->allows( 'INSERT' );
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "select-from.svg", $select_cue, ACTION => 'grid', TABLE => $linked_table, ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => $field, GRID_MODE => 'SELECT', SELECT_KEY_DATA => $field_data, FILTER_NAME => $select_filter_name ) if $ltdes->allows( 'READ'   );
          }
        }
      }
    elsif( $type_name eq 'BACKLINK' )
      {
      my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table ) or next;
      my $linked_table_label = $bltdes->get_label();

      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });

      $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "grid.svg",   "[~View all backlinked records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } ) if $bltdes->allows( 'READ' ) and $count > 0;
      $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "insert.svg", "[~Insert and link a new record into] <b>$linked_table_label</b>", ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field ) if $bltdes->allows( 'INSERT' );

      $count = 'Unknown' if $count eq '';

      $field_input = "<b class=hi>$count</b> records from <b class=hi>$linked_table_label</b>";

      my $details_fields = $bfdes->get_attr( qw( WEB EDIT DETAILS_FIELDS ) );
      if( $details_fields and $count > 0 )
        {
        my $backlink_text;

        my $sub_de_data_grid_cb = sub
          {
          my $id = shift;
          my $ccid = $reo->create_uniq_id();
          my $text;
          $text .= de_html_form_button_redirect( $reo, 'new', $edit_form, "view.svg", "[~View linked data]", ACTION => 'view', TABLE => $backlinked_table, ID => $id, );
          $text .= de_html_form_button_redirect( $reo, 'new', $edit_form, "edit.svg", "[~Edit linked data]", ACTION => 'edit', TABLE => $backlinked_table, ID => $id ) if $bltdes->allows( 'UPDATE' );
          return $text;
          };
      
        my $details_limit = $bfdes->get_attr( qw( WEB EDIT DETAILS_LIMIT ) ) || 16;
        $field_details .= "<p>" . de_data_grid( $core, $backlinked_table, $details_fields, { FILTER => { $backlinked_field => $id }, LIMIT => $details_limit, CLASS => 'grid view record', TITLE => "[~Related] $linked_table_label", CTRL_CB => $sub_de_data_grid_cb } ) ;

        my ( $insert_cue, $insert_cue_hint ) = de_web_get_cue( $bltdes->get_table_des(), qw( WEB GRID INSERT_CUE ) );
        $field_details .= de_html_form_button_redirect( $reo, 'new', $edit_form, "[~View all records]",  "[~View all backlinked records from] <b>$linked_table_label</b>",  BTYPE => 'nav', ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } ) if $bltdes->allows( 'READ' ) and $count > 0;
        $field_details .= de_html_form_button_redirect( $reo, 'new', $edit_form, $insert_cue, $insert_cue_hint, BTYPE => 'act', ACTION => 'edit', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, ID => -1, "F:$backlinked_field" => $id ) if $bltdes->allows( 'INSERT' );

        $backlink_text .= $field_details;
      
        push @backlinks_text, $backlink_text;
        next;
        }
      # EXPERIMENT: :)) $field_input .= "<p><div class=vframe><a reactor_new_href=?action=grid&table=$backlinked_table>show</a></div>";
      }
    elsif( $type_name eq 'WIDELINK' )
      {
      # TODO: nothing for now, could display view information as in action view
      next;
      }
    elsif( $type_name eq 'INT' and $fdes->{ 'BOOL' } )
      {
      $field_input .= $edit_form->checkbox_multi(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data,
                                       RET      => [ '0', '1' ],
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       LABELS   => [ "<img class='check-base check-0' src=i/check-0.svg>", "<img class='check-base check-1' src=i/check-1.svg>" ],
                                       );
      }
    elsif( $type_name eq 'INT' )
      {
      my $field_size = $flen < 32 ? $flen : 32;
      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => $field_size,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       );
      }
    elsif( $type_name eq 'REAL' )
      {
      my $field_size = $flen < 32 ? $flen : 32;
      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => $field_size,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       );
      }
    elsif( $type_name eq 'DATE' )
      {
      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => 32,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       );
      my $hl_handle = html_hover_layer( $reo, VALUE => "[~Set current date]", DELAY => 250 );
      my $date_format = type_get_format( $type );
      $field_input .= qq(<a class=plain href='#' onClick='set_value( "$field_id", current_date( "$date_format" ) ); return false;' ><img class=icon src=i/set-time.svg $hl_handle></a>);
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
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       );
      my $hl_handle = html_hover_layer( $reo, VALUE => "[~Set current time]", DELAY => 250 );
      $field_input .= qq(<a class=plain href='#' onClick='set_value( "$field_id", current_time() ); return false;' ><img class=icon src=i/set-time.svg $hl_handle></a>);
      }
    elsif( $type_name eq 'UTIME' )
      {
      $field_input .= $edit_form->input(
                                       NAME     => "F:$field",
                                       ID       => $field_id,
                                       VALUE    => $field_data_usr_format,
                                       SIZE     => 32,
                                       MAXLEN   => 64,
                                       DISABLED => $field_disabled,
                                       ARGS     => $input_tag_args,
                                       CLEAR    => $clear_icon,
                                       );
      my $hl_handle = html_hover_layer( $reo, VALUE => "[~Set current date+time]", DELAY => 250 );
      my $date_format = type_get_format( $type );
      $field_input .= qq(<a class=plain href='#' onClick='set_value( "$field_id", current_utime( "$date_format" ) ); return false;' ><img class=icon src=i/set-time.svg $hl_handle></a>);
      }
    else
      {
      $field_input = "(unknown)";
      }

    my $divider = $fdes->get_attr( 'WEB', 'DIVIDER' );
    if( $divider )
      {
      $text .= "<div class='$edit_mode_class_prefix-divider $edit_mode_class_prefix-sep record-sep fmt-center'>$divider</div>";
      $record_first = 1;
      }

    $field_error = "<div class=warning align=right>$field_error</div>" if $field_error;

    my $input_layout = html_layout_2lr( $field_input, '&nbsp;&nbsp;' . $field_input_ctrl, '<==1>' );
    my $base_field_class = lc "css_edit_class_$base_field";
    
#    $text .= "<tr class=view>\n";
#    $text .= "<td class='$edit_mode_class_prefix-field record-field $base_field_class'>$label$field_error</td>\n";
#    $text .= "<td class='$edit_mode_class_prefix-value record-value $base_field_class' >$input_layout</td>\n";
#    $text .= "</tr>\n";
    
    my $record_first_class = 'record-first' if $record_first;
    $record_first = 0;
    $text .= "<div class='record-field-value'>
                <div class='$edit_mode_class_prefix-field record-field $record_first_class $base_field_class' >$label$field_error</div>
                <div class='$edit_mode_class_prefix-value record-value $record_first_class $base_field_class' >$input_layout</div>
              </div>";


    if( $field_details )
      {
      $text .= "<div class='$edit_mode_class_prefix-details record-details'>$field_details</div>";

#      $text .= "<tr class=view>";
#      $text .= "<td colspan=2 class='details-fields' >$field_details</td>";
#      $text .= "</tr>\n";
      #$data_layout .= $field_details;
      }
    }
#  $text .= "</table>";
  $text .= "</div>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]", BTYPE => 'nav'   );

  if( $edit_mode_insert and exists $us->{ 'LAST_ROW_DATA' }{ $table } and ! $ps->{ 'ALREADY_USED_LAST_DATA' } )
    {
    $text .= de_html_alink_button( $reo, 'here', "&copy; [~Fill last used data]", "[~Fill last used data]", BTYPE => 'nav', USE_LAST_DATA => 1   );
    }

  if( $tdes->{ '@' }{ 'NO_PREVIEW' } )
    {
    $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, "[~OK] &rArr;", { HINT => "[~Save data]" }, BUTTON_ID => 'OK', ACTION => 'commit' );
    }
  else  
    {
    $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, "[~Preview] &rArr;", { HINT => "[~Preview data before save]" }, BUTTON_ID => 'PREVIEW', ACTION => 'preview' );
    }
  $text .= $edit_form->end();

  $text .= join '', @backlinks_text;

  return $text;
}

1;
