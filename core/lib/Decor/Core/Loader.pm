##############################################################################
##
##  Decor application machinery core
##  2014-2026 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  core loaders base: definition files lookup in core, bundles and app dirs
##  per kind (tables, menus, ...) and grant/deny access lines parsing shared
##  by all loaders (Decor::Core::Loader::Table, Decor::Core::Loader::Menu)
##
##############################################################################
package Decor::Core::Loader;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;

use Decor::Shared::Utils;
use Decor::Core::Env;
use Decor::Core::Log;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(
                loader_reset

                loader_dirs
                loader_names
                loader_files

                loader_grant_deny_tree
                loader_parse_access_line
                );

my %LOADER_CACHE;

sub loader_reset
{
  %LOADER_CACHE = ();

  return 1;
}

### DEFINITION FILES #########################################################

# loader_dirs( 'tables' ) returns array ref of dirs to search for definition
# files of a kind, in merge order: core, bundles, app
# currently kind is "table" or "menu"

sub loader_dirs
{
  my $kind = lc shift;

  boom "invalid loader kind [$kind]" unless $kind =~ /^[a-z_0-9]+$/;

  return $LOADER_CACHE{ 'DIRS' }{ $kind } if exists $LOADER_CACHE{ 'DIRS' }{ $kind };

  my $root         = de_root();
  my $app_dir      = de_app_dir();
  my $bundles_dirs = de_bundles_dirs();

  # FIXME: move here all bundles-related code from Env.def

  my @dirs;
  push @dirs, "$root/core/$kind";
  push @dirs, "$_/$kind" for reverse @$bundles_dirs;
  push @dirs, "$app_dir/$kind";

  return $LOADER_CACHE{ 'DIRS' }{ $kind } = \@dirs;
}

# loader_names( 'tables' ) returns array ref of sorted unique upper case names
# of all definition files of a kind, names starting with _ are skipped
sub loader_names
{
  my $kind = lc shift;

  return $LOADER_CACHE{ 'NAMES' }{ $kind } if exists $LOADER_CACHE{ 'NAMES' }{ $kind };

  my @names;
  push @names, glob_tree( "$_/*.def" ) for @{ loader_dirs( $kind ) };

  s/^.*?\/([^\/]+)\.def$/uc($1)/ie for @names;
  @names = sort keys %{ { map { $_ => 1 } grep { ! /^_+/ } @names } };

  return $LOADER_CACHE{ 'NAMES' }{ $kind } = \@names;
}

# loader_files( 'tables', 'DE_USERS' ) returns list of existing definition
# files for the name, in merge order: core, bundles, app
sub loader_files
{
  my $kind = lc shift;
  my $name = lc shift;

  boom "invalid definition name [$name]" unless de_check_name( $name );

  my @files;
  push @files, glob_tree( "$_/$name.def" ) for @{ loader_dirs( $kind ) };

  return @files;
}

### GRANT/DENY ACCESS ########################################################

my %OPERS = (
                      'READ'    => 1,
                      'INSERT'  => 1,
                      'UPDATE'  => 1,
                      'DELETE'  => 1,
                      'EXECUTE' => 1,
                      'ACCESS'  => 1,
                      'CROSS'   => 1,
                 );
my @OPERS = keys %OPERS;

my %GROUP_ALIASES = (
                      'ALL'    => 999,
                      'NOBODY' => 900,
                      'NOONE'  => 900,
                      'GUEST'  => 901,
);

#-----------------------------------------------------------------------------

# loader_grant_deny_tree( $hr )
#
# builds GRANT and DENY access trees of a description item (table self '@',
# field, DO, ACTION, menu item) from its grant/deny lines.
#
# args:
#   $hr  -- description item hashref, uses:
#             __GRANT_DENY_ACCUMULATOR  array ref of grant/deny lines, in the
#                                       order they appear in definition files,
#                                       e.g. [ 'deny all', 'grant read to 5' ]
#             TYPE                      type hashref, WIDELINK items always get
#                                       'deny insert update' appended
#             __DEBUG_ORIGIN            optional, file/line for error messages
#
# lines are applied in order, for each operation of a line:
#   set mode ( grant read ... )   replaces previous permission for the oper
#   add mode ( grant + read ... ) adds the line's group sets to previous ones
#   GRANT for an oper removes DENY for it and vice versa
#
# returns: nothing useful, $hr is modified in place:
#   $hr->{ 'GRANT' } = { OPER => group | [ [ grp, grp ], [ '!grp' ], ... ], ... }
#   $hr->{ 'DENY'  } = { same format }
#   __GRANT_DENY_ACCUMULATOR may get 'deny insert update' added for WIDELINKs
#
sub loader_grant_deny_tree
{
  my $hr = shift;

  my %access = ( 'GRANT' => {}, 'DENY' => {} );

  if( exists $hr->{ 'TYPE' } and ref( $hr->{ 'TYPE' } ) eq 'HASH' and exists $hr->{ 'TYPE' }{ 'NAME' } and $hr->{ 'TYPE' }{ 'NAME' } eq 'WIDELINK' )
    {
    # WIDELINKs are system and are forbidden for insert and update
    $hr->{ '__GRANT_DENY_ACCUMULATOR' } = [ @{ $hr->{ '__GRANT_DENY_ACCUMULATOR' } }, 'deny insert update'     ];
    }

  for my $line ( @{ $hr->{ '__GRANT_DENY_ACCUMULATOR' } } )
    {
    my ( $ty, $ta, $ac, $op )  = loader_parse_access_line( $line, $hr );

    for my $o ( @$op )
      {
      if( $ta )
        {
        # add mode, do not remove previous permissions
        $access{ $ty }{ $o } = [] unless defined $access{ $ty }{ $o };
        $access{ $ty }{ $o } = [ [ $access{ $ty }{ $o } ] ] unless ref( $access{ $ty }{ $o } );
        $ac->{ $o } = [ [ $ac->{ $o } ] ] unless ref( $ac->{ $o } );
        push @{ $access{ $ty }{ $o } }, @{ $ac->{ $o } };
        }
      else
        {
        # set mode, remove previous permissions
        $access{ $ty }{ $o } = $ac->{ $o };
        }
      my $rty = { GRANT => 'DENY', DENY => 'GRANT' }->{ $ty };
      delete $access{ $rty }{ $o };
      }
    }
  $hr->{ 'GRANT' } = $access{ 'GRANT' };
  $hr->{ 'DENY'  } = $access{ 'DENY'  };

#  print Dumper( "loader_grant_deny_tree DEBUG:", $hr->{ 'NAME' }, $hr->{ '__GRANT_DENY_ACCUMULATOR' }, $hr->{ 'GRANT' }, $hr->{ 'DENY' } );
}

