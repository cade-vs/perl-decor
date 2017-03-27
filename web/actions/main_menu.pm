##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
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


  $text .= "<table class=main-menu cellspacing=0 cellpadding=0 width=100%><tr class=main-menu>";
  for my $key ( sort { $menu->{ $a }{ '_ORDER' } <=> $menu->{ $b }{ '_ORDER' } } keys %$menu )
    {
    next if $key eq '@';
    my $item = $menu->{ $key };
    next unless $item->{ 'GRANT' }{ 'ACCESS' } or $item->{ 'GRANT' }{ 'ALL' };
    next if     $item->{ 'DENY'  }{ 'ACCESS' } or $item->{ 'DENY'  }{ 'ALL' };

    my $label = $item->{ 'LABEL' } || $key;
    my $type  = $item->{ 'TYPE'  };
    
    my $link;
    if( $type eq 'SUBMENU' )
      {
      my $submenu_name = $item->{ 'SUBMENU_NAME'  };
      $link = "<a class=main-menu reactor_none_href=?action=menu&menu=$submenu_name>$label</a>";
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=main-menu reactor_none_href=?action=grid&table=$table>$label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_none_href=?action=edit&table=$table&id=-1>$label</a>";
      }
    else
      {
      $reo->log( "error: main-menu: invalid item [$key] type [$type]" );
      next;
      }  

    $text .= "<td class=main-menu>$link</td>";
    }
  $text .= "<td class=main-menu-fill>&nbsp;</td><td class=main-menu><#main_menu_fill></td></tr></table>";
  
  print STDERR Dumper( '+++', $menu, $text );
  return $text;
  return "MAIN MENU" . rand() . return "<#menu_inside_debug><xmp>" . Dumper( $menu ) . "</xmp>";
}

1;
