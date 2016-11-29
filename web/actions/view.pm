package decor::actions::view;
use strict;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();
  
  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };
  my $fields = join ',', @fields;
  
  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  my $text .= "<br>";
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
  $text .= "</tr>";

  my $row_data = $core->fetch( $select );
  my $row_id = $row_data->{ '_ID' };
    
  for my $f ( @fields )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $f };
    my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };
    my $label     = $fdes->get_attr( qw( WEB VIEW LABEL ) );
    
    my $data = $row_data->{ $f };
    my $data_fmt = de_web_format_field( $data, $fdes, 'VIEW' );

    $text .= "<tr class=view>";
    $text .= "<td class='view-field' >$label</td>";
    $text .= "<td class='view-value' >$data_fmt</td>";
    $text .= "</tr>";
    }
  $text .= "</table>";

  $text .= "<br>";
  $text .= de_html_alink_button( $reo, 'back', "Back", "Return to previous screen" );
  $text .= de_html_alink_button( $reo, 'new',  "Edit", "Edit this record", ACTION => 'edit', ID => $id, TABLE => $table );

  return $text;
}

1;
