#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@noxrun.com> <cade@bis.bg> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
#use lib ( $ENV{ 'DECOR_ROOT' } || die "missing DECOR_ROOT env variable\n" ) . '/core/lib';
#use lib ( $ENV{ 'DECOR_ROOT' } || die "missing DECOR_ROOT env variable\n" ) . '/shared/lib';
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );

use Exception::Sink;
use Data::Dumper;

use Decor::Core::Env;
#use Decor::Core::Config;
use Decor::Core::Describe;
use Decor::Core::DSN;
use Decor::Core::Profile;
use Decor::Core::Log;
use Decor::Core::DB::Record;
use Decor::Shared::Utils;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

##############################################################################

##############################################################################

my $opt_app_name;
my $opt_recreate = 0;
my $opt_confirm_first = 0;
my $opt_inc_decor_tables = 1;

our $help_text = <<END;
usage: $0 <options> application_name tables
options:
    -f        -- drop and recreate database objects (tables/indexes/sequences)
    -fs       -- as -f but includes DECOR system tables
    -d        -- debug mode, can be used multiple times to rise debug level
    -o        -- ask for confirmation before executing tasks
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
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
  if( /-f(s)?/ )
    {
    $opt_recreate = 1;
    $opt_confirm_first = 1;
    $opt_inc_decor_tables = 0;
    print "option: recreate database objects\n";
    next unless $1;
    $opt_inc_decor_tables = 1;
    print "option: will consider and DECOR system tables\n";
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
  if( /-r(r)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    print "option: forwarding logs to STDERR\n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_app_name = shift @args;

print "option: database objects to handle: @args\n" if @args;
print "info: ALL database objects will be handled\n" unless @args;
print "info: application name in use [$opt_app_name]\n" if $opt_app_name;

#-----------------------------------------------------------------------------

de_init( APP_NAME => $opt_app_name );

my $root = de_root();

#Decor::Core::DSN::__dsn_parse_config();

my @tables = @args;
@tables = @{ des_get_tables_list() } unless @tables > 0;

@tables = grep { ! /^DE_/i } @tables if ! $opt_inc_decor_tables;

$_ = uc $_ for @tables;

print "rebuilding tables: \n";
print "                   $_\n" for sort @tables;

if( $opt_confirm_first )
  {
  print "type 'yes' to continue\n";
  $_ = <STDIN>;
  exit unless /yes/i;
  }

my $cc;
my $ac = @tables;
for my $table ( sort @tables )
  {
  $cc++;
  my $prc = sprintf "%6.2f", 100*$cc/$ac;
  print "rebuilding table: ($cc/$ac/$prc%) $table\n";
  my $des = describe_table( $table );
  my $dbh = dsn_get_dbh_by_table( $table );
  my $db_name = dsn_get_db_name( $des->get_dsn_name() );

  my $dbo = get_rebuild_obj( $des->get_dsn_name(), $db_name, $dbh );

  #print Dumper( $des, $db_name );
  
  rebuild_table( $dbo, $des );
  }

dsn_commit();

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
  
  #print Dumper( $db_name, $rebuild_class_name );
  
  $REBUILD_OBJ_CACHE{ $dsn_name } = $rebuild;
  
  return $rebuild;
}


#-----------------------------------------------------------------------------

sub rebuild_table
{
  my $dbo  = shift;
  my $des  = shift;
  
  my $table     = $des->get_table_name();
  my $db_table  = $des->get_db_table_name();
  my $table_des = $des->get_table_des();
  my $schema    = $table_des->{ 'SCHEMA' };
  
  # handle tables -------------------------------
  my $table_db_des = $dbo->describe_db_table( $table, $schema );
  
  if( $des->is_virtual() )
    {
    de_log( "status: table [$table] is VIRTUAL: will be skipped!" );
    return;
    }

  #print Dumper( 'TABLE DB DES:', $table, $schema, $table_db_des, $opt_recreate );

  if( $opt_recreate )
    {
    table_drop( $dbo, $des );
    $table_db_des = undef;
    }

  if( ! $table_db_des )
    {
    # table does not exist
    table_create( $dbo, $des );
    }
  else
    {
    # table does exist, try to alter
    table_alter( $dbo, $des, $table_db_des );
    }  

  # handle table sequence -------------------------------
  my $seq_db_des   = $dbo->describe_db_sequence( $table, $schema );

  #print Dumper( 'SEQUENCE DB DES:', $table, $schema, $seq_db_des );

  my $max_id = $dbo->get_table_max_id( $db_table );
  my $start_with = $max_id < 10001 ? 10001 : $max_id + 1;

  if( ! $seq_db_des )
    {
    # create, sequence does not exist
    sequence_create( $dbo, $des, $start_with );
    }
  else
    {
    # sequence does exist, try to sync
    sequence_alter( $dbo, $des, $start_with );
    }  
  
  # handle table indexes -------------------------------
  my $index_db_des = $dbo->describe_db_indexes( $table, $schema );

  #print Dumper( 'INDEX DB DES:', $table, $schema, $index_db_des );

  my $dbh = $dbo->get_dbh();
  my $fields = $des->get_fields_list();
  for my $field ( @$fields )
    {
    my $fld_des = $des->get_field_des( $field );
    my $index  = uc $fld_des->{ 'INDEX'  };
    my $unique =    $fld_des->{ 'UNIQUE' };

    next unless $index;  # no index required
    next if     $unique; # unique index required, but it is already created in table definition
    
    my $dx_name = "DX_${db_table}_${field}";
    
    if( ! exists $index_db_des->{ $dx_name } )
      {
      my $unique_str = 'UNIQUE' if $unique; # no op for now, already in table creation
      my $sql_stmt = "CREATE $unique_str INDEX $dx_name ON $db_table ( $field )";
      de_log( "info: creating $unique_str index [$dx_name] on table [$table] db table [$db_table] field [$field]" );
      de_log_debug( "debug: sql: [$sql_stmt]" );
      $dbh->do( $sql_stmt );
      }
    }

  my $indexes = $des->get_indexes_list();
  for my $index ( @$indexes )
    {
    my $idx_des = $des->get_index_des( $index );
    my $unique =    $idx_des->{ 'UNIQUE' };
    my $fields = uc $idx_des->{ 'FIELDS' };
    
    my @fields = split /[\s,]+/, $fields;
    # FIXME: check if $fields are already known in this table
    $fields = join ',', @fields;

    my $dx_name = "DX_$index";
    
    if( ! exists $index_db_des->{ $dx_name } )
      {
      my $unique_str = 'UNIQUE' if $unique; # no op for now, already in table creation
      my $sql_stmt = "CREATE $unique_str INDEX $dx_name ON $db_table ( $fields )";
      de_log( "info: creating $unique_str index [$dx_name] on table [$table] db table [$db_table] fields [$fields]" );
      de_log_debug( "debug: sql: [$sql_stmt]" );
      $dbh->do( $sql_stmt );
      }
    }

  # base-records (zero-id records)
  my $base_io = new Decor::Core::DB::IO;
  if( ! $base_io->read_first1_by_id_hashref( $table, 0, { MANUAL => 1 } ) )
    {
    de_log( "info: missing base record in table [$table], will recreate it" );
    my $des = describe_table( $table );
    my $fields = $des->get_fields_list();

    my %base_data;
    for my $field ( @$fields )
      {
      my $fdes = $des->get_field_des( $field );
      my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };
      # TODO: is it enough to check for non-CHAR and set them to zero?
      $base_data{ $field } = $type_name eq 'CHAR' ? '' : 0;
      }
    $base_data{ "_ID" } = 0;
    $base_io->insert( $table, \%base_data );  
    }
}

