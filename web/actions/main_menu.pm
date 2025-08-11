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
use Web::Reactor::HTML::Utils;
use Data::Dumper;

sub main
{
  my $reo = shift;

#  return "<#menu_outside>" unless $reo->is_logged_in();

  my $core = $reo->de_connect();
  my $menu = $core->menu( 'MAIN' );

#print STDERR Dumper( 'MAIN MENU 'x10, $menu );

  my $text;
  
  my @left;
  my @right;

  for my $key ( sort { $menu->{ $a }{ '_ORDER' } <=> $menu->{ $b }{ '_ORDER' } } keys %$menu )
    {
    next if $key eq '@';
    my $item = $menu->{ $key };

    next unless $item->{ 'GRANT' }{ 'ACCESS' } or $item->{ 'GRANT' }{ 'ALL' };
    next if     $item->{ 'DENY'  }{ 'ACCESS' } or $item->{ 'DENY'  }{ 'ALL' };

    my $label = $item->{ 'LABEL' } || $key;
    my $type  = $item->{ 'TYPE'  };

    $label = "<&user_info><#page_expire_hint>" if lc $label eq '!username';

    my $link;
    if( $type eq 'SUBMENU' )
      {
      my $submenu_name = $item->{ 'SUBMENU_NAME'  };
#      $link = "<a class=main-menu reactor_none_href=?action=menu&menu=$submenu_name>$label</a>";
      if( $submenu_name =~ /^_DE_/ )
        {
        $link = "<a class=main-menu reactor_none_href=?action=menu&menu=$submenu_name>= $label</a>";
        }
      else
        {  
        $link = "<a class=main-menu reactor_none_href=?action=menu&menu=$submenu_name>$label</a>";
        my $menu_ar = sub_menu( $reo, $core, $submenu_name );
        my $menu_item_text   = html_ftree( $menu_ar, 'ARGS' => 'class=menu cellpadding=0 width=100% border=0', 'ARGS_TR' => 'class=menu', 'ARGS_TD' => 'class=menu menu-popup' );
        my $menu_item_handle = html_popup_layer( $reo, VALUE => $menu_item_text, CLASS => 'popup-layer popup-layer-inline', TYPE => 'CLICK', TIMEOUT => 1000, SINGLE => 1 );
        $link = "<a class=main-menu reactor_none_href=?action=menu&menu=$submenu_name $menu_item_handle>+ $label</a>";
        }
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
      $link = "<a class=main-menu href=?_=$href>$label</a>";
      }
    elsif( $type eq 'INSERT' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_none_href=?action=edit&table=$table&id=-1>$label</a>";
      }
    elsif( $type eq 'EDIT' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_none_href=?action=edit&table=$table&id=0>$label</a>";
      }
    elsif( $type eq 'VIEW' )
      {
      my $table  = $item->{ 'TABLE'  };
      $link = "<a class=menu reactor_none_href=?action=view&table=$table>$label</a>";
      }
    elsif( $type eq 'URL' )
      {
      my $url  = $item->{ 'URL'  };
      $link = "<a class=menu target=_blank href=$url>$label</a>";
      }
    elsif( $type eq 'DO' )
      {
      my $table  = $item->{ 'TABLE'  };
      my $do     = $item->{ 'DO'     };
      $link = "<a class=menu reactor_none_href=?action=do&table=$table&do=$do>$label</a>";
      }
    elsif( $type eq 'ACTION' )
      {
      my $action  = $item->{ 'ACTION'  };
      #### DOES NOT WORK WITH ANON SESSIONS: next if $reo->is_logged_in() and uc $action =~ /(\[~)?LOGIN(\])?/; # root hack
      $link = "<a class=menu reactor_new_href=?action=$action>$label</a>";
      }
    else
      {
      $reo->log( "error: main-menu: invalid item [$key] type [$type]" );
      next;
      }  

    my $confirm = $item->{ 'CONFIRM' };
    my $menu_args;
    $confirm = "[~Are you sure?]" if $confirm == 1;
    $menu_args .= '  ' . qq( onclick="return confirm('$confirm');" ) if $confirm =~ /^([^"']+)$/;

    if( $item->{ 'RIGHT' } )
      {
      unshift @right, "<td class=main-menu $menu_args>$link</td>";
      }
    else
      {
      push    @left,  "<td class=main-menu $menu_args>$link</td>";   
      }
    }


  $text .= "<table class=main-menu cellspacing=0 cellpadding=0 width=100%><tr class=main-menu>";
  $text .= join( '', @left ) . "<td class=main-menu-fill>&nbsp;</td>" . join( '', @right );
  $text .= "</tr></table>";

#print STDERR Dumper( 'MAIN MENU 'x10, $text );
  return $text;
}

sub sub_menu
{
  my $reo  = shift;
  my $core = shift;
  my $name = shift;

  my $menu = $core->menu( $name );

  my @res;

#print STDERR Dumper( $menu );

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
    elsif( $type eq 'EDIT' )
      {
      my $table  = $item->{ 'TABLE'  };
      push @res, "<a class=menu reactor_none_href=?action=edit&table=$table&id=0 $menu_args><img src=i/menu-item-insert.svg class=icon> $label</a>";
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
    elsif( $type eq 'ACTION' )
      {
      my $action  = $item->{ 'ACTION'  };
      my $icon    = $item->{ 'ICON'    }; # FIXME: check icon name
      #### DOES NOT WORK WITH ANON SESSIONS: next if $reo->is_logged_in() and uc $action =~ /(\[~)?LOGIN(\])?/; # root hack
      push @res, "<a class=menu reactor_new_href=?action=$action $menu_args><img src=i/$icon class=icon> $label</a>";
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
