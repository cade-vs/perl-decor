package decor::actions::grid;
use strict;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

my %FMT_CLASSES = (
                  'CHAR'  => 'fmt-left',
                  'DATE'  => 'fmt-left',
                  'TIME'  => 'fmt-left',
                  'UTIME' => 'fmt-left',

                  'INT'   => 'fmt-right fmt-mono',
                  'REAL'  => 'fmt-right fmt-mono',
                  );

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $offset = $reo->param( 'OFFSET' );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $table_label = $tdes->get_label();

  $reo->ps_path_add( 'grid.png', qq( List data from "<b>$table_label</b>" ) );

  return "<#e_internal>" unless $tdes;

#  print STDERR Dumper( $tdes );

  my $page_size  = 15;
  $offset = 0 if $offset < 0;
  
  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };

### testing
#push @fields, 'USR.ACTIVE';

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  my $fields = join ',', @fields, values %basef;
  
  my $select = $core->select( $table, $fields, { OFFSET => $offset, LIMIT => $page_size, ORDER_BY => '_ID DESC' } );

  $text .= "<br>";

  $text .= de_html_alink( $reo, 'new', "insert.png Insert new record", 'Insert new record', ACTION => 'edit', ID => -1, TABLE => $table );
  $text .= "<p>";
  
  $text .= "<table class=grid cellspacing=0 cellpadding=0>";
  $text .= "<tr class=grid-header>";
  $text .= "<td class='grid-header fmt-left'>Ctrl</td>";
  
  for my $field ( @fields )
    {
    my $bfdes     = $bfdes{ $field };
    my $lfdes     = $lfdes{ $field };
    my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
    my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';
    my $blabel    = $bfdes->get_attr( qw( WEB GRID LABEL ) );
    my $label = "$blabel";
    if( $bfdes ne $lfdes )
      {
      my $llabel     = $lfdes->get_attr( qw( WEB GRID LABEL ) );
      $label .= "/$llabel";
      }

    $text .= "<td class='grid-header $fmt_class'>$label</td>";
    }
  $text .= "</tr>";
  my $row_counter;
  while( my $row_data = $core->fetch( $select ) )
    {
    my $id = $row_data->{ '_ID' };
    
    my $row_class = $row_counter++ % 2 ? 'grid-1' : 'grid-2';
    $text .= "<tr class=$row_class>";
    
    my $vec_ctrl;
    
    $vec_ctrl .= de_html_alink( $reo, 'new', "view.png", 'View this record', ACTION => 'view', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink( $reo, 'new', "edit.png", 'Edit this record', ACTION => 'edit', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink( $reo, 'new', "copy.png", 'Copy this record', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id );
    
    $text .= "<td class='grid-data fmt-ctrl'>$vec_ctrl</td>";
    for my $field ( @fields )
      {
      my $bfdes     = $bfdes{ $field };
      my $lfdes     = $lfdes{ $field };
      my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };
      my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';

      my $lpassword = $lfdes->get_attr( 'PASSWORD' ) ? 1 : 0;

      my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

      my $data = $row_data->{ $field };
      my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };
      
      my ( $data_fmt, $fmt_class ) = de_web_format_field( $data, $lfdes, 'GRID' );
      my $data_ctrl;

      if( $bfdes->is_linked() )
        {
        my ( $linked_table, $linked_field ) = $bfdes->link_details();
        my $ltdes = $core->describe( $linked_table );
        if( $data_base > 0 )
          {
          $data_fmt   = de_html_alink( $reo, 'new', $data_fmt,                       "View linked record", ACTION => 'view', ID => $data_base, TABLE => $linked_table );
          }
        else
          {
          $data_fmt   = "(empty)";
          }  
        $data_ctrl .= de_html_alink( $reo, 'new', 'view.png View linked record',   undef,                ACTION => 'view', ID => $data_base, TABLE => $linked_table );
        $data_ctrl .= "<br>\n";
        if( $ltdes->allows( 'UPDATE' ) and $data_base > 0 )
          {
          # FIXME: check for record access too!
          $data_ctrl .= de_html_alink( $reo, 'new', 'edit.png Edit linked record', undef, ACTION => 'edit', ID => $data_base, TABLE => $linked_table );
          $data_ctrl .= "<br>\n";
          }
        if( $ltdes->allows( 'INSERT' ) and $tdes->allows( 'UPDATE' ) and $bfdes->allows( 'UPDATE' ) )
          {
          # FIXME: check for record access too!
          $data_ctrl .= de_html_alink( $reo, 'new', 'insert.png Insert and link a new record', undef, ACTION => 'edit', ID => -1,         TABLE => $linked_table, LINK_TO_TABLE => $table, LINK_TO_FIELD => $base_field, LINK_TO_ID => $id );
          $data_ctrl .= "<br>\n";
          }
        }
      elsif( $bfdes->is_backlinked() )
        {
        my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
        $data_ctrl .= de_html_alink_icon( $reo, 'new', 'insert.png', "Insert and link a new record", ACTION => 'edit', ID => -1, TABLE => $backlinked_table );
        }

      if( $lpassword )
        {
        $data_fmt = "(hidden)";
        }

      if( $data_ctrl )
        {
        $data_ctrl = de_html_popup_icon( $reo, 'more.png', $data_ctrl );
        $data_fmt = "<table cellspacing=0 cellpadding=0 width=100%><tr><td align=left>$data_fmt</td><td align=right>&nbsp;$data_ctrl</td></tr></table>";
        }
      
      $text .= "<td class='grid-data $fmt_class'>$data_fmt</td>";
      }
    $text .= "</tr>";
    }
  $text .= "</table>";

  my $offset_prev = $offset - $page_size;
  my $offset_next = $offset + $page_size;
  $text .= "<a reactor_here_href=?offset=$offset_prev><img src=i/page-prev.png> previous page</a> | <a reactor_here_href=?offset=$offset_next>next page <img src=i/page-next.png> </a>";

  return $text;
}

1;
