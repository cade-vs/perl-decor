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
use Decor::Core::Utils;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

#-----------------------------------------------------------------------------

my $opt_application_name;
my $opt_recreate = 0;
my $opt_confirm_first = 0;

our $help_text = <<END;
usage: $0 <options> application_name tables
options:
    -f        -- drop and recreate database objects (tables/indexes/sequences)
    -d        -- debug mode, can be used multiple times to rise debug level
    -o        -- ask for confirmation before executing tasks
    --        -- end of options
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -fd is invalid, correct is: -f -d
END

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /-f/ )
    {
    $opt_recreate = 1;
    print "option: recreate database objects\n";
    next;
    }
  if( /-o/ )
    {
    $opt_confirm_first = 1;
    print "option: ask confirmation before executing tasks\n";
    next;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_application_name = shift @args;

print "option: database objects to handle: @args\n" if @args;
print "info: ALL database objects will be handled\n" unless @args;
print "info: application name in use [$opt_application_name]\n" if $opt_application_name;

if( $opt_confirm_first )
  {
  print "type 'yes' to continue\n";
  $_ = <STDIN>;
  exit unless /yes/i;
  }

#-----------------------------------------------------------------------------

my $root = de_root();

my $stage = Decor::Core::Stage->new( $opt_application_name );
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

  my $dbo = get_rebuild_obj( $des->get_dsn_name(), $db_name, $dbh );

  print Dumper( $des, $db_name );
  
  rebuild_table( $rebuild_obj, $des );
  }


#-----------------------------------------------------------------------------

my %REBUILD_OBJ_CACHE;

sub get_rebuild_obj
{
  my $dsn_name = shift;
  my $db_name  = shift;
  my $dbh      = shift;

  de_check_name_boom( $dsn_name, "invalid DSN NAME [$dsn_name]" );
  de_check_name_boom( $db_name,  "invalid DB  NAME [$db_name]" );
  
  return $REBUILD_OBJ_CACHE{ $dsn_name } if exists $REBUILD_OBJ_CACHE{ $dsn_name };

  my $rebuild_class_name = "Decor::Core::System::Table::Rebuild::$db_name";
  
  my $rebuild_file_name = perl_package_to_file( $rebuild_class_name );
  require $rebuild_file_name;
  my $rebuild = $rebuild_class_name->new( $dbh );
  
  print Dumper( $db_name, $rebuild_class_name );
  
  $REBUILD_OBJ_CACHE{ $dsn_name } = $rebuild;
  
  return $rebuild;
}


#-----------------------------------------------------------------------------

sub rebuild_table
{
  my $dbo  = shift;
  my $des  = shift;
  
  my $table     = $des->get_table_name();
  my $table_des = $des->get_table_des();
  my $schema    = $table_des->{ 'SCHEMA' };
  
  # handle tables
  my $table_db_des = $dbo->describe_db_tables( $table, $schema );

  if( ! $table_db_des )
    {
    # table does not exist
    table_create( $dbo, $des );
    }
  else
    {
    # table does exist, try to alter
    table_alter( $dbo, $des );
    }  

  # handle table indexes
  my $index_db_des = $dbo->describe_db_indexes( $table, $schema );

  # handle table sequence
  my $seq_db_des   = $dbo->describe_db_sequence( $table, $schema );

  if( ! $seq_db_des )
    {
    # sequence does not exist
    sequence_create( $dbo, $des );
    }
  else
    {
    # sequence does exist, try to sync
    sequence_alter( $dbo, $des );
    }  
  
  
  
  print Dumper( $table, $schema, $table_db_des, $index_db_des, $seq_db_des );
}

#-----------------------------------------------------------------------------

sub table_create
{
  my $dbo  = shift;
  my $des  = shift;
  
  my $table     = $des->get_table_name();
  my $table_des = $des->get_table_des();
  my $schema    = $table_des->{ 'SCHEMA' };

  my $fields = $des->get_fields_list();
  
  my $dbh = $dbo->get_dbh();

  my $db_table = "$schema.$table";
  my $db_seq   = "$schema.SQ_$table";
  
  print "DROP: table: $t \t=> $db_table\n";
  $dbh->exec( "drop table $db_table" );
  $dbh->exec( "drop sequence $db_seq" );

  for my $field ( @$fields )
    {
    my $fld_des = $des->get_field_des( $field );

    my $type  = $fld_des->{ 'TYPE'      };
    my $len   = $fld_des->{ 'LEN'       };
    my $opt   = $fld_des->{ 'OPTIONS'   };
    my $prec  = $DB_DB_DES{ $db_t }{ $f }{ 'PRECISION' };
    my $scale = $DB_DB_DES{ $db_t }{ $f }{ 'SCALE'     };
    my $def   = $DB_DB_DES{ $db_t }{ $f }{ 'DEFAULT'   }; # FIXME: ???

    $def =~ s/^\s*//;
    $def =~ s/\s*$//;
    }
}

#-----------------------------------------------------------------------------

=pod

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

$stage->dsn_reset();

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

=cut
