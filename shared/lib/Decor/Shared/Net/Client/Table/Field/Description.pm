##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client::Table::Field::Description;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

##############################################################################

sub client
{
  my $self = shift;
  
  return $self->{ ':CLIENT_OBJECT' };
}

sub get_attr
{
  my $self = shift;
  my @path = @_;

  my $attr = pop @path;
  
  boom "missing ATTRIBUTE NAME argument" unless $attr;
  
  while( @path )
    {
    my $full_attr = join '.', @path, $attr;
    return $self->{ $full_attr } if exists $self->{ $full_attr };
    pop @path;
    }

  return undef unless exists $self->{ $attr };
    
  return $self->{ $attr };
}

sub is_linked
{
  my $self   = shift;
  
  return ( exists $self->{ 'LINKED_TABLE' } or exists $self->{ 'BACKLINKED_TABLE' } ) ? 1 : undef;
}

sub is_backlinked
{
  my $self   = shift;
  
  return ( exists $self->{ 'BACKLINKED_TABLE' } ) ? 1 : undef;
}

sub link_details
{
  my $self   = shift;
  
  if( exists $self->{ 'LINKED_TABLE' } )
    {
    return ( $self->{ 'LINKED_TABLE' }, $self->{ 'LINKED_FIELD' }, $self->{ 'LINK_TYPE' } );
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

  if( exists $self->{ 'BACKLINKED_TABLE' } )  
    {
    return ( $self->{ 'BACKLINKED_TABLE' }, $self->{ 'BACKLINKED_KEY' }, $self->{ 'LINK_TYPE' } );
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
  
  my $ltdes = $self->client()->describe( $linked_table );
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
