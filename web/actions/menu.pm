package decor::actions::menu;
use strict;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();
  
  my $name = $reo->param( 'MENU' );

  my $core = $reo->de_connect();
  my $menu = $core->menu( $name );

  my $text;

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
  
  print STDERR Dumper( $menu );
  return $text;
}

1;
