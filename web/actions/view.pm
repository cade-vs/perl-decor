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
  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };

#  push @fields, 'USR.ACTIVE';

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

#$text .= Dumper( \%basef );

  my $fields = join ',', @fields, values %basef;
  
  my $select = $core->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } );

  my $text .= "<br>";
  
  $text .= "<table class=view cellspacing=0 cellpadding=0>";
  $text .= "<tr class=view-header>";
  $text .= "<td class='view-header fmt-right'>Field</td>";
  $text .= "<td class='view-header fmt-left' >Value</td>";
  $text .= "</tr>";

  my $row_data = $core->fetch( $select );
  return "<#no_data>" unless $row_data;
  my $row_id = $row_data->{ '_ID' };

  for my $field ( @fields )
    {
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
    my $blabel    = $bfdes->get_attr( qw( WEB VIEW LABEL ) );

    my $label = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = $lfdes->get_attr( qw( WEB VIEW LABEL ) );
      $label .= "/$llabel";
      }
    
    my $data      = $row_data->{ $field };
    my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };
    my $data_fmt  = de_web_format_field( $data, $lfdes, 'VIEW' );

    my $overflow  = $bfdes->get_attr( qw( WEB VIEW OVERFLOW ) );
    if( $overflow )
      {
      $data_fmt =~ s/'/&#39;/g; # FIXME: move to func
      $data_fmt = "<form><input value='$data_fmt' style='width: 96%' readonly></form>";
      }

    if( $bfdes->is_linked() )
      {
      my ( $linked_table, $linked_field ) = $bfdes->link_details();
      $data_fmt = de_html_alink_button( $reo, 'new', $data_fmt, "View linked record", ACTION => 'view', ID => $data_base, TABLE => $linked_table );
      }
    elsif( $bfdes->is_backlinked() )
      {
      }

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