#--- tables ------------------------------------------------------------------

sub table_drop
{
  my $dbo  = shift;
  my $des  = shift;
  
  my $table    = $des->get_table_name();
  my $db_table = $des->get_db_table_name();
  
  my $dbh = $dbo->get_dbh();
  my $sql_stmt = "DROP TABLE $db_table";
  de_log( "info: drop table [$table] db table [$db_table]" );
  de_log_debug( "debug: sql: [$sql_stmt]" );
  $dbh->do( $sql_stmt );
}

sub table_create
{
  my $dbo  = shift;
  my $des  = shift;
  
  my $table    = $des->get_table_name();
  my $db_table = $des->get_db_table_name();

  my @sql_columns;

  my $fields = $des->get_fields_list();
  for my $field ( @$fields )
    {
    my $fld_des = $des->get_field_des( $field );

    my $type = $fld_des->{ 'TYPE' }{ 'NAME' };
    my $len  = $fld_des->{ 'TYPE' }{ 'LEN'  };
    my $dot  = $fld_des->{ 'TYPE' }{ 'DOT'  };

    my $column_args;
    
    $column_args .= " PRIMARY KEY" if $fld_des->{ 'PRIMARY_KEY' };
    $column_args .= " NOT NULL"    if $fld_des->{ 'NOT_NULL' };
    $column_args .= " UNIQUE"      if $fld_des->{ 'UNIQUE' };
    
    my $native_type = $dbo->get_native_type( $fld_des->{ 'TYPE' } );
    
    #print Dumper( $field, $fld_des->{ 'TYPE' }, $native_type );
    
    push @sql_columns, "$field $native_type $column_args";
    }
    
  my $sql_columns = join ', ', @sql_columns;

  my $sql_stmt = "CREATE TABLE $db_table ( $sql_columns )";
  
  de_log( "info: create table [$table] db table [$db_table]" );
  de_log_debug( "debug: sql: [$sql_stmt]" );
  
  my $dbh = $dbo->get_dbh();
  $dbh->do( $sql_stmt );
}

