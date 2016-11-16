package decor::actions::view;
use strict;
use Web::Reactor::HTML::Utils;
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

  $text .= html_alink( $reo, 'back', "Back", { HINT => "Return to previous screen" } );
  $text .= html_alink( $reo, 'new',  "Edit", { HINT => "Edit this record" } );

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
