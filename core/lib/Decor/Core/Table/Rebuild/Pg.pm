#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Table::Rebuild::Pg;
use strict;
use Exception::Sink;

use parent 'Decor::Core::Table::Rebuild';

sub describe_db_table
{
  my $self  = shift;
  my $table = shift;
  
  my $dbh = $self->get_dbh();
  
  my $des_stmt = qq(

           select
               table_name                  as "table",
               table_schema                as "schema",
               column_name                 as "column",
               data_type                   as "type",
               character_maximum_length    as "len",
               numeric_precision           as "precision",
               numeric_scale               as "scale",
               ( select current_schema() ) as "default_schema"
           from
               information_schema.columns
           where
               table = ? AND schema = ?
           order by
               table_name 
  );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( $table, $schema ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my %db_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    $db_des{ $column } = $hr;
=pod    
    my $table   = uc $hr->{ 'TABLE'     };
    my $schema  = uc $hr->{ 'SCHEMA'    };
    my $column  = uc $hr->{ 'COLUMN'    };
    my $type    = uc $hr->{ 'TYPE'      };
    my $prec    =    $hr->{ 'PRECISION' };
    my $scale   =    $hr->{ 'SCALE'     };
    my $dschema = uc $hr->{ 'DEFAULT_SCHEMA'  };

    $db_des{ $column }{ 'TYPE' } = $type;
=cut
    }
    
  return \%db_des;  
}
