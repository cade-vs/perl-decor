#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##                <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##  2014-2018 (c) Dimitar Atanasov
##                <datanasov@ir-statistics.net>
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use open ':std', ':encoding(UTF-8)';

use Term::ReadKey;
use Decor::Core::Env;
use Decor::Core::DSN;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Shared::Utils;
use Data::Tools;
use Data::Dumper;
use Exception::Sink;

data_tools_set_file_io_utf8();

#print Dumper( [ parse_scsv_line( qq[; '  123'  ;testing   ;this\\;is it; "asd";qwe] ) ] );
#die;

my $p0 = file_name_ext( $0 );

our $help_text = <<END;
usage: $0 <options> application_name object_names
options:
    -v        -- verbose output
    -i        -- use file names as object_names
    -t        -- use table names as object_names (default)
    -d        -- debug mode, can be used multiple times to rise debug level
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    -rc       -- use ANSI-colored STDERR log messages (same as -rrc)
    --        -- end of options
notes:
  * -t will search for files matching table names (see docs dir for details)
  * object_names may be either table names or file names (see options above)
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -rd is invalid, correct is: -r -d
examples:
  $p0 -v    table1 table2 table3
  $p0 -v -t table1 table2 table3 
  $p0 -v -i /path/to/files/*.def
END

my $opt_verbose;
my $use_files;

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /^-d/ )
    {
    my $level = de_debug_inc();
    print "option: debug level raised, now is [$level] \n";
    next;
    }
  if( /^-t/ )
    {
    $use_files = 0;
    print "option: using TABLE names\n";
    next;
    }
  if( /^-i/ )
    {
    $use_files = 1;
    print "option: using FILE names\n";
    next;
    }
    
  if( /^-v/ )
    {
    $opt_verbose = 1;
    next;
    }
  if( /-r(r)?(c)?/ )
    {
    $DE_LOG_TO_STDERR = 1;
    $DE_LOG_TO_FILES  = $1 ? 1 : 0;
    $DE_LOG_STDERR_COLORS = $2 ? 1 : 0;
    print "status: option: forwarding logs to STDERR\n";
    print "status: using ANSI colors in logs\n" if $DE_LOG_STDERR_COLORS;
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

de_init( APP_NAME => $opt_app_name );

my @objects = @args;
@objects = sort @{ des_get_tables_list() } if ! $use_files and ! @objects;
@objects = sort @objects if $use_files;

if( ! @objects )
  {
  print "error: missing objects names\n\n";
  print $help_text;
  exit;
  }

load_object( $_ ) for @objects;

dsn_commit();

##############################################################################

sub load_object
{
  my $object = shift;

  my $table;
  my @files;
  if( $use_files )
    {
    $table = uc file_name( $object );
    @files = ( $object );
    }
  else
    {
    $table = uc $object;
    @files = find_files_for_table( $object );
    if( @files )
      {
      print "found file: $_\n" for @files;
      }
    else
      {
      print "notice: no files for table [$object] \t-- skipped\n";
      return;
      }
    }  


  print "status: loading the following objects:\n";
  print "        [$_]\n" for @files;

  my $data = {};
  for my $file ( @files )
    {
    my $c = load_data_file( $table, $data, $file );
    print "status: [$table] <==($c)== [$file]\n";
    }
  print Dumper( $data );
  import_data( $table, $data );
}

##############################################################################

sub import_data
{
  my $table = uc shift;
  my $data  = shift;
  
  my $tdes = describe_table( $table );

  my $des = describe_table( $table );
  my $fields = $des->get_fields_list();
  my %data_default;
  for my $field ( @$fields )
    {
    my $fdes      = $des->get_field_des( $field );
    my $type_name = $fdes->{ 'TYPE' }{ 'NAME' };
    $data_default{ $field } = $type_name eq 'CHAR' ? '' : 0;
    }
    
  my $dbio = new Decor::Core::DB::IO;

  my @protected_ids;
  for my $id ( keys %$data )
    {
    push @protected_ids, $id if $data->{ $id }{ 'PROTECTED' } and $dbio->read_first1_hashref( $table, '._ID = ?', { BIND => [ $id ] } );
    }
  my $protected_ids = join ',', sort { $a <=> $b } @protected_ids;
  my %protected_ids = map { $_ => 1 } @protected_ids;
    
  my $dbh = dsn_get_dbh_by_table( $table );
  my $protected = "AND _ID NOT IN ( $protected_ids )" if $protected_ids;
  my $dd_stmt = "DELETE FROM $table WHERE _ID > 0 AND _ID < 10000 $protected";
  print "status: TABLE cleanup SQL: $dd_stmt\n";
  my $rc = $dbh->do( $dd_stmt );  
  
  for my $id ( keys %$data )
    {
    next if $protected_ids{ $id };
    
    $dbio->insert( $table, { %data_default, %{ $data->{ $id }{ 'DATA' } } } );
    }
}

##############################################################################

sub find_files_for_table
{
  my $table = lc shift;
  my @res;
  
  for( de_root() . '/core', @{ de_bundles_dirs() }, de_app_dir() )
    {
    my $fn = "$_/static/$table.def";
    push( @res, glob_tree( $fn ) ) ;
    }
  return @res;
}

##############################################################################

sub load_data_file
{
  my $table   = shift;
  my $data_hr = shift;
  my $fname   = shift;

  my $dbio = new Decor::Core::DB::IO;                                                                                           

  open( my $if, '<', $fname ) or die "cannot open static data file [$fname]\n";
  
  my $c;
  my @fields;
  while(<$if>) 
    {
    chomp;
    s/^\s*//;
    s/\s*$//;
    next unless /\S/;

    my @line = parse_scsv_line( $_ );

    if( ! @fields )
      {
      @fields = @line;
      next;
      }  

    next unless @fields;

    $c++;  
    my %data;
    for my $field ( @fields )
      {
      $data{ 'DATA' }{ uc $field } = shift @line;
      }

    if( $data{ 'DATA' }{ '_ID' } =~ s/^!// )
      {
      $data{ 'PROTECTED' } = 1;
      }

    if( ! exists $data{ 'DATA' }{ '_ID' } or $data{ 'DATA' }{ '_ID' } == 0 )
      {
      my $new_id = $dbio->get_next_table_id( $table );                                                                              
      print "requested new _ID [$new_id]\n";
      $data{ 'DATA' }{ '_ID' } = $new_id;
      }

    $data_hr->{ $data{ 'DATA' }{ '_ID' } } = \%data;
    }
  close( $if );
  
  return $c;
}

sub parse_scsv_line
{
  my $line = shift;
  
  my @line = split( /(?<!\\);/, $line );
  s/\\;/;/ for @line;
  s/^\s*(['"]?)(.*?)\1\s*$/$2/ for @line;
  
  return @line;
}

##############################################################################

=pod



FIELD,FIELD,FIELD
P,asd,asd,asd


=cut
