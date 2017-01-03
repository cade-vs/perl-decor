##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::IO::Oracle;
use strict;

use parent 'Decor::Core::DB::IO';
use Exception::Sink;

use Decor::Core::DSN;
use Decor::Core::Log;

### Oracle Specifics #########################################################

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

  my $sql_stmt = "select $db_seq.nextval FROM dual";

  my $sth = $dbh->prepare_cached( $sql_stmt );

  my $hr = $dbh->selectrow_hashref( $sth );
  if ( $hr and $hr->{ "NEXTVAL" } )
    {
    my $nextval = $hr->{ "NEXTVAL" };
    de_log_debug( "debug: get_next_sequence: for sequence [$db_seq] new val [$nextval]" );
    return $nextval;
    }
  else
    {
    boom "cannot read sequence [$db_seq]";
    }
  
}

# ORACLE 12c and later, ONLY! sorry that oracle has no native limit/offset before 12c...

# FIXME: URGENT: NOT TESTED, no ORACLE 12c server access yet.

sub __select_limit_clause
{
  my $self   = shift;
  my $limit  = shift;
  
  return "FETCH FIRST $limit ROWS ONLY";
}

sub __select_offset_clause
{
  my $self   = shift;
  my $offset = shift;
  
  return "OFFSET $offset ROWS";
}

### EOF ######################################################################
1;
