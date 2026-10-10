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
##  description tree API, plain functions over plain (unblessed) description
##  hashes, the same on all sides (core, remote/client, web)
##
##  descriptions of other tables are pulled from a registered source:
##
##    core:   des_set_source( \&tdef_load );                       # at init
##    web:    des_set_source( sub { $client->describe( @_ ) } );   # per request
##
##  table arguments ($t) may be table name or table description hashref,
##  item arguments ($des, $fdes) are category item hashrefs (field, do,
##  action or table self '@').
##
##  access checks (allows) are not here, they belong to the Profile, all
##  *_by_oper functions take a Profile object with allows( $des, $oper )
##
##############################################################################
package Decor::Shared::Describe;
use strict;

use Data::Dumper;
use Scalar::Util qw( reftype );
use Exception::Sink;
use Data::Tools;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                des_set_source
                des_get_source
                des_describe

                des_exists
                des_exists_category
                des_exists_boom

                des_table_name
                des_table_type
                des_table_label
                des_table_s
                des_table_p
                des_is_virtual
                des_table_schema
                des_db_table_name
                des_db_sequence_name
                des_dsn_name

                des_table_des
                des_field_des
                des_category_des
                des_index_des

                des_fields_list
                des_dos_list
                des_actions_list
                des_indexes_list
                des_category_list
                des_sort_by_order
                des_sort_fields_by_order
                des_category_list_by_oper
                des_fields_list_by_oper

                des_item_table
                des_item_name
                des_item_label
                des_is_self_category
                des_self_des
                des_top_des
                des_get_attr
                des_get_cue

                des_type_name
                des_is_linked
                des_is_backlinked
                des_is_widelinked
                des_is_map
                des_is_required
                des_is_unique

                des_link_details
                des_backlink_details
                des_map_details
                des_describe_linked_field

                des_resolve
                des_expand_path
                des_field_expand_path

                );

my %CATEGORIES = map { $_ => 1 } qw( @ FIELD INDEX FILTER DO ACTION );

### SOURCE ###################################################################

my $DES_SOURCE;

# registers the description source: code ref, called with table name,
# must return table description hashref or undef for unknown table
sub des_set_source
{
  my $src = shift;

  boom "description source must be a CODE ref" unless ref( $src ) eq 'CODE';

  $DES_SOURCE = $src;
  return 1;
}

sub des_get_source
{
  return $DES_SOURCE;
}

# returns table description, accepts table name or table description hashref
sub des_describe
{
  my $t = shift;

  return $t if ref( $t ) and reftype( $t ) eq 'HASH'; # plain or (still) blessed description

  boom "description source is not set, use des_set_source() first" unless $DES_SOURCE;

  my $table = uc $t;
  boom "invalid table name [$t]" unless $table =~ /^[A-Z_0-9]+$/;

  my $tdes = $DES_SOURCE->( $table ) or boom "unknown table [$table]";

  return $tdes;
}

# same as des_describe() but returns undef instead of boom for unknown table
sub __des_describe_soft
{
  my $t = shift;

  return $t if ref( $t ) and reftype( $t ) eq 'HASH'; # plain or (still) blessed description
  return undef unless uc( $t ) =~ /^[A-Z_0-9]+$/;

  my $tdes = eval { des_describe( $t ) };
  return $tdes;
}

### EXISTS ###################################################################

# des_exists( $t, $field_or_path, $attr )
# returns 1 if table exists, 2 if field (or dot-path end field) exists,
# 3 if field attribute exists, 0 otherwise; never booms on unknown names
sub des_exists
{
  my $t    = shift;
  my $path = shift;
  my $attr = shift;

  my $tdes = __des_describe_soft( $t ) or return 0;
  return 1 unless defined $path and $path ne '';

  my $fdes = eval { scalar des_resolve( $tdes, $path ) } or return 0;
  return 2 unless defined $attr and $attr ne '';

  return exists $fdes->{ uc $attr } ? 3 : 0;
}

# des_exists_category( $cat, $t, $item, $attr ), same return values as des_exists()
sub des_exists_category
{
  my $cat  = uc shift;
  my $t    = shift;
  my $item = uc shift;
  my $attr = uc shift;

  boom "invalid category [$cat]" unless exists $CATEGORIES{ $cat };

  my $tdes = __des_describe_soft( $t ) or return 0;
  return 1 if $item eq '';

  return 0 unless exists $tdes->{ $cat } and exists $tdes->{ $cat }{ $item };
  return 2 if $attr eq '';

  return exists $tdes->{ $cat }{ $item }{ $attr } ? 3 : 0;
}

