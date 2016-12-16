package decor::actions::commit;
use strict;
use Data::Dumper;
use Exception::Sink;

use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();
  
  my $text;

  # FIXME: invalidate session first!!!
  my $ps = $reo->get_page_session();

  my $table   = $ps->{ 'TABLE'   };
  my $id      = $ps->{ 'ID'      };

  return "<#e_data>" unless $table and $id;

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );


  my $fields_ar        = $ps->{ 'FIELDS_WRITE_AR'  };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  boom "FIELDS list empty" unless @$fields_ar;

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;

  my $res;
  if( $edit_mode_insert )
    {
    my $opt = {};
    
    my $lt_table = $reo->param( 'LINK_TO_TABLE' );
    my $lt_field = $reo->param( 'LINK_TO_FIELD' );
    my $lt_id    = $reo->param( 'LINK_TO_ID'    );
    
    if( $lt_table and $lt_field and $lt_id )
      {
      $opt->{ 'LINK_TO_TABLE' } = $lt_table;
      $opt->{ 'LINK_TO_FIELD' } = $lt_field;
      $opt->{ 'LINK_TO_ID'    } = $lt_id;
      }
    
    $res = $core->insert( $table, $row_data, $id, $opt );
    }
  else
    {
    $res = $core->update( $table, $row_data, { ID => $id } );
    }  

  my $res_msg = $res ? "OK" : "Error";

  my $text .= "<br>";
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
  $text .= "</tr>";

  $text .= "<tr class=view>";
  $text .= "<td class='view-field' >Operation result</td>";
  $text .= "<td class='view-value' >$res_msg</td>";
  $text .= "</tr>";

  $text .= "</table>";

#  my $ok_hint = $edit_mode_insert ? "Confirm new record insert" : "Confirm record update";
  
  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'here', "&lArr; [~Back]",     "Back to data edit screen", ACTION => 'edit'   );
  $text .= de_html_alink_button( $reo, 'back', "[~Continue] &crarr;", "Operation done, continue..."              );
#  $text .= de_html_alink_button( $reo, 'new',  "OK",     $ok_hint,                   ACTION => 'commit' );

  return $text;
}

1;