#-----------------------------------------------------------------------------

# loader_parse_access_line( $line, $hr )
#
# parses single grant/deny line from definition files:
#
#   grant|deny [+] <op> [<op> ...] [to <groups>]
#
#   <op>      READ INSERT UPDATE DELETE EXECUTE ACCESS CROSS or ALL (all ops),
#             unknown operations are logged as error and skipped
#   +         add mode, adds group sets to previous permissions of the item
#   <groups>  group sets separated with ; or , (any set may match),
#             groups inside a set joined with + (all must match),
#             ! before group means "user is not in group",
#             group is number or alias ALL (999), NOBODY/NOONE (900),
#             GUEST (901); without "to <groups>" ALL is used
#
#   example:  grant read update to 5+6; !7
#
# args:
#   $line  -- access line text, case insensitive
#   $hr    -- description item hashref, used only for __DEBUG_ORIGIN in
#             error messages
#
# returns list:
#   ( $type, $add, \%access, \@opers )
#     $type    'GRANT' or 'DENY'
#     $add     '+' for add mode, empty for set mode
#     %access  OPER => group                 single numeric group, or
#              OPER => [ [ g1, g2 ], [ '!g3' ] ]  list of group sets
#     @opers   valid operations of the line (ALL expanded)
#
# booms on invalid line syntax
#
sub loader_parse_access_line
{
  my $line = uc shift;
  my $hr   = shift; # currently preprocessed field description, used for debug origin

  my @debug_origin = exists $hr->{ '__DEBUG_ORIGIN' } ? @{ $hr->{ '__DEBUG_ORIGIN' } } : ();

  $line =~ s/^\s*//;
  $line =~ s/\s*$//;

  # TODO: FIXME: make RE simpler!
  boom "invalid access line [$line] expected [grant|deny <op> <op> <op> to <grp>; <grp> + <grp>; <grp> + !<grp>] at [@debug_origin]"
        unless $line =~ /^\s*(GRANT|DENY)\s*((\+)?|\s)\s*([A-Z_0-9;,\s]+?)(\s+TO\s+([A-Z0-9!+;,\s]+))?\s*$/;

  my $type_line   = $1;
  my $type_add    = $3;
  my $opers_line  = $4;
  my $groups_line = $5 ? $6 : 'ALL';
  $groups_line =~ s/\s*//g;

#print "ACCESS DEBUG LINE [$line] OPER [$opers_line] GROUPS [$groups_line]\n";
#  boom "invalid access line, keywords must not be separated by whitespace [$line]" if $line =~ /[a-z_0-9]\s+[a-z_0-9]/i;

#  $line =~ s/\s*//g;
#print "ACCESS DEBUG LINE [$line]\n";

###  my @line = split /[;,]/, $line;

###  my $ops = shift @line;
  my @opers  = split /[\s;,]+/, $opers_line;
  my @groups = split /\s*[;,]\s*/, $groups_line;

  # replace aliases in each group of a set ( GUEST+5 ), keep leading ! ( !GUEST )
  $_ = join '+', map { /^(!?)(.*)$/; $1 . ( $GROUP_ALIASES{ $2 } || $2 ) } split /[+]/ for @groups;

  my @valid_opers;
  for my $op ( @opers )
    {
    if( $op eq 'ALL' )
      {
      @valid_opers = @OPERS;
      last;
      }
    if( ! $OPERS{ $op } )
      {
      de_log( "error: unknown operation [$op] in line [$line] at one of [@debug_origin]" );
      next;
      }
    push @valid_opers, $op;
    }
  @opers = @valid_opers; # unknown operations are skipped, not added to the access tree

  my %access;

  for my $op ( @opers )
    {
    if( @groups == 1 and $groups[ 0 ] =~ /^\d+$/ and $groups[ 0 ] > 0 )
      {
      $access{ $op } = $groups[ 0 ];
      }
    else
      {
      $access{ $op } = [ map { [ split /[+]/ ] } @groups ];
      }
    }


#print Dumper( $line, $opers_line, $groups_line, \%access );
  return ( $type_line, $type_add, \%access, \@opers );
}

### EOF ######################################################################
1;
