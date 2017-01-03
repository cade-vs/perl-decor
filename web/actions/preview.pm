package decor::actions::preview;
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

  my $table   = $reo->param( 'TABLE'   );
  my $id      = $reo->param( 'ID'      );

  return "<#e_data>" unless $table and $id;

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $ps = $reo->get_page_session();

  my $fields_ar        = $ps->{ 'FIELDS_WRITE_AR'  };
  my $edit_mode_insert = $ps->{ 'EDIT_MODE_INSERT' };

  boom "FIELDS list empty" unless @$fields_ar;

  my $text .= "<br>";
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
  $text .= "</tr>";

  my $row_data = $ps->{ 'ROW_DATA' };
  return "<#no_data>" unless $row_data;
  my $row_id = $row_data->{ '_ID' };

  for my $field ( @$fields_ar )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $field };
    my $bfdes     = $fdes; # keep sync code with view/grid, bfdes is begin/origin-field
    my $type_name = $fdes->{ 'TYPE'  }{ 'NAME' };
    my $label     = $fdes->get_attr( qw( WEB PREVIEW LABEL ) );
    
    my $data = $row_data->{ $field };
    my $data_fmt = de_web_format_field( $data, $fdes, 'PREVIEW' );

    if( $bfdes->is_backlinked() )
      {
      my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
      my $bltdes = $core->describe( $backlinked_table );
      my $linked_table_label = $bltdes->get_label();
      
      my $count = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } });
      $count = 'Unknown' if $count eq '';
      
      $data_fmt = qq( <b class=hi>$count</b> records from <b class=hi>$linked_table_label</b> );
      }

    $text .= "<tr class=view>";
    $text .= "<td class='view-field' >$label</td>";
    $text .= "<td class='view-value' >$data_fmt</td>";
    $text .= "</tr>";
    }
  $text .= "</table>";

  my $ok_hint = $edit_mode_insert ? "Confirm new record insert" : "Confirm record update";
  
  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "&lArr; [~Cancel]", "Cancel this operation"                        );
  $text .= de_html_alink_button( $reo, 'here', "&lArr; [~Back]",   "Back to data edit screen", ACTION => 'edit'   );
  $text .= de_html_alink_button( $reo, 'here', "[~OK] &radic;",     $ok_hint,                   ACTION => 'commit' );

  return $text;
}

1;
