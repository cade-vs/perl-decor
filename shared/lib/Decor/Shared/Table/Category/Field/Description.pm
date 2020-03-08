##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Table::Category::Field::Description;
use strict;

use parent 'Decor::Shared::Table::Category::Description';

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub get_table_name
{
  my $self  =    shift;
  
  return $self->{ 'TABLE' };
}

sub is_linked
{
  my $self   = shift;
  
  return $self->{ 'TYPE' }{ 'NAME' } eq 'LINK';
}

sub is_backlinked
{
  my $self   = shift;
  
  return $self->{ 'TYPE' }{ 'NAME' } eq 'BACKLINK';
}

sub is_widelinked
{
  my $self   = shift;
  
  return $self->{ 'TYPE' }{ 'NAME' } eq 'WIDELINK';
}

sub link_details
{
  my $self   = shift;
  
  if( $self->is_linked() )
    {
    return ( $self->{ 'LINKED_TABLE' }, $self->{ 'LINKED_FIELD' } );
    }
  else
    {
    my $table = $self->{ 'TABLE' };
    my $field = $self->{ 'NAME'  };
    boom "link details requested for table [$table] field [$field] but this is not a LINKED field";
    }  
}

sub backlink_details
{
  my $self   = shift;

  if( $self->is_backlinked() )  
    {
    return ( $self->{ 'BACKLINKED_TABLE' }, $self->{ 'BACKLINKED_KEY' } );
    }
  else
    {
    my $table = $self->{ 'TABLE' };
    my $field = $self->{ 'NAME'  };
    boom "backlink details requested for table [$table] field [$field] but this is not a BACKLINKED field";
    }  
}

sub describe_linked_field
{
  my $self   = shift;
  
  my ( $linked_table, $linked_field, $type ) = $self->link_details();
  
  my $ltdes = $self->describe( $linked_table );
  if( ! $ltdes or ! exists $ltdes->{ 'FIELD' }{ $linked_field } )
    {
    my $table = $self->{ 'TABLE' };
    my $field = $self->{ 'NAME'  };
    boom "table [$table] field [$field] links to unknown table [$linked_table] or field [$linked_field]";
    }
  my $lfdes = $ltdes->{ 'FIELD' }{ $linked_field };
  
  return $lfdes;
}

sub expand_field_path
{
  my $self   = shift;
  
  my $cfdes = $self;
  my @res = ( $self->{ 'NAME' } );
  while(4)
    {
    last unless $cfdes->is_linked();
    $cfdes = $cfdes->describe_linked_field();
    push @res, $cfdes->{ 'NAME' };
    }

  my $res = join '.', @res;
  return wantarray() ? ( $res, $cfdes ) : $res;  
}

### EOF ######################################################################
1;
