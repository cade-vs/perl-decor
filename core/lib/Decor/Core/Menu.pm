##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Menu;
use strict;
use open ':std', ':encoding(UTF-8)';

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;
use Tie::IxHash;
use Data::Lock qw( dlock dunlock );

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Describe;
#use Decor::Core::Config;
use Decor::Core::Table::Description;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_menu_reset

                preload_all_menus

                de_get_menus_list
                de_menu_get

                );

# TODO: FIXME: handle LOOP errors!

### TABLE DESCRIPTIONS #######################################################

my %MENU_TYPES = (
                      'GRID'    => 1,
                      'SUBMENU' => 1,
                      'INSERT'  => 1,
                      'EDIT'    => 1,
                      'URL'     => 1,
                      'DO'      => 1,
                      'ACTION'  => 1,
                 );

my %MENU_KEY_TYPES  = (
                      'GRANT' => '@',
                      'DENY'  => '@',
                    );

my %MENU_KEY_SHORTCUTS = (
                        'UNIQ' => 'UNIQUE', # not used
                        );

my @TABLE_ATTRS = qw(
                      SCHEMA
                      LABEL
                      GRANT
                      DENY
                    );

# FIXME: more categories INDEX: ACTION: etc.
my %MENU_ATTRS = (
                  '@' => {
                           LABEL   => 1,
                           GRANT   => 1,
                           DENY    => 1,
                           OPTIONS => 1,
                         },
                  'ITEMS' => {
                           TYPE          => 1,
                           LABEL         => 1,
                           GRANT         => 1,
                           DENY          => 1,
                           UNIQUE        => 1,
                           OPTIONS       => 1,
                           FILTER_NAME   => 1,
                           FILTER_METHOD => 1,
                           ORDER_BY      => 1,
                           RIGHT         => 1,
                         },
                );

#my %DES_LINK_ATTRS = (
#                  'FIELD' => {
#                           GRANT  => 1,
#                           DENY   => 1,
#                         },
#                );

#my %TABLE_ATTRS = map { $_ => 1 } @TABLE_ATTRS;
#hash_lock_recursive( \%TABLE_ATTRS );
#my %FIELD_ATTRS = map { $_ => 1 } @FIELD_ATTRS;
#hash_lock_recursive( \%FIELD_ATTRS );

#-----------------------------------------------------------------------------

my %MENU_CACHE;
my $MENU_CACHE_PRELOADED;

sub de_menu_reset
{
  %MENU_CACHE = ();
  $MENU_CACHE_PRELOADED = 0;

  return 1;
}

#-----------------------------------------------------------------------------

sub __get_menus_dirs
{
  return $MENU_CACHE{ 'MENUS_DIRS_AR' } if exists $MENU_CACHE{ 'MENUS_DIRS_AR' };

  my $root         = de_root();
  my $app_dir     = de_app_dir();
  my $bundles_dirs = de_bundles_dirs();

  my @dirs;
  push @dirs, "$root/core/menus";
  push @dirs, "$_/menus" for reverse @$bundles_dirs;
  push @dirs, "$app_dir/menus";

  $MENU_CACHE{ 'MENUS_DIRS_AR' } = \@dirs;

  return \@dirs;
}

#-----------------------------------------------------------------------------

sub de_get_menus_list
{
  return $MENU_CACHE{ 'MENUS_LIST_AR' } if exists $MENU_CACHE{ 'MENUS_LIST_AR' };

  my $menus_dirs = __get_menus_dirs();

  #print STDERR 'TABLE MENU DIRS:' . Dumper( $menus_dirs );

  my @menus;

  for my $dir ( @$menus_dirs )
    {
    print STDERR "$dir/*.def\n";
    push @menus, ( sort( glob_tree( "$dir/*.def" ) ) );
    }

  s/^.*?\/([^\/]+)\.def$/uc($1)/ie for @menus;
  @menus = keys %{ { map { $_ => 1 } grep { ! /^_+/ } @menus } };

  $MENU_CACHE{ 'MENUS_LIST_AR' } = \@menus;

  return \@menus;
}

#-----------------------------------------------------------------------------

