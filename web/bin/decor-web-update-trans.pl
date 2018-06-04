#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Tie::IxHash;
use Data::Dumper;
use Data::Tools;

use Decor::Shared::Utils;

my $ROOT = $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor';

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 3;

my $opt_app_name;
my $opt_lang;
my $opt_verbose;
my $opt_tdir;
my $DEBUG;

our $help_text = <<END;
usage: $0 <options> application_name language
options:
    -v        -- verbose output
    -t dir    -- target output directory (optional)
    -d        -- debug mode, can be used multiple times to rise debug level
    --        -- end of options
notes:
  * "language" must be two-letter language id
  * options cannot be grouped: -vd is invalid, correct is: -v -d
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
  if( /^-d/ )
    {
    my $level = ++$DEBUG;
    print "option: debug level raised, now is [$level] \n";
    next;
    }
  if( /^-t/ )
    {
    my $opt_tdir = shift;
    print "option: target directory set to [$opt_tdir] \n";
    next;
    }
    
  if( /^-v/ )
    {
    $opt_verbose = 1;
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $help_text;
    exit;
    }
  push @args, $_;
  }

my $opt_app_name =    shift @args;
my $opt_lang     = lc shift @args;

die $help_text unless de_check_name( $opt_app_name ) and -d "$ROOT/apps/$opt_app_name";
die $help_text unless $opt_lang =~ /^[a-z][a-z]$/;

my $TDIR = $opt_tdir || "$ROOT/apps/$opt_app_name/trans/";
$TDIR .= "/$opt_lang";

dir_path_ensure( $TDIR ) or die "error: cannot nesure directory existence for [$TDIR]\n";


my @dirs = ( 
             "$ROOT/web/html/default/*.html", 
             "$ROOT/web/actions/*.pm", 
             "$ROOT/apps/$opt_app_name/web/html/default/*.html", 
             "$ROOT/apps/$opt_app_name/web/actions/*.pm",
           );

my @files;

push @files, glob_tree( $_ ) for @dirs;

#print Dumper( \@files );



for my $file ( @files )
  {
  print "$file\n";
  update_trans( $file, "web" );
  }

sub update_trans
{
  my $fname = shift; # file to load
  my $tname = shift; # trans file name to update

  my $tfile = "$TDIR/$tname.tr";
  my $tr = tr_hash_load( $tfile ) || {};

#print Dumper( $fname, $tr );

#  tie %$tr, 'Tie::IxHash';

  my $fdata = file_load( $fname );
  for( $fdata =~ /\<~([^\<\>]*)\>/g, $fdata =~ /\[~([^\[\]]*)\]/g )
    {
    next if exists $tr->{ $_ };
    $tr->{ $_ } = $_;
    }

  tr_hash_save( $tfile, $tr );
}

### EOF ######################################################################
