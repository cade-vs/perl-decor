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
use Web::Reactor::HTML::Utils;

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

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );


  my $edit_mode_insert;
  my $fields_ar;

  if( ! $ps->{ 'INIT_DONE' } )
    {
    $ps->{ 'INIT_DONE' } = 1;
    if( $mode_insert )
      {
      # insert
      $edit_mode_insert = 1;

      $fields_ar = $tdes->get_fields_list_by_oper( 'INSERT' );
      if( $copy_id )
        {
        # insert with copy
        }
      else
        {
        # regular insert
        
        # exec default method
        
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
    }
  else
    {
    $fields_ar = $ps->{ 'FIELDS_WRITE_AR' };
    $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };
    }  

  boom "FIELDS list empty" unless @$fields_ar;

  my $fields = join ',', @$fields_ar;

  my %ui_si = ( %$ui, %$si ); # merge inputs, SAFE_INPUT has priority
  # input data
  for my $field ( @$fields_ar )
    {
    next unless exists $ui_si{ "F:$field" };
    my $input_data = $ui_si{ "F:$field" };
    $ps->{ 'ROW_DATA' }{ $field } = $input_data;
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
    
  for my $f ( @$fields_ar )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $f };
    my $type      = $fdes->{ 'TYPE'  };
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->{ 'LABEL' } || $f;
    
    my $field_data = $ps->{ 'ROW_DATA' }{ $f };
    my $field_data_usr_format = type_format( $field_data, $type );

    my $field_id = "F:$table:$f:" . $reo->html_new_id();

    my $field_input;
    my $input_tag_args;
    my $field_disabled;
    
    if( $type_name eq 'CHAR' )
      {
      my $pass_type = 1 if $fdes->{ 'OPTIONS' }{ 'PWD' } or $f =~ /^PWD_/;
      my $field_size = $type->{ 'LEN' };
      my $field_maxlen = $field_size;
      $field_size = 42 if $field_size > 42; # TODO: fixme
      $field_input .= $edit_form->input( 
                                       NAME     => "F:$f", 
                                       ID       => $field_id, 
                                       PASS     => $pass_type, 
                                       VALUE    => $field_data_usr_format, 
                                       SIZE     => $field_size, 
                                       MAXLEN   => $field_maxlen, 
                                       DISABLED => $field_disabled, 
                                       ARGS     => $input_tag_args, 
                                       );
      }
    elsif( $type_name eq 'INT' )
      {
      }

    $text .= "<tr class=view>\n";
    $text .= "<td class='view-field'>$label</td>\n";
    $text .= "<td class='view-value' >$field_input</td>\n";
    $text .= "</tr>\n";
    }
  $text .= "</table>";

  $text .= "<br>";
  $text .= $edit_form->button( NAME => "REDIRECT:PREVIEW", VALUE => "[~Preview]" );
  $text .= $edit_form->end();
  $text .= de_html_alink_button( $reo, 'back', "Back", "Return to previous screen" );

  return $text;
}

1;
