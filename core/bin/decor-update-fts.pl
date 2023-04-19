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
use Data::Tools;
use Time::Progress;

use Decor::Core::Env;
#use Decor::Core::Config;
use Decor::Core::Describe;
use Decor::Core::DSN;
use Decor::Core::Profile;
use Decor::Core::Log;
use Decor::Core::DB::Record;
use Decor::Core::Shop;
use Decor::Shared::Utils;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

##############################################################################

##############################################################################

my $opt_app_name;
my $opt_recreate = 0;
my $opt_confirm_first = 0;

our $help_text = <<END;
usage: $0 <options> application_name tables
options:
    -f        -- flush all data
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
  if( /-f/ )
    {
    $opt_recreate = 1;
    $opt_confirm_first = 1;
    print "option: recreate FTS data\n";
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

my $root    = de_root();
my $app_dir = de_app_dir();
#Decor::Core::DSN::__dsn_parse_config();

my @tables = @args;
@tables = @{ des_get_tables_list() } unless @tables > 0;

@tables = grep { ! /^DE_/i } @tables;
@tables = grep { ! /_FT(W|M)$/i } @tables;

$_ = uc $_ for @tables;

print "rebuilding FTS data for tables: \n";
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

  update_fts_data( $table );
  }

dsn_commit();

print "\ndone.\n";

#-----------------------------------------------------------------------------

sub update_fts_data
{
  my $table = shift;
  
  my $des = describe_table( $table );
  my $dbh = dsn_get_dbh_by_table( $table );
  my $db_name = dsn_get_db_name( $des->get_dsn_name() );

  my @fields;
  
  my $fields = $des->get_fields_list();
  for my $f ( @$fields )
    {
    my $fld_des = $des->get_field_des( $f );
    next unless $fld_des->{ 'FTS' };
    push @fields, $f;
    }

  if( ! @fields )
    {
    print "NOTE: no FTS fields for table [$table]\n";
    return undef;
    }

  my $fts_dir = "$app_dir/tables/__auto__/fts";
  if( ! dir_path_ensure( $fts_dir ) )
    {
    print "NOTE: cannot access FTS table directory [$fts_dir]\n";
    return undef;
    }

  my $table_lc = lc $table;

  file_save( "$fts_dir/${table_lc}_ftw.def", "# THIS FILE IS AUTO GENERATED\n=W\nchar 92\nindex\n=L\nint\n" );
  file_save( "$fts_dir/${table_lc}_ftm.def", "# THIS FILE IS AUTO GENERATED\n=WL\nlink ${table}_ftw W\nindex\n=RL\nlink ${table} _ID\nindex\n" );

  system( "$root/core/bin/decor-rebuild-db.pl $opt_app_name ${table_lc}_ftw ${table_lc}_ftm");

  my $re = record_new();
  my $io = io_new();

  io_exec_by_table( $_, "ALTER TABLE $_ SET UNLOGGED"       ) for ( "${table}_FTW", "${table}_FTM" );
  io_exec_by_table( $_, "DELETE FROM $_ WHERE _ID >= 10001" ) for ( "${table}_FTW", "${table}_FTM" );

  my $sthw = fast_insert_prepare( $dbh, "${table}_FTW", qw( _ID W  L  ) );
  my $sthm = fast_insert_prepare( $dbh, "${table}_FTM", qw( _ID WL RL ) );

  my $wid = $io->get_next_table_id( "${table}_FTW" );
  my $mid = $io->get_next_table_id( "${table}_FTM" );

  my %W;

  my $r;
  my $lc = $io->count( $table );
  my $pr = Time::Progress->new( min => 0, max => $lc );
  
  $io->select( $table, [ '_ID', @fields ], "" );
  while( my $hr = $io->fetch() )
    {
    my $rid = $hr->{ '_ID' };
    my $data = lc join ' ', @$hr{@fields};
#    print "$rid -- [$data]\n";

    for my $w ( $data =~ /\w{2,}/g )
      {
#      print "        [$w]\n";
      
      my $wwid; # currently matched word ID
      if( ! exists $W{ $w } )
        {
#      print "        <<< [$wid]\n\n";
        $wid++;
        $W{ $w } = $wid;
        fast_insert( $dbh, $sthw, $wid, $w, length( $w ) );
        $wwid = $wid;
        }
      else
        {
        $wwid = $W{ $w };
        }  
#      print "        --> [$wid]\n\n";
        
      $mid++;  
      fast_insert( $dbh, $sthm, $mid, $wwid, $rid );
      }

    $re->commit() if $r % 4096 == 0;

    $r++;
    my $rs = str_num_comma( $r );
    my $ls = str_num_comma( $lc );
    print $pr->report( "\r   EPS=$rs of $ls %30b %p %s/sec (%S) %L ETA: %E -- %f", $r ) if $r % 317 == 0;
    }

  $io->commit();
}

sub fast_insert_prepare
{
  my $dbh   = shift;
  my $table = shift;

  my $stmt = "INSERT INTO $table ( " . join( ',', @_ ) . " ) VALUES ( " . join( ',', map { '?' } @_ ) . " )";
  my $sth = $dbh->prepare( $stmt );
  return $sth;
}

sub fast_insert
{
  my $dbh = shift;
  my $sth = shift;

  return $sth->execute( @_ );
}

sub load_dict
{
  my $t = shift;
  my $k = shift;
  my $v = shift;

  print "LOADING DICT: $t: $k => $v\n";
  
  my %d;
  
  my $io = io_new();
  $io->select( $t, [ $k, $v ] );
  while( my $hr = $io->fetch() )
    {
    $d{ $hr->{ $k } } = $hr->{ $v };
    }
  
  return \%d;
}
