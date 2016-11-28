package decor::actions::grid;
use strict;
use Web::Reactor::HTML::Utils;
use Decor::Web::HTML::Utils;
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

#  print STDERR Dumper( $tdes );

  my $page_size  = 15;
  $offset = 0 if $offset < 0;
  
  my @fields = @{ $tdes->get_fields_list_by_oper( 'READ' ) };
  my $fields = join ',', @fields;
  
  my $select = $core->select( $table, $fields, { OFFSET => $offset, LIMIT => $page_size, ORDER_BY => '_ID DESC' } );

  my $text .= "<br>";
  
  $text .= "<table class=grid cellspacing=0 cellpadding=0>";
  $text .= "<tr class=grid-header>";
  $text .= "<td class='grid-header fmt-left'>Ctrl</td>";
  
  for my $f ( @fields )
    {
    my $fdes      = $tdes->{ 'FIELD' }{ $f };
    my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };
    my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';
    my $label     = $fdes->{ 'WEB.GRID.LABEL' } || $fdes->{ 'LABEL' };

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
    
    $vec_ctrl .= de_html_alink_icon( $reo, 'new', "view.png", 'View this record', ACTION => 'view', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink_icon( $reo, 'new', "edit.png", 'Edit this record', ACTION => 'edit', ID => $id, TABLE => $table );
    $vec_ctrl .= de_html_alink_icon( $reo, 'new', "copy.png", 'Copy this record', ACTION => 'edit', ID =>  -1, TABLE => $table, COPY_ID => $id );
    
    $text .= "<td class='grid-data fmt-ctrl'>$vec_ctrl</td>";
    for my $f ( @fields )
      {
      my $fdes      = $tdes->{ 'FIELD' }{ $f };
      my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };
      my $fmt_class = $FMT_CLASSES{ $type_name } || 'fmt-left';
      
      my $data = $row_data->{ $f };
      my $data_format = $data;
      
      if( $type_name eq 'CHAR' )
        {
        my $maxlen = $fdes->{ 'WEB.GRID.MAXLEN' } || $fdes->{ 'WEB.MAXLEN' };
        if( $maxlen )
          {
          $maxlen = 16 if $maxlen <   0;
          $maxlen = 16 if $maxlen > 256;
          if( length( $data ) > $maxlen )
            {
            my $cut_len = int( ( $maxlen - 3 ) / 2 );
            $data_format = substr( $data, 0, $cut_len ) . ' ... ' . substr( $data, - $cut_len );
            }
          }
        my $mono = $fdes->{ 'WEB.GRID.MONO' } || $fdes->{ 'WEB.MONO' };
        if( $mono )
          {
          $fmt_class .= " fmt-mono";
          }
        }
      
      $text .= "<td class='grid-data $fmt_class'>$data_format</td>";
      }
    $text .= "</tr>";
    }
  $text .= "</table>";

  my $offset_prev = $offset - $page_size;
  my $offset_next = $offset + $page_size;
  $text .= "<a reactor_here_href=?offset=$offset_prev><img src=i/page-prev.png> previous page</a> | <a reactor_here_href=?offset=$offset_next>next page <img src=i/page-next.png> </a>";

=pod
  $text .= "<table cellspacing=0 cellpadding=0 width=100%><tr><td align=center><table class=menu cellspacing=0 cellpadding=0 width=80%><tr>";
  for my $key ( keys %$menu )
    {
    next if $key eq '@';
    my $item = $menu->{ $key };
    next unless $item->{ 'GRANT' }{ 'ACCESS' };
    next if     $item->{ 'DENY'  }{ 'ACCESS' };

    my $label = $item->{ 'LABEL' } || $key;
    my $type  = $item->{ 'TYPE'  };
    
    my $link;
    if( $type eq 'SUBMENU' )
      {
      $link = "<a class=menu reactor_new_href=?action=menu&menu=$key>$label</a>";
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_new_href=?action=grid&table=$table>$label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_new_href=?action=edit&table=$table&id=-1>$label</a>";
      }
    else
      {
      $reo->log( "error: menu: invalid item [$key] type [$type]" );
      next;
      }  

    $text .= "<tr><td class=menu>$link</td></tr>";
    }
  $text .= "</table></td></tr></table>";
=cut  
  return $text;
}

1;
