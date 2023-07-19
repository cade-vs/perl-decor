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

###  return unless $reo->is_logged_in();

  my $name = $reo->param( 'MENU' );

  my $core = $reo->de_connect();

  my $menu_ar = sub_menu( $reo, $core, $name );

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

#print STDERR Dumper( '****************************** MENU MENU MENU MENU MENU MENU',  $menu );

  for my $key ( sort { $menu->{ $a }{ '_ORDER' } <=> $menu->{ $b }{ '_ORDER' } } keys %$menu )
    {
    next if $key eq '@';
    my $item = $menu->{ $key };

    next unless $item->{ 'GRANT' }{ 'ACCESS' } or $item->{ 'GRANT' }{ 'ALL' };
    next if     $item->{ 'DENY'  }{ 'ACCESS' } or $item->{ 'DENY'  }{ 'ALL' };

#print STDERR Dumper( $item );

    my $label = $item->{ 'LABEL' } || $key;
    my $type  = $item->{ 'TYPE'  };

    my $confirm = $item->{ 'CONFIRM' };
    my $menu_args;
    $confirm = "[~Are you sure?]" if $confirm == 1;
    $menu_args .= '  ' . qq( onclick="return confirm('$confirm');" ) if $confirm =~ /^([^"']+)$/;

    if( $type eq 'SUBMENU' )
      {
      my $submenu_name = $item->{ 'SUBMENU_NAME'  };
      my $submenu = sub_menu( $reo, $core, $submenu_name );
      push @res, { LABEL => "<img src=i/menu-item-submenu.svg class=icon> $label", DATA => $submenu };
      }
    elsif( $type eq 'GRID' )
      {
      my $table  = $item->{ 'TABLE'  };
      my $filter_name   = $item->{ 'FILTER_NAME'   };
      my $filter_method = $item->{ 'FILTER_METHOD' };
      my $order_by      = $item->{ 'ORDER_BY'      };
      my $href = $reo->args_type( 
                                  'none', 
                                  ACTION        => 'grid',
                                  TABLE         => $table,
                                  FILTER_NAME   => $filter_name,
                                  FILTER_METHOD => $filter_method,
                                  ORDER_BY      => $order_by,
                                );
      push @res, "<a class=menu href=?_=$href $menu_args><img src=i/menu-item-grid.svg class=icon> $label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      push @res, "<a class=menu reactor_none_href=?action=edit&table=$table&id=-1 $menu_args><img src=i/menu-item-insert.svg class=icon> $label</a>";
      }
    elsif( $type eq 'DO' )
      {
      my $table  = $item->{ 'TABLE'  };
      my $do     = $item->{ 'DO'     };
      push @res, "<a class=menu reactor_none_href=?action=do&table=$table&do=$do $menu_args><img src=i/menu-item-do.svg class=icon> $label</a>";
      }
    elsif( $type eq 'URL' )
      {
      my $url  = $item->{ 'URL'  };
      push @res, "<a class=menu target=_blank href=$url $menu_args><img src=i/menu-item-url.svg class=icon> $label</a>";
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
