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

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );

  my $core = $reo->de_connect();
  my $des  = $core->describe( $table );

  my @fields = @{ $des->get_fields_list_by_oper( 'READ' ) };
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
    my $type_name = $des->{ 'FIELD' }{ $f }{ 'TYPE' }{ 'NAME' };
    my $label     = $des->{ 'FIELD' }{ $f }{ 'LABEL' } || $f;
    
    my $data = $row_data->{ $f };

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
