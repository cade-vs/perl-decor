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
use strict;
use lib ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' );

use FindBin;
use lib '/usr/local/decor/core/lib';
use lib $FindBin::Bin . "/../lib";

use Data::Dumper;
use Decor::Core::Env;
use Decor::Core::Config;
use Decor::Core::Stage;
use Decor::Core::Profile;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $root = de_root();

de_set_debug( 1 );

my $stage = Decor::Core::Stage->new( shift() );
$stage->init( $root );

$stage->__dsn_parse_config();


my @tables = @ARGV;
@tables = @{ $stage->get_tables_list() } unless @tables > 0;

$_ = uc $_ for @tables;

print "rebuilding tables: @tables\n";

for my $table ( @tables )
  {
  my $des = $stage->describe_table( $table );
  my $dbh = $stage->dsn_get_dbh_by_table( $table );
  my $db_name = $stage->dsn_get_db_name( $des->get_dsn_name() );

  my $rebuild = get_rebuild_obj( $db_name );

  print Dumper( $des, $db_name );
  
  }


#-----------------------------------------------------------------------------

my %REBUILD_OBJ;

sub get_rebuild_obj
{
  my $db_name = shift;

  de_check_name_boom( $db_name, "invalid DB NAME [$db_name]" );
  
  return $REBUILD_OBJ{ $db_name } if exists $REBUILD_OBJ{ $db_name };

  my $rebuild_class_name = "Decor::System::Table::Rebuild::$db_name";
  
  my $rebuild = new $rebuild_class_name;
  
  print Dumper( $db_name, $rebuild_class_name );
  
  $REBUILD_OBJ{ $db_name } = $rebuild;
  
  return $rebuild;
}


#-----------------------------------------------------------------------------

=pod

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

$stage->dsn_reset();

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

=cut
