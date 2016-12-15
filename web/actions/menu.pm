package decor::actions::menu;
use strict;
use Data::Dumper;
use Web::Reactor::HTML::Utils;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();
  
  my $name = $reo->param( 'MENU' );

  my $core = $reo->de_connect();

  my $menu_ar = sub_menu( $reo, $core, $name );

  print STDERR Dumper( 'MENU 'x11, $menu_ar );

  my $text = html_ftree( $menu_ar, 'ARGS' => 'class=menu cellpadding=10 width=100% border=0', 'ARGS_TR' => 'class=menu', 'ARGS_TD' => 'class=menu' );
  
  return "<p>" . $text;
  
########

  my $menu = $core->menu( $name );

  my $text;

  $text .= "<table cellspacing=0 cellpadding=0 width=100%><tr><td align=center><table class=menu cellspacing=0 cellpadding=0 width=80%><tr>";
  for my $key ( keys %$menu )
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
      $link = "<a class=menu reactor_new_href=?action=menu&menu=$submenu_name>$label</a>";
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
  
  print STDERR Dumper( 'MENU 'x11, $menu );
  return $text;
}

sub sub_menu
{
  my $reo  = shift;
  my $core = shift;
  my $name = shift;

  my $menu = $core->menu( $name );

  my @res;
  
  for my $key ( keys %$menu )
    {
    next if $key eq '@';
    my $item = $menu->{ $key };
    next unless $item->{ 'GRANT' }{ 'ACCESS' } or $item->{ 'GRANT' }{ 'ALL' };
    next if     $item->{ 'DENY'  }{ 'ACCESS' } or $item->{ 'DENY'  }{ 'ALL' };

    my $label = $item->{ 'LABEL' } || $key;
    my $type  = $item->{ 'TYPE'  };
    
    if( $type eq 'SUBMENU' )
      {
      my $submenu_name = $item->{ 'SUBMENU_NAME'  };
      my $submenu = sub_menu( $reo, $core, $submenu_name );
      push @res, { LABEL => $key, DATA => $submenu };
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      push @res, "<a class=menu reactor_new_href=?action=grid&table=$table>$label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      push @res, "<a class=menu reactor_new_href=?action=edit&table=$table&id=-1>$label</a>";
      }
    else
      {
      $reo->log( "error: menu: invalid item [$key] type [$type]" );
      next;
      }  
    }

  return \@res;
}

1;
