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
  
#  return "<#menu_outside>" unless $reo->is_logged_in();

  my $core = $reo->de_connect();
  my $menu = $core->menu( 'MAIN' );

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

    my $link;
    if( $type eq 'SUBMENU' )
      {
      my $submenu_name = $item->{ 'SUBMENU_NAME'  };
      $link = "<a class=main-menu reactor_none_href=?action=menu&menu=$submenu_name>$label</a>";
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
      $link = "<a class=menu reactor_none_href=?action=edit&table=$table>$label</a>";
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
      next if $reo->is_logged_in() and uc $action =~ /(\[~)?LOGIN(\])?/; # root hack
      $link = "<a class=menu reactor_none_href=?action=$action>$label</a>";
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
##  print STDERR Dumper( '+++', $menu, $text );
  return $text;
#  return "MAIN MENU" . rand() . return "<#menu_inside_debug><xmp>" . Dumper( $menu ) . "</xmp>";
}

1;
