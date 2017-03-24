##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
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
}

sub sub_menu
{
  my $reo  = shift;
  my $core = shift;
  my $name = shift;

  my $menu = $core->menu( $name );

  my @res;

  for my $key ( sort { $menu->{ $a }{ '_ORDER' } <=> $menu->{ $b }{ '_ORDER' } } keys %$menu )
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
      push @res, { LABEL => "<img src=i/menu-item-submenu.svg> $label", DATA => $submenu };
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      push @res, "<a class=menu reactor_none_href=?action=grid&table=$table><img src=i/menu-item-grid.svg> $label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      push @res, "<a class=menu reactor_none_href=?action=edit&table=$table&id=-1><img src=i/menu-item-insert.svg> $label</a>";
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
