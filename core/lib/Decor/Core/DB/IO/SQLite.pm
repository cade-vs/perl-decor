##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::IO::SQLite;
use strict;

use Exception::Sink;

use parent 'Decor::Core::DB::IO';

use Decor::Core::DSN;
use Decor::Core::Log;

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

  my $ss  = "SELECT SV FROM DE_SYS_SQLITE_SEQUENCES WHERE SN = ?";
  my $sth = $dbh->prepare( $ss );
  $sth->execute( $db_seq ) or die "[$ss] exec failed: " . $sth->errstr;
  my $hr = $sth->fetchrow_hashref();
  my $sv = $hr->{ 'SV' };

  my $ss  = "UPDATE DE_SYS_SQLITE_SEQUENCES SET SV = ? WHERE SN = ?";
  $dbh->do( $ss, {}, $sv + 1, $db_seq );

  return $sv;
}

sub __select_limit_clause
{
  my $self   = shift;
  my $limit  = shift;
  
  return "LIMIT $limit";
}

sub __select_offset_clause
{
  my $self   = shift;
  my $offset = shift;
  
  return "OFFSET $offset";
}

sub __select_for_update_clause
{
  return undef;
}

### EOF ######################################################################
1;
