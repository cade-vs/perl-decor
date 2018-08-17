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

use Term::ReadKey;
use Decor::Core::Env;
use Decor::Core::Log;
use Decor::Core::Describe;
use Decor::Core::DB::Record;
use Decor::Core::DB::IO;
use Decor::Shared::Utils;
use Data::Tools;

use Data::Dumper;

#print Dumper( [ parse_scsv_line( qq[; '  123'  ;testing   ;this\\;is it; "asd";qwe] ) ] );
#die;

our $help_text = <<END;
usage: $0 <options> application_name table files
options:
    -v        -- verbose output
    -d        -- debug mode, can be used multiple times to rise debug level
    -r        -- log to STDERR
    -rr       -- log to both files and STDERR
    --        -- end of options
notes:
  * first argument is application name and it is mandatory!
  * options cannot be grouped: -rd is invalid, correct is: -r -d
END

my $opt_verbose;

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
    
  if( /^-v/ )
    {
    $opt_verbose = 1;
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

de_init( APP_NAME => $opt_app_name );

my $table = lc shift @args;

my @files = @args;

my $data = {};

load_data_file( $table, $data, $_ ) for @files;

print Dumper( $data );

=pod

my $file  = shift @args;

my $ucolumn = lc $opt{'ucolumn'} || '_id';

open( my $if, "< :encoding(UTF-8)", $file ) or die "CANT OPEN DATA FILE $file";

my $c;
my @r; # row data
my @f; # fields

while ( <$if> ) {

    chomp;

    if ( !$c ) {
        @f = split( /(?<=\\);/, $_ );
        s/// for @f;
        $c += 1;
        next;
    }

    @r = split(';',$_);

    next unless @r;
    
    my $rec = new Decor::Core::DB::Record;

    my %rowData;

    for my $fl ( @f ) {
        $rowData{lc $fl} = shift @r;
    }


    print "ROW $c DATA === ".Dumper(\%rowData);

    $rec->select($table, "$ucolumn = ?", {BIND => [$rowData{lc $ucolumn}] });
    $rec->create($table) unless $rec->next();

    for my $fl ( @f ) {
        $rec->write( $fl => $rowData{$fl} );
    }

    $rec->save();
    $rec->commit();

    $c++;
}

close( $if );
=cut
##############################################################################

sub load_data_file
{
  my $table   = shift;
  my $data_hr = shift;
  my $fname   = shift;

  my $dbio = new Decor::Core::DB::IO;                                                                                           

  open( my $if, "< :encoding(UTF-8)", $fname ) or die "cannot open static data file [$fname]\n";
  
  my $c;
  my @fields;
  while(<$if>) 
    {
    chomp;
    s/^\s*//;
    s/\s*$//;
    next unless /\S/;

    my $fields = 1 if s/^\s*=//;
    
    my @line = parse_scsv_line( $_ );
    
    if( $fields )
      {
      @fields = @line;
      next;
      }  

    next unless @fields;

    $c++;  
    my %data;
    for my $field ( @fields )
      {
      $data{ uc $field } = shift @line;
      }

    if( ! exists $data{ '_ID' } or $data{ '_ID' } == 0 )
      {
      my $new_id = $dbio->get_next_table_id( $table );                                                                              
      print "requested new _ID [$new_id]\n";
      $data{ '_ID' } = $new_id;
      }

    $data_hr->{ $data{ '_ID' } } = { %{ $data_hr->{ $data{ '_ID' } } || {} }, %data };
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
