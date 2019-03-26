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

sub describe
{
  boom "describe must be reimplemented in the subclass";
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

sub get_table_name
{
  my $self  =    shift;
  
  return $self->{ '@' }{ 'NAME' };
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

### EOF ######################################################################
1;
