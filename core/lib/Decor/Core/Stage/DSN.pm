##############################################################################
##
##  Decor stagelication machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Stage;
use strict;

use DBI;
use Sys::SigAction qw( set_sig_handler );

use Data::Dumper;
use Decor::Core::Config;

### DATA SOURCE NAMES SUPPORT AND DB HANDLERS ################################

sub __dsn_parse_config
{
  my $self  =    shift;

  my $root         = $self->get_root_dir();
  my $stage_name   = $self->get_stage_name();
  my $dsn_file     = "$root/apps/$stage_name/etc/dsn.def";
  
  my $dsn = de_config_load_file( $dsn_file );

  print Dumper( $dsn );
  
  $self->{ 'DSN' } = $dsn;
  return $dsn;
}

sub __dsn_dbh_connect
{
  my $self  =    shift;
  my $name  = uc shift;

  __dsn_parse_config() unless exists $self->{ 'DSN' };

  boom "invalid DSN (NAME)" unless exists $self->{ 'DSN' }{ $name };
  
  my $dsn = $self->{ 'DSN' }{ $name }{ 'DSN'  };
  my $usr = $self->{ 'DSN' }{ $name }{ 'USER' };
  my $pwd = $self->{ 'DSN' }{ $name }{ 'PASS' };

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
    return $dbh;
    }
}

sub dsn_get_dbh_by_name
{
  my $self  =    shift;
  my $name  = uc shift;

  my $cache = $self->__get_cache_storage( 'DSN_DBH' );
  if( exists $cache->{ $name } )
    {
    return $cache->{ $name };
    }

  my $dbh = $self->__dsn_dbh_connect( $name );

  $cache->{ $name } = $dbh;
  return $dbh;
}

sub dsn_get_dbh_by_table
{
  my $self  =    shift;
  my $table = uc shift;

  my $cache = $self->__get_cache_storage( 'TABLE_DBH' );
  if( exists $cache->{ $table } )
    {
    return $cache->{ $table };
    }
  
  my $des = $self->describe_table( $table );
  my $dsn = $self->{ '@' }{ 'DSN' } || 'MAIN';
  
  my $dbh = $self->dsn_get_dbh_by_name( $dsn );
  $cache->{ $table } = $dbh;
  
  return $dbh;
}

sub dsn_reset
{
  my $self  =    shift;

  my $cache = $self->__get_cache_storage( 'DSN_DBH' );
  %$cache = ();
  my $cache = $self->__get_cache_storage( 'TABLE_DBH' );
  %$cache = ();
  
  return;
}

### EOF ######################################################################
1;