sub table_alter
{
  my $dbo  = shift;
  my $des  = shift;
  my $table_db_des = shift;
  
  #print Dumper( $table_db_des );
  
  my $table    = $des->get_table_name();
  my $db_table = $des->get_db_table_name();

  my @sql_columns;
  my @sql_zero;

  my $fields = $des->get_fields_list();
  my $add_columns = 0;
  for my $field ( @$fields )
    {
    my $fld_des = $des->get_field_des( $field );

    my $type      = $fld_des->{ 'TYPE' };
    my $type_name = $type->{ 'NAME' };
    my $len       = $type->{ 'LEN'  };
    my $dot       = $type->{ 'DOT'  };

    my ( $native_type, $base_type ) = $dbo->get_native_type( $type );

    if( exists $table_db_des->{ $field } )
      {
      my $field_db_des = $table_db_des->{ $field };
      my $in_type = $field_db_des->{ 'TYPE' };
      if( $in_type ne $base_type )
        {
        de_log( "error: incompatible field/column [$field] type [$type_name] change, got [$in_type] expected [$base_type]" );
        # FIXME: handle column types change?
        }
      next;
      }

    my $column_args;
    
    $column_args .= " PRIMARY KEY" if $fld_des->{ 'PRIMARY_KEY' };
    $column_args .= " NOT NULL"    if $fld_des->{ 'NOT_NULL'    };
    $column_args .= " UNIQUE"      if $fld_des->{ 'UNIQUE'      };
    
    #print Dumper( $field, $fld_des->{ 'TYPE' }, $native_type );
    
    my $zero_data = $type_name eq 'CHAR' ? "''" : 0;
    
    push @sql_columns, "$field $native_type $column_args";
    push @sql_zero, "$field = $zero_data";
    $add_columns++;
    }

  if( $add_columns > 0 )
    {
    de_log( "info: alter table [$table] db table [$db_table] added columns [$add_columns] (@sql_columns)" );
    }
  else
    {
    de_log( "info: alter table [$table] db table [$db_table] no changes found" );
    return 0;
    }  
    
  my $sql_stmt = $dbo->table_alter_sql( $db_table, \@sql_columns );
  
  de_log_debug( "debug: sql: [$sql_stmt]" );
  
  my $dbh = $dbo->get_dbh();
  $dbh->do( $sql_stmt );
  
  my $sql_zero = "UPDATE $table SET " . join( ',', @sql_zero );
  $dbh->do( $sql_zero );
  
  return 1;
}

#--- sequences ---------------------------------------------------------------

sub sequence_create
{
  my $dbo  = shift;
  my $des  = shift;
  my $start_with = shift;
  
  my $table    = $des->get_table_name();
  my $db_seq   = $des->get_db_sequence_name();

  $dbo->sequence_create( $des, $start_with );
  de_log( "info: create sequence for table [$table] db sequence [$db_seq] start with [$start_with]" );
  
  return 1;
}

sub sequence_drop
{
  my $dbo  = shift;
  my $des  = shift;
  
  my $table    = $des->get_table_name();
  my $db_seq   = $des->get_db_sequence_name();
  
  $dbo->sequence_drop( $des );
  de_log( "info: drop sequence for table [$table] db sequence [$db_seq]" );

  return 1;
}

sub sequence_alter
{
  my $dbo  = shift;
  my $des  = shift;
  my $start_with = shift;

  my $table    = $des->get_table_name();
  my $db_seq   = $des->get_db_sequence_name();

  my $current = $dbo->sequence_get_current_value( $des );
  
  if( $current >= $start_with )
    {
    de_log( "info: alter sequence [$db_seq] for table [$table] current value [$current] no change needed" );
    return 0;
    }

  de_log( "info: alter sequence [$db_seq] for table [$table] current value [$current] needs to be restarted with [$start_with]" );
  sequence_drop( $dbo, $des );
  sequence_create( $dbo, $des, $start_with );
  
  return 1;
}

#--- indexes -----------------------------------------------------------------

#-----------------------------------------------------------------------------

=pod

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

$stage->dsn_reset();

my $dbh = $stage->dsn_get_dbh_by_table( 'test1' );

print $dbh;

=cut
