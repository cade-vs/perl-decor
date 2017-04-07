##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client::Table::Description;
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

sub allows
{
  my $self = shift;
  
  my $oper = uc shift;

#print STDERR Dumper( $self->{ '@' } );

  return 0 if    ( exists $self->{ '@' }{ 'DENY'  }{ $oper } and $self->{ '@' }{ 'DENY'  }{ $oper } ) 
              or ( exists $self->{ '@' }{ 'DENY'  }{ 'ALL' } and $self->{ '@' }{ 'DENY'  }{ 'ALL' } );
              
  return 1 if    ( exists $self->{ '@' }{ 'GRANT' }{ $oper } and $self->{ '@' }{ 'GRANT' }{ $oper } ) 
              or ( exists $self->{ '@' }{ 'GRANT' }{ 'ALL' } and $self->{ '@' }{ 'GRANT' }{ 'ALL' } );
  
  return 0;
}

sub get_label
{
  my $self = shift;

  return $self->{ '@' }{ 'LABEL' };
}

sub get_fields_list_by_oper
{
  my $self     = shift;
  my $oper     = uc shift;

  return $self->get_category_list_by_oper( $oper, 'FIELD' );
}

sub get_category_list_by_oper
{
  my $self = shift;
  
  my $oper     = uc shift;
  my $category = uc shift;
  
  return $self->{ 'CACHE' }{ 'LIST_BY_OPER' }{ $category }{ $oper } if exists $self->{ 'CACHE' }{ 'LIST_BY_OPER' }{ $category }{ $oper };
  
  my @items;
  
  for my $item ( keys %{ $self->{ $category } } )
    {
    next unless $self->{ $category }{ $item }->allows( $oper );
    push @items, $item;
    }

  @items = sort { $self->{ $category }{ $a }{ '_ORDER' } <=> $self->{ $category }{ $b }{ '_ORDER' } } @items;

  $self->{ 'CACHE' }{ 'LIST_BY_OPER' }{ $category }{ $oper } = \@items;
  
  return \@items;
}

sub get_field_des
{
  my $self = shift;
  return $self->get_category_des( 'FIELD', @_ );
}

sub get_category_des
{
  my $self =    shift;
  my $cat  = uc shift;
  my $item = uc shift;
  
  return $self->{ $cat }{ $item };
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
    my $ctdes = $self->client()->describe( $table );
    $f = shift @path;
    $cfdes = $ctdes->get_field_des( $f );
    }
  
  return wantarray ? ( $bfdes, $cfdes ) : $cfdes;
}

### EOF ######################################################################
1;
