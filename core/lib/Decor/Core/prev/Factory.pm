##############################################################################
##
##  App::Recon application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recon::Core::Factory;
use strict;

use App::Recon::Core::Config;

use Exception::Sink;
use Hash::Util;

##############################################################################

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;

  my $root     = shift;
  my $app_name = shift;
  
  boom "invalid factory root directory [$root]" unless -d $root;

  my $self = {
             'ROOT'     => $root,
             'APP_NAME' => $app_name,
             };
  bless $self, $class;

  if( $RED_DEBUG )
    {
    my ( $pack, $file, $line, $subname ) = caller( 0 );
    $self->{ 'DEBUG_CREATED_AT' } = "$file:$line:$subname";
    }
  return $self;
}

sub DESTROY
{
  my $self = shift;

  1;
}

sub get_root_dir
{
  my $self = shift;
  
  return $self->{ 'ROOT' };
}

sub get_app_name
{
  my $self = shift;
  
  return $self->{ 'APP_NAME' };
}

##############################################################################
#  database source management
##############################################################################

sub _load_dsn_config
{
  my $self = shift;
  
  my $dsn = {};

  my $root     = $self->get_root_dir();
  my $app_name = $self->get_app_name();
  
  my $dir = "$root/apps/$app_name/etc";
  my $res = red_merge_config_file( $dsn, 'dsn.cfg', [ $dir ] );
  
  if( $res )
    {
    hash_lock_recursive( $dsn );
    $self->{ 'DSN' } = $dsn;
    }
  else
    {
    boom "cannot load DSN configuration from [$dir/dsn.cfg]";
    }

  return 1;
}



sub get_dsn_list
{
  my $self = shift;
  
  return keys %{ $self->{ 'DSN' } };
}

sub get_dbh_by_dsn
{
  my $dsn_name = uc shift;
  my %opt = @_;

  my $dsn = $self->{ 'DSN' };

  boom "fatal: get_dbh_by_dsn: empty DSN name requested" unless $name;
  boom "fatal: get_dbh_by_dsn: unknown DSN name requested [$name]" unless exists $dsn->{ $dsn_name };

  return $self->{ 'DBH' }{ $name } if exists $self->{ 'DBH' }{ $name };
  
  my $conntry_limit = 16; # FIXME: get from config

  my $DBH;

  while( $conn_try_limit-- )
    {

    my $dbi_dsn  = $dsn->{ $name }{ 'DSN'  };
    my $dbi_user = $dsn->{ $name }{ 'USER' };
    my $dbi_pass = $dsn->{ $name }{ 'PASS' };

    my $timeout;
    eval
      {
      my $sig_h = set_sig_handler( 'ALRM', sub { $timeout = 1; die 'ECONNECT' } );
      alarm(4); # 4 seconds to connect DB, pretty enough

      $DBH = DBI->connect( $DBI_DSN, $DBI_USER, $DBI_PASS,
                                { 'AutoCommit' => 0,
                                  'PrintError' => 0,
                                  'RaiseError' => 1,
                                  'ChopBlanks' => 1,
                                  'ShowErrorStatement' => 1,
                                  'FetchHashKeyName' => 'NAME_uc',
                                } );
      $DBH->{ 'LongReadLen' } = $CONFIG{ 'LONG_READ_LEN' } if $CONFIG{ 'LONG_READ_LEN' };
      # $DBH->begin_work();
      alarm(0); # FIXME: zashto?
      };
    alarm(0);

    if( $@ )
      {
      $DBH = undef;
      sleep(1); # FIXME: delay? 1 second
      my $alrm = ", alarm timeout" if $timeout;
      rcd_log( "error: connect failed (lc=$conn_limit): $DBI::errstr ($@)$alrm\n" );
      }
    else
      {
      last;
      }
  }

  if ( $DBH )
    {
    my $DB_NAME = uc $DBH->{ Driver }->{ Name };
    if ( ! $DB_NAMES{ $DB_NAME } )
      {
      rcd_log( "debug: unsupported DB_NAME=($DB_NAME)" );
      $DBH = undef;
      return 0;
      }

    ### FIXME: $DSN{ $name }{ '@' }{ 'DB_NAME' } = $DB_NAME;

    my $db_init_fname = "$SYSTEM_DIR/etc/" . lc $DB_NAME . ".init";
    if ( -e $db_init_fname and open( my $fh, $db_init_fname ) ) 
      {
      rcd_log( "debug: loading db init file $db_init_fname" );

      while (<$fh>) 
        {
        chomp;
        next if /^\s*#/;
        next if /^\s*$/;
        rcd_log( "debug: executing sql statement '$_'" );
        $DBH->do($_);
        }
      close $fh;
      }
    $DBH{ $name } = $DBH;
    rcd_log( "debug: database connected ok (lc=$conn_limit) DB_NAME=($DB_NAME)" );
    
    return $DBH;
    }
  else
    {
    delete $DBH{ $name };
    rcd_log( "error: connect failed (lc=$conn_limit): $DBI::errstr ($@)" );
    return undef;
    }
  
}

sub get_dbh_by_table
{
}



##############################################################################
#  table descriptions
##############################################################################

sub get_table_des
{
}

sub preload_tables_des
{
}

sub get_tables_list
{
}

##############################################################################
#  objects manifacturing
##############################################################################

sub new_record
{
}

sub new_db
{
}

##############################################################################

1;
###EOF########################################################################

