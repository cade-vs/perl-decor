##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Table::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub __set_describe_callback
{
  my $self = shift;
  
  $self->{ ':DESCRIBE_CB' } = shift;
}

sub describe
{
  my $self = shift;
  
  boom "missing describe callback" unless $self->{ ':DESCRIBE_CB' };
  
  return $self->{ ':DESCRIBE_CB' }->( @_ );
}

sub is_virtual
{
  my $self = shift;
  
  return $self->{ '@' }{ 'VIRTUAL' };
}

sub get_table_type
{
  my $self = shift;
  
  return $self->{ '@' }{ 'TYPE' };
}

sub get_table_name
{
  my $self = shift;
  
  return $self->{ '@' }{ '_TABLE_NAME' };
}

sub get_table_type
{
  my $self = shift;
  
  return $self->{ '@' }{ 'TYPE' };
}

sub get_fields_list
{
  my $self = shift;
  
  return $self->{ '@' }{ '_FIELDS_LIST' };
}

sub get_dos_list
{
  my $self = shift;
  
  return $self->{ '@' }{ '_DOS_LIST' };
}

sub get_label
{
  my $self = shift;

  return $self->{ '@' }{ 'LABEL' };
}

sub get_table_des
{
  my $self  =    shift;
  
  return $self->{ '@' };
}

sub get_field_des
{
  my $self  =    shift;

  return $self->get_category_des( 'FIELD', @_ );
}

sub get_category_des
{
  my $self     =    shift;
  my $category = uc shift;
  my $item     = uc shift;

  if( $item eq '@' )
    {
    # shortcut to self, regardless category
    return $self->{ '@' };
    }
  
  if( ! exists $self->{ $category }{ $item } )
    {
    my $table = $self->get_table_name();
    boom "unknown category [$category] item [$item] for table [$table]";
    }

  return $self->{ $category }{ $item };
}

sub allows
{
  my $self = shift;
  
  my $oper    = uc shift;
  my $profile = shift; # not used here, only inside core

  return 0 if    ( exists $self->{ '@' }{ 'DENY'  }{ $oper } and $self->{ '@' }{ 'DENY'  }{ $oper } ) 
              or ( exists $self->{ '@' }{ 'DENY'  }{ 'ALL' } and $self->{ '@' }{ 'DENY'  }{ 'ALL' } );

  return 1 if    ( exists $self->{ '@' }{ 'GRANT' }{ $oper } and $self->{ '@' }{ 'GRANT' }{ $oper } ) 
              or ( exists $self->{ '@' }{ 'GRANT' }{ 'ALL' } and $self->{ '@' }{ 'GRANT' }{ 'ALL' } );
  
  return 0;
}

sub exists
{
  my $self     =    shift;
  my $category = uc shift;
  my $item     = uc shift;
  
  return undef unless exists $self->{ $category };
  return undef unless exists $self->{ $category }{ $item };
  
  return 1;
}

sub resolve_path
{
  my $self = shift;
  my $path = shift;
  
  my @path = split /\./, $path;
  
  my $f  = shift @path;
  my $bfdes = $self->get_field_des( $f );
  my $cfdes = $bfdes;

  while( @path )
    {
    if( ! $cfdes->is_linked() )
      {
      boom "during path resolve of [$path] non-linked field [$f] is found";
      }
    my ( $table ) = $cfdes->link_details();
    my $ctdes = $self->describe( $table );
    $f = shift @path;
    $cfdes = $ctdes->get_field_des( $f );
    }
  
  return wantarray ? ( $bfdes, $cfdes ) : $cfdes;
}

sub expand_field_path
{
  my $self = shift;
  my $path = shift;

  my @path = split /\./, $path;
  
  my $cfdes = $self->resolve_path( $path );
  while(4)
    {
    last unless $cfdes->is_linked();
    $cfdes = $cfdes->describe_linked_field();
    push @path, $cfdes->{ 'NAME' };
    }

  my $res = join '.', @path;
  return wantarray() ? ( $res, $cfdes ) : $res;  
}

sub sort_cat_by_order
{
  my $self = shift;
  my $cat  = shift;
  
  return sort { $self->{ $cat }{ $a }{ '_ORDER' } <=> $self->{ $cat }{ $b }{ '_ORDER' } } @_;
}

sub sort_fields_by_order
{
  my $self = shift;
  
  return $self->sort_cat_by_order( 'FIELD', @_ );
}

sub get_cat_list
{
  my $self = shift;
  my $cat  = shift;

  return [ $self->sort_cat_by_order( $cat, keys %{ $self->{ $cat } } ) ];
}

sub get_fields_list
{
  my $self = shift;

  return $self->get_cat_list( 'FIELD' );
}

#-----------------------------------------------------------------------------

sub get_fields_list_by_oper
{
  my $self     = shift;

  return $self->get_category_list_by_oper( 'FIELD', @_ );
}

sub get_category_list_by_oper
{
  my $self = shift;
  
  my $category = uc shift;
  my $oper     = uc shift;
  my $profile  = uc shift; # not used by shared and client, only inside core
  
  return $self->{ 'CACHE' }{ 'LIST_BY_OPER' }{ $category }{ $oper } if exists $self->{ 'CACHE' }{ 'LIST_BY_OPER' }{ $category }{ $oper };
  
  my @items;
  
  for my $item ( keys %{ $self->{ $category } } )
    {
    next unless $self->{ $category }{ $item }->allows( $oper, $profile );
    push @items, $item;
    }

  @items = sort { $self->{ $category }{ $a }{ '_ORDER' } <=> $self->{ $category }{ $b }{ '_ORDER' } } @items;

  $self->{ 'CACHE' }{ 'LIST_BY_OPER' }{ $category }{ $oper } = \@items;
  
  return \@items;
}

sub sort_category_list_by_order
{
  my $self = shift;
  
  my $category = uc shift;

  return sort { $self->{ $category }{ $a }{ '_ORDER' } <=> $self->{ $category }{ $b }{ '_ORDER' } } @_;
}

sub sort_fields_list_by_order
{
  my $self = shift;
  
  return $self->sort_category_list_by_order( 'FIELD', @_ );
}

### EOF ######################################################################
1;