sub des_exists_boom
{
  my $msg = shift;

  boom "error: $msg: unknown TABLE:FIELD:ATTRIBUTE [@_]" unless des_exists( @_ );
  return 1;
}

### TABLE ####################################################################

sub des_table_name
{
  return des_describe( shift )->{ '@' }{ '_TABLE_NAME' };
}

sub des_table_type
{
  return des_describe( shift )->{ '@' }{ 'TYPE' };
}

# scalar context: label, list context: ( label2, label3 || label ) as before
sub des_table_label
{
  my @label = split /\s*;\s*/, des_describe( shift )->{ '@' }{ 'LABEL' };

  return wantarray ? ( $label[1], $label[2] || $label[0] ) : $label[0];
}

sub des_table_s
{
  return des_describe( shift )->{ '@' }{ 'S' };
}

sub des_table_p
{
  return des_describe( shift )->{ '@' }{ 'P' };
}

sub des_is_virtual
{
  return des_describe( shift )->{ '@' }{ 'VIRTUAL' };
}

sub des_table_schema
{
  return des_describe( shift )->{ '@' }{ 'SCHEMA' };
}

sub des_db_table_name
{
  my $tdes = des_describe( shift );

  my $table  = $tdes->{ '@' }{ '_TABLE_NAME' };
  my $schema = $tdes->{ '@' }{ 'SCHEMA' };
  $schema = "$schema." if $schema;

  return "${schema}$table";
}

sub des_db_sequence_name
{
  my $tdes = des_describe( shift );

  my $table  = $tdes->{ '@' }{ '_TABLE_NAME' };
  my $schema = $tdes->{ '@' }{ 'SCHEMA' };
  $schema = "$schema." if $schema;

  return "${schema}DE_SQ_$table";
}

sub des_dsn_name
{
  return des_describe( shift )->{ '@' }{ 'DSN' };
}

### CATEGORY ITEMS ###########################################################

sub des_table_des
{
  return des_describe( shift )->{ '@' };
}

sub des_field_des
{
  my $t     = shift;
  my $field = shift;

  return des_category_des( $t, 'FIELD', $field );
}

# '@' item is shortcut to table self, regardless category
sub des_category_des
{
  my $tdes = des_describe( shift );
  my $cat  = uc shift;
  my $item = uc shift;

  return $tdes->{ '@' } if $item eq '@';

  if( ! exists $tdes->{ $cat } or ! exists $tdes->{ $cat }{ $item } )
    {
    my $table = $tdes->{ '@' }{ '_TABLE_NAME' };
    boom "unknown category [$cat] item [$item] for table [$table]";
    }

  return $tdes->{ $cat }{ $item };
}

sub des_index_des
{
  my $t     = shift;
  my $index = shift;

  return des_category_des( $t, 'INDEX', $index );
}

### LISTS ####################################################################

# ordered lists, prepared by the description loader
sub des_fields_list
{
  return des_describe( shift )->{ '@' }{ '_FIELDS_LIST' };
}

sub des_dos_list
{
  return des_describe( shift )->{ '@' }{ '_DOS_LIST' };
}

sub des_actions_list
{
  return des_describe( shift )->{ '@' }{ '_ACTIONS_LIST' };
}

sub des_indexes_list
{
  return des_describe( shift )->{ '@' }{ '_INDEXES_LIST' };
}

# all items of a category, sorted by _ORDER, array ref
sub des_category_list
{
  my $tdes = des_describe( shift );
  my $cat  = uc shift;

  return [ des_sort_by_order( $tdes, $cat, keys %{ $tdes->{ $cat } || {} } ) ];
}

# sorts given category item names by _ORDER, returns list
sub des_sort_by_order
{
  my $tdes = des_describe( shift );
  my $cat  = uc shift;

  return sort { $tdes->{ $cat }{ $a }{ '_ORDER' } <=> $tdes->{ $cat }{ $b }{ '_ORDER' } } @_;
}

