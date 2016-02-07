##############################################################################
##
##  Decor application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Table::Description;
use strict;

use parent 'Decor::Core::Base';

use Data::Dumper;
use Exception::Sink;
use Data::Tools;

use Decor::Core::Log;
use Decor::Core::Utils;
use Decor::Core::Config;

##############################################################################

sub fields
{
  my $self = shift;
  
  return $self->{ '@' }{ '_FIELDS_LIST' };
}

sub get_table_des
{
  my $self  =    shift;
  
  return $self->{ '@' };
}

sub get_field_des
{
  my $self  =    shift;
  my $field = uc shift;

  if( ! exists $self->{ $field } )
    {
    my $table = $self->{ '@' }{ '_TABLE_NAME' };
    boom "unknown field [$field] for table [$table]";
    }

  return $self->{ $field };
}

sub get_dsn_name
{
  my $self  =    shift;

  return $self->{ '@' }{ 'DSN' };
}

=pod
sub get_table_dbh
{
  my $self  =    shift;

  my $table = $self->{ '@' }{ '_TABLE_NAME' };
  
  print Dumper( $self );
  
  return $self->get_stage()->dsn_get_dbh_by_table( $table );
}
=cut

### EOF ######################################################################
1;
