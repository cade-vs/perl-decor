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
use Exception::Sink;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::Utils;
use Decor::Web::View;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;

my $clear_icon = 'i/clear.svg';
my $clear_icon = 'x';

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table   = $reo->param( 'TABLE'   );
  my $id      = $reo->param( 'ID'      );
  my $copy_id = $reo->param( 'COPY_ID' );

  my $mode_insert = 1 if $id < 0;

  return "<#access_denied>" if $id == 0;

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();

  my $button    = $reo->get_input_button();
  my $button_id = $reo->get_input_button_id();

  # save extra args
  $reo->param( $_ ) for qw( LINK_TO_TABLE LINK_TO_FIELD LINK_TO_ID RETURN_DATA_FROM RETURN_DATA_TO );

  my $link_field_disable = $reo->param( 'LINK_FIELD_DISABLE' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

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

  if( $edit_mode_insert )
    {
    $reo->ps_path_add( 'insert', qq( "Insert new record into "<b>$table_label</b>" ) );
    }
  else
    {
    $reo->ps_path_add( 'edit', qq( "Edit record data from "<b>$table_label</b>" ) );
    }

#print STDERR Dumper( "error:", $fields_ar, $ps->{ 'ROW_DATA' }, 'insert', $edit_mode_insert, 'allow', $tdes->allows( 'UPDATE' ) );

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

    my $raw_input_data = type_revert( $input_data, $type );

    $ps->{ 'ROW_DATA' }{ $field } = $raw_input_data;
    
    }

  # recalc data
  #$fields_ar        = $ps->{ 'FIELDS_WRITE_AR' };
  #$edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  my $calc_in  = { map { $_ => $ps->{ 'ROW_DATA' }{ $_ } } @$fields_ar };
  my $calc_id  = $id unless $edit_mode_insert;
  my ( $calc_out, $calc_merrs )= $core->recalc( $table, $calc_in, $calc_id );
  if( $calc_out )
    {
    $ps->{ 'ROW_DATA' } = $calc_out;
    }
  else
    {
    return "<#e_internal>" . de_html_alink_button( $reo, 'back', "&lArr; [~Go back]", "[~Go back to the previous screen]"   );
    }

  for my $field ( @$fields_ar )
    {
    my $raw_data = $ps->{ 'ROW_DATA' }{ $field };
    my $fdes       = $tdes->{ 'FIELD' }{ $field };
    my $type       = $fdes->{ 'TYPE'  };
    next unless $fdes->{ 'REQUIRED' };
    my $type_name = $type->{ 'NAME' };
    next if $type_name eq 'CHAR' and $raw_data =~ /\S/;
    next if $type_name ne 'CHAR' and $raw_data != 0;
    
    $calc_merrs ||= {};
    push @{ $calc_merrs->{ $field } }, "[~This field is required]!";
    }

  if( ! ( ( $button_id eq 'PREVIEW' or $button_id eq 'OK' ) and $calc_merrs ) )
    {
    # handle redirects here
    de_web_handle_redirect_buttons( $reo );
    }

###  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  $text .= "<br>";

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

  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>[~Field]</td>";
  $text .= "<td class='view-header fmt-left' >[~Value]</td>";
  $text .= "</tr>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };

  for my $field ( @$fields_ar )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $bfdes     = $fdes; # keep sync code with view/preview/grid, bfdes is begin/origin-field
    my $type      = $fdes->{ 'TYPE'  };
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->{ 'LABEL' } || $field;

    next if $fdes->get_attr( 'WEB', 'HIDDEN' );

    my $field_data = $ps->{ 'ROW_DATA' }{ $field };
    my $field_data_usr_format = type_format( $field_data, $type );

    my $field_error;

    if( $button )
      {
      $field_error .= "$_<br>\n" for @{ $calc_merrs->{ $field } };
      }

    my $field_id = "F:$table:$field:" . $reo->html_new_id();

    my $field_input;
    my $field_input_ctrl;
    my $input_tag_args;
    my $field_disabled;

    if( $type_name eq 'CHAR' )
      {
      my $pass_type = 1 if $fdes->{ 'PASSWORD' } or $field =~ /^PWD_/;
      my $rows = $fdes->get_attr( 'WEB', 'ROWS' );
      my $field_size = $type->{ 'LEN' };
      my $field_maxlen = $field_size;
      $field_size = 42 if $field_size > 42; # TODO: fixme
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
      }
    elsif( $type_name eq 'LINK' )
      {
      my ( $linked_table, $linked_field ) = $fdes->link_details();
      my $ltdes = $core->describe( $linked_table );

      my $select_filter_name = $fdes->get_attr( 'WEB', 'SELECT_FILTER' );

      my $combo = $fdes->get_attr( qw( WEB COMBO ) );
      if( $combo )
        {
        my $spf_fmt;
        my @spf_fld;
        if( $combo == 1 )
          {
          $spf_fmt = "%s";
          @spf_fld = ( $linked_field );
          }
        else
          {
          my @v = split /\s*;\s*/, $combo;
          $spf_fmt = shift @v;
          @spf_fld = @v;
          }


        my $combo_data = [];
        my $sel_hr     = {};
        $sel_hr->{ $field_data } = 1 if $field_data > 0;

        my @lfields = @{ $ltdes->get_fields_list_by_oper( 'READ' ) };
        unshift @lfields, $linked_field;

##        return "<#access_denied>" unless @fields;

        my %bfdes; # base/begin/origin field descriptions, indexed by field path
        my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
        my %basef; # base fields map, return base field NAME by field path

        de_web_expand_resolve_fields_in_place( \@lfields, $ltdes, \%bfdes, \%lfdes, \%basef );

      #$text .= Dumper( \%basef );

        my $lfields = join ',', '_ID', @lfields, values %basef;

        my $combo_select = $core->select( $linked_table, $lfields, { 'FILTER_NAME' => $select_filter_name } );
#$text .= "my $combo_select = $core->select( $linked_table, $lfields )<br>";
        while( my $hr = $core->fetch( $combo_select ) )
          {
          my @value = map { $hr->{ $_ } } @spf_fld;
          my $value = sprintf( $spf_fmt, @value );

#$text .= "[$spf_fmt][@spf_fld][$value][@value]<br>";
          $value =~ s/\s/&nbsp;/g;
          push @$combo_data, { KEY => $hr->{ '_ID' }, VALUE => $value };
          }

        my $fmt_class;
        if( $fdes->get_attr( 'WEB', 'EDIT', 'MONO' ) )
          {
          $fmt_class .= " fmt-mono";
          }

        $field_input = $edit_form->combo( NAME => "F:$field", CLASS => $fmt_class, DATA => $combo_data, SELECTED => $sel_hr );
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
      
      if( $ltdes->get_table_type() eq 'FILE' )
        {
        if( $field_data > 0 )
          {
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "FILE_UPLOAD_REPLACE_$field_id", "file_up.svg", "[~Upload and replace current file]", ACTION => 'file_up', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'UPDATE' );
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "FILE_DOWNLOAD_$field_id",       "file_dn.svg", "[~Download current file]",           ACTION => 'file_dn', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'READ' );
          }
        else
          {
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "FILE_UPLOAD_NEW_$field_id", "file_new.svg", "[~Upload new file]", ACTION => 'file_up', TABLE => $linked_table, ID => -1, RETURN_DATA_TO => $field ) if $ltdes->allows( 'INSERT' );
          }
        }
      else
        {
        if( $field_data > 0 )
          {
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "VIEW_LINKED_$field_id", "view.svg", "[~View linked data]", ACTION => 'view', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'READ'   );
          $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "EDIT_LINKED_$field_id", "edit.svg", "[~Edit linked data]", ACTION => 'edit', TABLE => $linked_table, ID => $field_data ) if $ltdes->allows( 'UPDATE' );
          }
        my $insert_cue = $bfdes->get_attr( qw( WEB EDIT INSERT_CUE ) ) || "[~Insert and link a new record]";
        my $select_cue = $bfdes->get_attr( qw( WEB EDIT SELECT_CUE ) ) || "[~Select linked record]";
        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "INSERT_LINKED_$field_id", "insert.svg",      $insert_cue, ACTION => 'edit', TABLE => $linked_table, ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => $field ) if $ltdes->allows( 'INSERT' );
        $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "SELECT_LINKED_$field_id", "select-from.svg", $select_cue, ACTION => 'grid', TABLE => $linked_table, ID => -1, RETURN_DATA_FROM => '_ID', RETURN_DATA_TO => $field, GRID_MODE => 'SELECT', SELECT_KEY_DATA => $field_data, FILTER_NAME => $select_filter_name ) if $ltdes->allows( 'READ'   );
        }
      }
    elsif( $type_name eq 'BACKLINK' )
      {
      my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table );
      my $linked_table_label = $bltdes->get_label();

      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });

      $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "GRID_BACKLINKED_$field_id",   "grid.svg",   "[~View all backlinked records from] <b>$linked_table_label</b>",  ACTION => 'grid', TABLE => $backlinked_table, LINK_FIELD_DISABLE => $backlinked_field, LINK_FIELD_ID => $id, FILTER => { $backlinked_field => $id } ) if $bltdes->allows( 'READ' ) and $count > 0;
      $field_input_ctrl .= de_html_form_button_redirect( $reo, 'new', $edit_form, "INSERT_BACKLINKED_$field_id", "insert.svg", "[~Insert and link a new record into] <b>$linked_table_label</b>", ACTION => 'edit', ID => -1, TABLE => $backlinked_table, "F:$backlinked_field" => $id, LINK_FIELD_DISABLE => $backlinked_field ) if $bltdes->allows( 'INSERT' );

      $count = 'Unknown' if $count eq '';

      $field_input = "<b class=hi>$count</b> records from <b class=hi>$linked_table_label</b>";
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
                                       LABELS   => [ "<img class=check-0 src=i/check-0.svg>", "<img class=check-1 src=i/check-1.svg>" ],
                                       );
      }
    elsif( $type_name eq 'INT' )
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
      }
    elsif( $type_name eq 'REAL' )
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
      $field_input .= qq(<a href='#' onClick='set_value( "$field_id", current_date( "$date_format" ) ); return false;' ><img class=icon src=i/set-time.svg $hl_handle></a>);
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
      $field_input .= qq(<a href='#' onClick='set_value( "$field_id", current_time() ); return false;' ><img class=icon src=i/set-time.svg $hl_handle></a>);
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
      $field_input .= qq(<a href='#' onClick='set_value( "$field_id", current_utime( "$date_format" ) ); return false;' ><img class=icon src=i/set-time.svg $hl_handle></a>);
      }
    else
      {
      $field_input = "(unknown)";
      }

    $field_error = "<div class=warning align=right>$field_error</div>" if $field_error;

    my $input_layout = html_layout_2lr( $field_input, $field_input_ctrl, '<==1>' );
    $text .= "<tr class=view>\n";
    $text .= "<td class='view-field'>$label$field_error</td>\n";
    $text .= "<td class='view-value' >$input_layout</td>\n";
    $text .= "</tr>\n";
    }
  $text .= "</table>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "[~Cancel this operation]", BTYPE => 'nav'   );

  if( $tdes->{ '@' }{ 'NO_PREVIEW' } )
    {
    $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, 'OK', "[~OK] &rArr;", "[~Save data]", ACTION => 'commit' );
    }
  else  
    {
    $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, 'PREVIEW', "[~Preview] &rArr;", "[~Preview data before save]", ACTION => 'preview' );
    }
  $text .= $edit_form->end();

  return $text;
}

1;
