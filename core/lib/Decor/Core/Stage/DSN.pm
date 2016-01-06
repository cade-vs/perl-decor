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

### DATA SOURCE NAMES SUPPORT AND DB HANDLERS ################################

sub __dsn_parse_config
{
}

sub __dsn_dbh_connect
{
  my $self  =    shift;
  my $name  = uc shift;

  boom "invalid DSN (NAME)" unless exists $self->{ 'DSN' }{ $name };
  
  my $dsn = $self->{ 'DSN' }{ $name }{ 'DSN'  };
  my $usr = $self->{ 'DSN' }{ $name }{ 'USER' };
  my $pwd = $self->{ 'DSN' }{ $name }{ 'PASS' };

  my $dbh; # FIXME: TODO: DBI CONNECT HERE

  return $dbh;
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
  my $dsn = $self->{ '@' }{ 'DSN' };
  
  my $dbh = $self->dsn_get_dbh_by_name( $dsn );
  $cache->{ $table } = $dbh;
  
  return $dbh;
}

### EOF ######################################################################
1;
