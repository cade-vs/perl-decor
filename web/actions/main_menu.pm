package decor::actions::main_menu;
use strict;
use Data::Dumper;

sub main
{
  my $reo = shift;
  
  return "<#menu_outside>" unless $reo->is_logged_in();

  my $core = $reo->de_connect();
  my $menu = $core->menu( 'MAIN' );

  my $text;


  $text .= "<table class=main-menu cellspacing=0 cellpadding=0 width=100%><tr>";
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
      $link = "<a class=main-menu reactor_new_href=?action=menu&menu=$key>$label</a>";
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=main-menu reactor_new_href=?action=grid&table=$table>$label</a>";
      }
    else
      {
      $reo->log( "error: main-menu: invalid item [$key] type [$type]" );
      next;
      }  

    $text .= "<td class=main-menu>$link</td>";
    }
  $text .= "<td class=main-menu-fill>&nbsp;</td><td class=main-menu><#main_menu_fill></td></tr></table>";
  
  print STDERR Dumper( $menu );
  return $text;
  return "MAIN MENU" . rand() . return "<#menu_inside_debug><xmp>" . Dumper( $menu ) . "</xmp>";
}

1;
