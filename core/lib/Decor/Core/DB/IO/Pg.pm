##############################################################################
##
##  Decor stagelication machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::IO::Pg;
use strict;

use Exception::Sink;

use parent 'Decor::Core::DB::IO';


### PostgreSQL Specifics #####################################################

sub __init
{
  my $self = shift;
  
  1;
}

sub get_next_sequence
{
  my $self   = shift;
  my $db_seq = shift; # db sequence name
  my $dsn    = shift || 'MAIN';

  my $dbh = dsn_get_dbh_by_name( $dsn );

  my $sql_stmt = "SELECT NEXTVAL( '$db_seq' )";

  my $sth = $dbh->prepare_cached( $sql_stmt );

  my $hr = $dbh->selectrow_hashref( $sth );
  if ( $hr and $hr->{ "NEXTVAL" } )
    {
    return $hr->{ "NEXTVAL" };
    }
  else
    {
    boom "cannot read sequence [$db_seq]";
    }
}

### EOF ######################################################################
1;
