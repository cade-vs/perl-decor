##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
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
use Web::Reactor::HTML::Utils;

my $clear_icon = 'i/clear.png';
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

  # save extra args
  $reo->param( 'LINK_TO_TABLE' );
  $reo->param( 'LINK_TO_FIELD' );
  $reo->param( 'LINK_TO_ID'    );

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
        $ps->{ 'ROW_DATA' } = { _ID => $id };
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

  boom "FIELDS list empty" unless @$fields_ar;

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

  # handle redirects here
  de_web_handle_redirect_buttons( $reo );

  # recalc data
  #$fields_ar        = $ps->{ 'FIELDS_WRITE_AR' };
  #$edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };
  
  my $calc_in  = { map { $_ => $ps->{ 'ROW_DATA' }{ $_ } } @$fields_ar };
  my $calc_id  = $id unless $edit_mode_insert;
  my $calc_out = $core->recalc( $table, $calc_in, $calc_id );
  if( $calc_out )
    {
    $ps->{ 'ROW_DATA' } = $calc_out;
    }
  else
    {
    return "<#e_internal>";
    }  
  

###  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  $text .= "<br>";

  my $edit_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $edit_form_begin;
  $edit_form_begin .= $edit_form->begin( NAME => "form_edit_$table", DEFAULT_BUTTON => 'PREVIEW' );
  $edit_form_begin .= $edit_form->input( NAME => "ACTION", RETURN => "edit", HIDDEN => 1 );
  my $form_id = $edit_form->get_id();
  $edit_form_begin .= "<p>";

  $text .= $edit_form_begin;
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
  $text .= "</tr>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };
    
  for my $field ( @$fields_ar )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $type      = $fdes->{ 'TYPE'  };
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->{ 'LABEL' } || $field;
    
    my $field_data = $ps->{ 'ROW_DATA' }{ $field };
    my $field_data_usr_format = type_format( $field_data, $type );

    my $field_id = "F:$table:$field:" . $reo->html_new_id();

    my $field_input;
    my $input_tag_args;
    my $field_disabled;
    
    if( $type_name eq 'CHAR' )
      {
      my $pass_type = 1 if $fdes->{ 'OPTIONS' }{ 'PWD' } or $field =~ /^PWD_/;
      my $field_size = $type->{ 'LEN' };
      my $field_maxlen = $field_size;
      $field_size = 42 if $field_size > 42; # TODO: fixme
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
    elsif( $type_name eq 'INT' and $fdes->{ 'BOOL' } )
      {
      $field_input .= $edit_form->checkbox( 
                                       NAME     => "F:$field", 
                                       ID       => $field_id, 
                                       VALUE => $field_data, 
                                       RET   => [ '0', '1' ], 
                                       ARGS     => $input_tag_args, 
                                       CLEAR    => $clear_icon,
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
      my $hl_handle = html_hover_layer( $reo, VALUE => "Set current date", DELAY => 250 );
      my $date_format = type_get_format( $type );
      $field_input .= qq(<a href='#' onClick='set_value( "$field_id", current_date( "$date_format" ) ); return false;' ><img class=icon src=i/set-time.png $hl_handle></a>);
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
      my $hl_handle = html_hover_layer( $reo, VALUE => "Set current time", DELAY => 250 );
      $field_input .= qq(<a href='#' onClick='set_value( "$field_id", current_time() ); return false;' ><img class=icon src=i/set-time.png $hl_handle></a>);
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
      my $hl_handle = html_hover_layer( $reo, VALUE => "Set current date+time", DELAY => 250 );
      my $date_format = type_get_format( $type );
      $field_input .= qq(<a href='#' onClick='set_value( "$field_id", current_utime( "$date_format" ) ); return false;' ><img class=icon src=i/set-time.png $hl_handle></a>);
      }
    else
      {
      $field_input = "(unknown)";
      }  

    $text .= "<tr class=view>\n";
    $text .= "<td class='view-field'>$label</td>\n";
    $text .= "<td class='view-value' >$field_input</td>\n";
    $text .= "</tr>\n";
    }
  $text .= "</table>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; Cancel", "Cancel this operation"   );
  $text .= de_html_form_button_redirect( $reo, 'here', $edit_form, 'PREVIEW', "[~Preview] &rArr;", "Preview data before save", ACTION => 'preview' );
  $text .= $edit_form->end();

  return $text;
}

1;