sub des_sort_fields_by_order
{
  my $t = shift;

  return des_sort_by_order( $t, 'FIELD', @_ );
}

# category items allowed for operation, sorted by _ORDER, array ref
# $profile must provide allows( $des, $oper )
sub des_category_list_by_oper
{
  my $tdes    = des_describe( shift );
  my $cat     = uc shift;
  my $oper    = uc shift;
  my $profile = shift;

  boom "missing profile for [$cat] list by [$oper]" unless ref( $profile );

  my @items = grep { $profile->allows( $tdes->{ $cat }{ $_ }, $oper ) } keys %{ $tdes->{ $cat } || {} };

  return [ des_sort_by_order( $tdes, $cat, @items ) ];
}

sub des_fields_list_by_oper
{
  my $t       = shift;
  my $oper    = shift;
  my $profile = shift;

  return des_category_list_by_oper( $t, 'FIELD', $oper, $profile );
}

### ITEM #####################################################################

# table name the item belongs to, TABLE back reference is set by the loader
# on all items (self '@', fields, DOs, ACTIONs), _TABLE_NAME kept as fallback
sub des_item_table
{
  my $des = shift;

  my $table = $des->{ 'TABLE' } || $des->{ '_TABLE_NAME' };
  boom "description item [$des->{ 'NAME' }] has no table reference (TABLE)" unless $table;

  return $table;
}

sub des_item_name
{
  return shift->{ 'NAME' };
}

sub des_item_label
{
  return shift->{ 'LABEL' };
}

sub des_is_self_category
{
  return exists $_[0]->{ '_TABLE_NAME' } ? 1 : 0;
}

# table self description '@' of the item's table
sub des_self_des
{
  my $des = shift;

  return $des if des_is_self_category( $des );
  return des_describe( des_item_table( $des ) )->{ '@' };
}

# whole table description of the item's table
sub des_top_des
{
  return des_describe( des_item_table( shift ) );
}

# des_get_attr( $des, 'WEB', 'GRID', 'LABEL' )
# looks for WEB.GRID.LABEL, then WEB.LABEL, then LABEL
sub des_get_attr
{
  my $des  = shift;
  my @path = @_;
  my $attr = pop @path;

  boom "missing ATTRIBUTE NAME argument" unless $attr;

  while( @path )
    {
    my $full_attr = join '.', @path, $attr;
    return $des->{ $full_attr } if exists $des->{ $full_attr };
    pop @path;
    }

  return undef unless exists $des->{ $attr };
  return $des->{ $attr };
}

# cue (label; hint) from item attribute, falls back to table self '@' item,
# %t is replaced with item label, returns ( label, hint ) or label
# (was de_web_get_cue() in web/lib/Decor/Web/Utils.pm)
sub des_get_cue
{
  my $des = shift;

  my $cue = des_get_attr( $des, @_ );
  if( ! $cue and ! des_is_self_category( $des ) )
    {
    $cue = des_get_attr( des_self_des( $des ), @_ );
    }

  my @cue = split /\s*;\s*/, $cue;

  my $label = des_item_label( $des );
  s/%t/$label/gi for @cue;

  if( wantarray() )
    {
    if( @cue > 1 )
      {
      return @cue[ 0 ] if $cue[ 1 ] eq '-';
      return @cue[ 0, 1 ];
      }
    else
      {
      return @cue[ 0, 0 ];
      }
    }
  else
    {
    return $cue[ 0 ];
    }
}

### FIELD ####################################################################

sub des_type_name
{
  return shift->{ 'TYPE' }{ 'NAME' };
}

sub des_is_linked
{
  return shift->{ 'TYPE' }{ 'NAME' } eq 'LINK';
}

sub des_is_backlinked
{
  return shift->{ 'TYPE' }{ 'NAME' } eq 'BACKLINK';
}

sub des_is_widelinked
{
  return shift->{ 'TYPE' }{ 'NAME' } eq 'WIDELINK';
}

sub des_is_map
{
  return shift->{ 'TYPE' }{ 'NAME' } eq 'MAP';
}

sub des_is_required
{
  return shift->{ 'REQUIRED' };
}

sub des_is_unique
{
  return shift->{ 'UNIQUE' };
}

