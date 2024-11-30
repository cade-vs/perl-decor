##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DSN;
use strict;

use DBI;
use Sys::SigAction qw( set_sig_handler );
use Exception::Sink;
use Data::Tools 1.09;
use Data::Lock qw( dlock dunlock );

use Data::Dumper;

use Decor::Shared::Config;
use Decor::Core::Env;
use Decor::Core::Describe;
use Decor::Core::Log;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                dsn_reset
                
                dsn_get_dbh_by_name
                dsn_get_dbh_by_table
                dsn_get
                dsn_get_db_name
                dsn_get_db_name_by_table

                dsn_begin_work
                dsn_commit
                dsn_savepoint
                dsn_rollback_to_savepoint
                dsn_rollback
                );

### DATA SOURCE NAMES SUPPORT AND DB HANDLERS ################################

my $DSN;
my %DSN_DBH_CACHE;
my %DSN_TABLE_DBH_CACHE;
my %DSN_TABLE_DB_NAME_CACHE;

sub dsn_reset
{
  dunlock $DSN = undef;
  
  %DSN_DBH_CACHE = ();
  %DSN_TABLE_DBH_CACHE = ();
  %DSN_TABLE_DB_NAME_CACHE = ();
  
  return 1;
}

sub __dsn_parse_config
{
  my $root         = de_root();
  my $stage_name   = de_app_name();
  my $app_dir      = de_app_dir();
  my $dsn_file     = "$app_dir/etc/dsn.conf";
  
  my $dsn = de_config_load_file( $dsn_file );
  $dsn = $dsn->{ '*' };
#  print Dumper( "DSN PARSE CONFIG: ", $dsn );

  for my $name ( keys %$dsn )
    {
    next if $name eq '@';
    my $dh = $dsn->{ $name };
    
    if( $dh->{ 'DSN' } =~ /^dbi:([a-z]+)/i )
      {
      $dh->{ 'DB_NAME' } = $1;
      }
    else
      {
      # FIXME: print subset of hash, skipping sensitive things, passwords, etc.
      boom "cannot find DSN DB_NAME for: " . Dumper( $dh );
      }  
    }

#  print Dumper( "DSN PARSE CONFIG: ", $dsn );
  
  hash_lock_recursive( $dsn );

  dlock $DSN = $dsn;
  return $DSN;
}

sub __dbi_error_handler
{
  boom_skip( "$_[0] $_[1] {$_[2]}", 1 );
}

sub __dsn_dbh_connect
{
  my $name  = uc shift;

  __dsn_parse_config() unless $DSN;

  boom "invalid DSN name [$name]" unless exists $DSN->{ $name };
  
  my $dsn = $DSN->{ $name }{ 'DSN'     };
  my $usr = $DSN->{ $name }{ 'USER'    };
  my $pwd = $DSN->{ $name }{ 'PASS'    };

  my $dbh;
  my $timeout_reached;
  eval
    {
    my $sig_handler = set_sig_handler( 'ALRM', sub { $timeout_reached = 1; die 'ECONNECT' } );
    alarm(4); # connect timeout, default 4 seconds, TODO: get from config

    $dbh = DBI->connect( 
                         $dsn, 
                         $usr, 
                         $pwd,
                         { 
                           # standard sane set, alpha-sorted
                           'AutoCommit'         => 0,
                           'ChopBlanks'         => 1,
                           'FetchHashKeyName'   => 'NAME_uc',
                           'PrintError'         => 0,
                           'RaiseError'         => 1,
                           'HandleError'        => \&__dbi_error_handler,
                           'ShowErrorStatement' => 1,
                         } 
                       );
    
    $dbh->{ 'LongReadLen' } = 4096; # FIXME: TODO: get from config
    };
  alarm(0); # reset alarm

  if( $@ )
    {
    my $alarm_msg = " connect timeout reached" if $timeout_reached;
    boom( "fatal: connect failed: DBI=[$DBI::errstr] Exception=[$@] $alarm_msg" );
    }
  else
    {
    de_log_debug( "debug: DBH connected for DSN name [$name]" );
    
    # FIXME: add an etc/env option to use or skip this
    # TODO: implement common instantiator of similar classes (factory :))
    my $db_name = $DSN->{ $name }{ 'DB_NAME' };
    my $dbn_class_name = "Decor::Core::DB::Setup::$db_name";
    my $dbn_file_name  = perl_package_to_file( $dbn_class_name );
    require $dbn_file_name;
    my $dbno = new $dbn_class_name;
    $dbno->setup_dbh( $dbh );
    
    return $dbh;
    }
}

