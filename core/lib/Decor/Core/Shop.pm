##############################################################################
##
##  Decor application machinery core
##  2014-2022 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Shop;
use strict;

use Exception::Sink;

use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Core::Env;
use Decor::Core::DSN;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                record_create
                record_load
                record_new
                io_new
                io_exec_by_table
                io_exec_by_table_boom
                io_count_by_table

                );

sub record_create
{
  my $new_rec = new Decor::Core::DB::Record;
  $new_rec->create( @_ );
  return $new_rec;
}

sub record_load
{
  my $new_rec = new Decor::Core::DB::Record;
  $new_rec->load( @_ ) or return undef;
  return $new_rec;
}

sub record_new
{
  return new Decor::Core::DB::Record;
}

sub io_new
{
  return new Decor::Core::DB::IO;
}

sub io_exec_by_table
{
  my $table = shift; # used only to select correct DBH
  my $stmt  = shift;
  my @bind  = @_;

  my $dbh = dsn_get_dbh_by_table( $table );

  my $sth = $dbh->prepare( $stmt );

  my $retval = $sth->execute( @bind );

  return $retval;
}

sub io_exec_by_table_boom
{
  return io_exec_by_table( @_ ) or boom "error: io_exec: @_\n";
}

sub io_count_by_table
{
  my $table = shift;
  my $where = shift;
  my @bind  = @_;

  my $io = io_new();
  
  return $io->count( $table, $where, { BIND => \@bind });
}

### EOF ######################################################################
1;
