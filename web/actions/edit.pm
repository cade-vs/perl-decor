package decor::actions::edit;
use strict;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Data::Dumper;

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

  my $ps = $reo->get_page_session();

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my @fields = @{ $des->get_fields_list_by_oper( 'READ' ) };
  my $fields = join ',', @fields;

  if( ! $ps->{ 'INIT_DONE' } )
    {
    $ps->{ 'INIT_DONE' } = 1;
    if( $mode_insert )
      {
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
      my $row_data = $core->select_first1_by_id( $table, $fields, $id );
      $ps->{ 'ROW_DATA' } = $row_data;
      }  
    }

  
###  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  my $text .= "<br>";

  my $edit_form = new Web::Reactor::HTML::Form( REO_REACTOR => $reo );
  my $edit_form_begin;
  $edit_form_begin .= $edit_form->begin( NAME => "form_edit_$table", DEFAULT_BUTTON => 'PREVIEW' );
  $edit_form_begin .= $edit_form->input( NAME => "ACTION", RETURN => "edit", HIDDEN => 1 );
  my $form_id = $edit_form->get_id();
  $edit_form_begin .= "<p>";
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
  $text .= "</tr>";

###  my $row_data = $core->fetch( $select );
###  my $row_id = $row_data->{ '_ID' };
    
  for my $f ( @fields )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $f };
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->{ 'LABEL' } || $f;
    
    my $data = $ps->{ 'ROW_DATA' }{ $f };

    $text .= "<tr class=view>";
    $text .= "<td class='view-field'>$label</td>";
    $text .= "<td class='view-value' >$data</td>";
    $text .= "</tr>";
    }
  $text .= "</table>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "Back", "Return to previous screen" );

  return $text;
}

1;