# ( linked_table, linked_field )
sub des_link_details
{
  my $fdes = shift;

  return ( $fdes->{ 'LINKED_TABLE' }, $fdes->{ 'LINKED_FIELD' } ) if des_is_linked( $fdes );

  boom "link details requested for table [$fdes->{ 'TABLE' }] field [$fdes->{ 'NAME' }] but this is not a LINKED field";
}

# ( backlinked_table, backlinked_key, backlinked_src )
sub des_backlink_details
{
  my $fdes = shift;

  return ( $fdes->{ 'BACKLINKED_TABLE' }, $fdes->{ 'BACKLINKED_KEY' }, $fdes->{ 'BACKLINKED_SRC' } ) if des_is_backlinked( $fdes );

  boom "backlink details requested for table [$fdes->{ 'TABLE' }] field [$fdes->{ 'NAME' }] but this is not a BACKLINKED field";
}

# ( map_table, map_near_field, map_far_field, far_table, far_field )
# cross-table, uses description source for the map table
sub des_map_details
{
  my $fdes = shift;

  if( ! des_is_map( $fdes ) )
    {
    boom "map details requested for table [$fdes->{ 'TABLE' }] field [$fdes->{ 'NAME' }] but this is not a MAP field";
    }

  my $mffdes = des_field_des( $fdes->{ 'MAP_TABLE' }, $fdes->{ 'MAP_FAR_FIELD' } );
  my ( $far_table, $far_field ) = des_link_details( $mffdes );
  # TODO: FIXME: move to table description loading postprocessing!

  return ( $fdes->{ 'MAP_TABLE' }, $fdes->{ 'MAP_NEAR_FIELD' }, $fdes->{ 'MAP_FAR_FIELD' }, $far_table, $far_field );
}

# description of the field the LINK field points to, cross-table
sub des_describe_linked_field
{
  my $fdes = shift;

  my ( $linked_table, $linked_field ) = des_link_details( $fdes );

  my $ltdes = __des_describe_soft( $linked_table );
  if( ! $ltdes or ! exists $ltdes->{ 'FIELD' }{ uc $linked_field } )
    {
    boom "table [$fdes->{ 'TABLE' }] field [$fdes->{ 'NAME' }] links to unknown table [$linked_table] or field [$linked_field]";
    }

  return $ltdes->{ 'FIELD' }{ uc $linked_field };
}

### PATHS ####################################################################

# des_resolve( $t, 'FLD.FLD2.FLD3' ) follows LINK fields through tables
# returns ( base_field_des, final_field_des ) or final_field_des
sub des_resolve
{
  my $tdes = des_describe( shift );
  my $path = shift;

  my @path = split /\./, $path;

  my $f     = shift @path;
  my $bfdes = des_field_des( $tdes, $f );
  my $cfdes = $bfdes;

  while( @path )
    {
    boom "during path resolve of [$path] non-linked field [$f] is found" unless des_is_linked( $cfdes );

    my ( $table ) = des_link_details( $cfdes );
    $f     = shift @path;
    $cfdes = des_field_des( $table, $f );
    }

  return wantarray ? ( $bfdes, $cfdes ) : $cfdes;
}

# expands path until a non-LINK field is reached:
# des_expand_path( 'ORDERS', 'CLIENT' ) => 'CLIENT.NAME' (if CLIENT links to CLIENTS.NAME)
# returns ( expanded_path, final_field_des ) or expanded_path
sub des_expand_path
{
  my $t    = shift;
  my $path = shift;

  my @path  = split /\./, $path;
  my $cfdes = des_resolve( $t, $path );

  while( des_is_linked( $cfdes ) )
    {
    $cfdes = des_describe_linked_field( $cfdes );
    push @path, $cfdes->{ 'NAME' };
    }

  my $res = join '.', @path;
  return wantarray ? ( $res, $cfdes ) : $res;
}

# same as des_expand_path() but starts from a field description
sub des_field_expand_path
{
  my $fdes = shift;

  my $cfdes = $fdes;
  my @res   = ( $fdes->{ 'NAME' } );

  while( des_is_linked( $cfdes ) )
    {
    $cfdes = des_describe_linked_field( $cfdes );
    push @res, $cfdes->{ 'NAME' };
    }

  my $res = join '.', @res;
  return wantarray ? ( $res, $cfdes ) : $res;
}

### EOF ######################################################################
1;