sub dsn_get_dbh_by_name
{
  my $name  = uc shift;

  if( exists $DSN_DBH_CACHE{ $name } )
    {
    return $DSN_DBH_CACHE{ $name };
    }

  my $dbh = __dsn_dbh_connect( $name );

  $DSN_DBH_CACHE{ $name } = $dbh;
  return $dbh;
}

sub dsn_get_dbh_by_table
{
  my $table = uc shift;

  if( exists $DSN_TABLE_DBH_CACHE{ $table } )
    {
    return $DSN_TABLE_DBH_CACHE{ $table };
    }
  
  my $des = describe_table( $table );
  my $dsn = $des->{ '@' }{ 'DSN' };

  my $dbh = dsn_get_dbh_by_name( $dsn );
  $DSN_TABLE_DBH_CACHE{ $table } = $dbh;
  
  return $dbh;
}

sub dsn_get_db_name_by_table
{
  my $table = uc shift;

  if( exists $DSN_TABLE_DB_NAME_CACHE{ $table } )
    {
    return $DSN_TABLE_DB_NAME_CACHE{ $table };
    }
  
  my $des = describe_table( $table );
  boom "unknown table [$table]" unless $des;
  my $db_name = dsn_get_db_name( $des->get_dsn_name() );

  $DSN_TABLE_DB_NAME_CACHE{ $table } = $db_name;
  
  return $db_name;
}

sub dsn_get
{
  my $name  = uc shift;
  
  __dsn_parse_config() unless $DSN;

  boom "unknown DSN NAME [$name]" unless exists $DSN->{ $name };
  
  return $DSN->{ $name };
}

sub dsn_get_db_name
{
  my $name  = uc shift;
  
  my $dsn = dsn_get( $name );
  
  return $dsn->{ 'DB_NAME' };
}

#-----------------------------------------------------------------------------

sub dsn_begin_work
{
  # TODO: issue SQL BEGIN WORK [transaction type]
  return 1; 
}

sub dsn_commit
{
  # NOTE: commit should be global (for all DSNs)
  my $skip_second_main;
  for my $name ( ( 'MAIN', keys %DSN_DBH_CACHE ) )
    {
    next if $name eq 'MAIN' and $skip_second_main++;
    next unless exists $DSN_DBH_CACHE{ $name }; # skip if not connected
    my $dbh = $DSN_DBH_CACHE{ $name };
    $dbh->commit();
    }
}

sub dsn_savepoint
{
  my $sp_name = shift;
  my @dsn     = @_;
  
  boom "missing save point name" unless $sp_name; # cannot be '0'

  @dsn = ( 'MAIN', keys %DSN_DBH_CACHE ) unless @dsn > 0;
  my $skip_second_main;
  for my $name ( @dsn )
    {
    next if $name eq 'MAIN' and $skip_second_main++;
    next unless exists $DSN_DBH_CACHE{ $name }; # skip if not connected
    my $dbh = $DSN_DBH_CACHE{ $name };
    $dbh->do("SAVEPOINT sp_$sp_name");
    }
}

sub dsn_rollback_to_savepoint
{
  my $sp_name = shift;
  my @dsn     = @_;
  
  boom "missing save point name" unless $sp_name; # cannot be '0'

  @dsn = ( 'MAIN', keys %DSN_DBH_CACHE ) unless @dsn > 0;
  my $skip_second_main;
  for my $name ( @dsn )
    {
    next if $name eq 'MAIN' and $skip_second_main++;
    next unless exists $DSN_DBH_CACHE{ $name }; # skip if not connected
    my $dbh = $DSN_DBH_CACHE{ $name };
    $dbh->do("ROLLBACK TO sp_$sp_name");
    }
}

sub dsn_rollback
{
  # NOTE: commit should be global (for all DSNs)
  my $skip_second_main;
  for my $name ( ( 'MAIN', keys %DSN_DBH_CACHE ) )
    {
    next if $name eq 'MAIN' and $skip_second_main++;
    next unless exists $DSN_DBH_CACHE{ $name }; # skip if not connected
    my $dbh = $DSN_DBH_CACHE{ $name };
    $dbh->rollback();
    }
}


### EOF ######################################################################
1;