sub __merge_menu_file
{
  my $menu      = shift; # config hash ref
  my $menu_name = shift;
  my $fname     = shift;
  my $opt       = shift || {};

  my $order = 0;

  my $inf;
  open( $inf, "<", $fname ) or boom "cannot open menu file [$fname]";

  de_log_debug2( "menu open file: [$fname]" );

  my $item_name = '@'; # self :) should be more like 0
  $menu->{ $item_name } ||= {};
  my $file_mtime = file_mtime( $fname );
  if( $menu->{ $item_name }{ '_MTIME' } < $file_mtime )
    {
    # of all files merged, keep only the latest modification time
    $menu->{ $item_name }{ '_MTIME' } = $file_mtime;
    }

  my $ln; # line number
  while( my $line = <$inf> )
    {
    $ln++;
    my $origin = "$fname at $ln"; # localize $origin from the outer one

    chomp( $line );
    $line =~ s/^\s*//;
    $line =~ s/\s*$//;
    next unless $line =~ /\S/;
    next if $line =~ /^([#;]|\/\/)/;
    de_log_debug2( "        line: [$line]" );

#    if( $line =~ /^=+\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*(.*?)\s*$/ )
    if( $line =~ /^=+\s*(.*?)\s*$/ )
      {
         $item_name = uc( $1 );
      my $item_opts =     $2; # fixme: upcase/locase?

      de_log_debug2( "       =item: [$item_name]" );

      $menu->{ $item_name } ||= {};
      $menu->{ $item_name }{ 'LABEL' } ||= $item_name;
      $menu->{ $item_name }{ '_ORDER' } = ++ $opt->{ '_ORDER' };

      if( de_debug() )
        {
        $menu->{ $item_name }{ 'DEBUG::ORIGIN' } ||= [];
        push @{ $menu->{ $item_name }{ 'DEBUG::ORIGIN' } }, $origin;
        }

      next;
      }

    if( $line =~ /^([a-zA-Z\-_0-9\.]+)\s*(.*?)\s*$/ )
      {
      my $key   = uc $1;
      my $value =    $2;

      $key =~ s/-/_/g;

      $key = $MENU_KEY_SHORTCUTS{ $key } if exists $MENU_KEY_SHORTCUTS{ $key };
      #boom "unknown attribute key [$key] for menu [$menu_name] item [$item_name] at [$fname at $ln]" unless exists $MENU_ATTRS{ $item_name eq '@' ? '@' : 'ITEMS' }{ $key };
      if( ! exists $MENU_ATTRS{ $item_name eq '@' ? '@' : 'ITEMS' }{ $key } )
        {
        de_log( "error: menu: unknown attribute key [$key] for menu [$menu_name] item [$item_name] at [$fname at $ln]" );
        $menu->{ $item_name }{ '__INVALID' }++;
        }

      if( $value =~ /^(['"])(.*?)\1/ )
        {
        $value = $2;
        }
      elsif( $value eq '' )
        {
        $value = 1;
        }

      de_log_debug2( "            key:  [$item_name]:[$key]=[$value]" );

      if( $key eq 'GRANT' or $key eq 'DENY' )
        {
        $menu->{ $item_name }{ '__GRANT_DENY_ACCUMULATOR'  } ||= [];
        push @{ $menu->{ $item_name }{ '__GRANT_DENY_ACCUMULATOR' } }, "$key  $value";

        next;
        }

      if( $MENU_KEY_TYPES{ $key } eq '@' )
        {
        $menu->{ $item_name }{ $key } ||= [];
        push @{ $menu->{ $item_name }{ $key } }, $value;
        }
      else
        {
        $menu->{ $item_name }{ $key } = $value;
        }

      next;
      }

    }
  close( $inf );

  return 1;
}

sub __merge_menu_hash
{
  my $menu      = shift;
  my $menu_name = uc shift;

  boom "invalid MENU name [$menu_name]" unless de_check_name( $menu_name );

  my $menus_dirs = __get_menus_dirs();

  #print STDERR 'MENUS DIRS:' . Dumper( $tables_dirs );

  my $menu_fname = lc $menu_name;
  my @menus_files;
  push @menus_files, glob_tree( "$_/$menu_fname.def" ) for @$menus_dirs;

  my $c = 0;
  my $opt = {};
  for my $file ( @menus_files )
    {
    $c++;
    __merge_menu_file( $menu, $menu_name, $file, $opt );
    }

  return $c;
}

sub __postprocess_menu_hash
{
  my $menu      = shift;
  my $menu_name = uc shift;
###  print STDERR "TABLE DES RAW [$table]:" . Dumper( $des );

  boom "missing MENU (load error) for menu name [$menu_name]" unless $menu;

  # postprocessing TABLE (self) ---------------------------------------------
  my @items  = sort { $menu->{ $a }{ '_ORDER' } <=> $menu->{ $b }{ '_ORDER' } } keys %{ $menu };

  # convert grant/deny list to access tree
  describe_preprocess_grant_deny( $menu->{ '@' } );

  # add empty keys to table description before locking
  for my $attr ( keys %{ $MENU_ATTRS{ '@' } } )
    {
    next if exists $menu->{ '@' }{ $attr };
    $menu->{ '@' }{ $attr } = undef;
    }

  # more postprocessing work
  $menu->{ '@' }{ '_MENU_NAME'   } = $menu_name;
  $menu->{ '@' }{ '_ITEMS_LIST'  } = \@items;

  $menu->{ '@' }{ 'GRANT' } = {} unless $menu->{ '@' }{ 'GRANT' };
  $menu->{ '@' }{ 'DENY'  } = {} unless $menu->{ '@' }{ 'DENY'  };

  #print STDERR "MENU DES AFTER SELF PP [$menu_name]:" . Dumper( $menu );
  # postprocessing FIELDs ---------------------------------------------------

  for my $item ( @items )
    {
    next if $item eq '@';

    my $item_des = $menu->{ $item };
    if( $item_des->{ '__INVALID' } )
      {
      # remove menu items with invalid attributes
      delete $menu->{ $item };
      next;
      }

    # --- type ---------------------------------------------
    my @type = split /[,\s]+/, uc $item_des->{ 'TYPE' };
    my $type = shift @type;

    my @debug_origin = exists $item_des->{ 'DEBUG::ORIGIN' } ? @{ $item_des->{ 'DEBUG::ORIGIN' } } : ();

    # "high" level types
    if( $type eq 'SUBMENU' )
      {
      my $submenu = shift @type;
      my $subm;
      $subm = __load_menu( $submenu ) if $submenu;
      if( ! $subm )
        {
        de_log( "error: menu: unknown SUBMENU [$submenu] in menu [$menu_name] item [$item] from [@debug_origin]" );
        # remove submenu item pointing to unknown menu
        delete $menu->{ $item };
        next;
        }
      $item_des->{ 'SUBMENU_NAME' } = $submenu;
      }
    elsif( $type =~ /^(GRID|INSERT|EDIT)$/ )
      {
      my $table = shift @type;
      if( ! des_exists( $table ) )
        {
        de_log( "error: menu: unknown table [$table] in menu [$menu_name] item [$item] from [@debug_origin]" );
        # remove item pointing to unknown table
        delete $menu->{ $item };
        next;
        }
      $item_des->{ 'TABLE' } = $table;
      }
    elsif( $type =~ /^(URL)$/ )
      {
      my $url = shift @type;
      $item_des->{ 'URL' } = $url;
      }
    elsif( $type =~ /^(ACTION)$/ )
      {
      my $action = shift @type;
      $item_des->{ 'ACTION' } = $action;
      }
    elsif( $type =~ /^(DO)$/ )
      {
      $item_des->{ 'TABLE' } = shift @type;
      $item_des->{ 'DO'    } = shift @type;
      }
    else
      {
      de_log( "error: menu: invalid MENU TYPE [$type] in menu [$menu_name] item [$item] from [@debug_origin]" );
      # remove item with unknown type
      delete $menu->{ $item };
      next;
      }
    $item_des->{ 'TYPE' } = $type;

    # convert grant/deny list to access tree
    describe_preprocess_grant_deny( $item_des );
#print Dumper( '-'x20, $menu_name, $item, $item_des );

    for my $grant_deny ( qw( GRANT DENY ) )
      {
#print Dumper( $menu_name, $menu->{ '@' }{ $grant_deny } );
      for my $oper ( keys %{ $menu->{ '@' }{ $grant_deny } } )
        {
        next if exists $item_des->{ $grant_deny }{ $oper };
        # link missing operation grant/deny to self
        $item_des->{ $grant_deny }{ $oper } = $menu->{ '@' }{ $grant_deny }{ $oper }
        }
      }

    # add empty keys to fields description before locking
    my $menu_attrs = $MENU_ATTRS{ $item eq '@' ? '@' : 'ITEMS' };
    for my $attr ( keys %$menu_attrs )
      {
      next if exists $item_des->{ $attr };
      $item_des->{ $attr } = undef;
      }

    }

  #print STDERR "MENU DES POST PROCESSSED [$menu_name]:" . Dumper( $menu );

  dlock $menu;
  #hash_lock_recursive( $des );

  return $menu;
}

#-----------------------------------------------------------------------------

sub __load_menu
{
  my $menu_name = uc shift;

  if( exists $MENU_CACHE{ 'MENU_DES' }{ $menu_name } )
    {
    # FIXME: boom if ref() is not HASH
    #de_log( "status: menu cache hit for [$menu_name]" );
    return $MENU_CACHE{ 'MENU_DES' }{ $menu_name };
    }
  elsif( $MENU_CACHE_PRELOADED )
    {
    return undef;
    }

  my $menu = {};
  tie %$menu, 'Tie::IxHash';

  my $rc;
  $rc = __merge_menu_hash( $menu, '_DE_UNIVERSAL' );
  # zero $rc for UNIVERSAL is ok
  $rc = __merge_menu_hash( $menu, $menu_name );
  return undef unless $rc > 0;
  __postprocess_menu_hash( $menu, $menu_name );

  $MENU_CACHE{ 'MENU_DES' }{ $menu_name } = $menu;

  return $menu;
}

sub de_menu_get
{
  my $menu_name = uc shift;

  my $menu = __load_menu( $menu_name );

  if( ! $menu )
    {
    my $menus_dirs = __get_menus_dirs();
    boom "cannot find/load MENU for menu name [$menu_name] dirs [@$menus_dirs]";
    }

  return $menu;
}

sub preload_all_menus
{
  my $menus = de_get_menus_list();

  for my $menu_name ( @$menus )
    {
    de_log_debug2( "preloading MENU for menu name [$menu_name]" );
    de_menu_get( $menu_name );
    };

  $MENU_CACHE_PRELOADED = 1;
}

### EOF ######################################################################
1;
