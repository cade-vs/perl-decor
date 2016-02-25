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
package Decor::Core::System::Table::Rebuild::Pg;
use strict;
use Data::Dumper;
use Exception::Sink;

use parent 'Decor::Core::System::Table::Rebuild';

sub describe_db_table
{
  my $self   = shift;
  my $table  = shift;
  my $schema = shift;
  
  my $dbh = $self->get_dbh();

  my $where_schema;
  my @where_bind;

  push @where_bind, lc $table;
  
  if( $schema )
    {
    $where_schema = "table_schema = ?";
    push @where_bind, lc $schema;
    }
  else
    {
    $where_schema = "table_schema = ( select current_schema() )";
    }  
  
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
               table_name = ? AND $where_schema
           order by
               table_name 
  );
  
  print Dumper( $des_stmt, \@where_bind );
  
  my $sth = $dbh->prepare( $des_stmt );
  $sth->execute( @where_bind ) or die "[$des_stmt] exec failed: " . $sth->errstr;

  my %db_des;

  while( my $hr = $sth->fetchrow_hashref() )
    {
    my $column  = uc $hr->{ 'COLUMN'    };
    
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

1;
