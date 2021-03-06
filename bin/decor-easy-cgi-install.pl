#!/usr/bin/perl
use strict;
use Cwd qw( abs_path getcwd );
use Data::Tools;
  
my $root = $0;
$root =~ s/[^\/]+$//; 
$root = '.' if $root eq '';

$root = abs_path( "$root/../" );

my $easy_dir = "$root/easy";
my $easy_lib = "$root/easy/lib";

my $app    = shift;
my $target = shift;

my $app_dir = "$root/apps/$app";

my $USAGE = "usage: $0  decor-app  target-http-dir\n";

die "decor app [$app] does not exist or is not accessible at [$app_dir]\n$USAGE" unless -d $app_dir;
die "target http dir [$target] does not exist or is not accessible\n$USAGE" unless -d $target;

print "WILL SETUP CGI FOR APP [$app] INTO HTTP DIR [$target]...\n\n";

my $easy_cgi_template = file_load( "$root/bin/index.cgi.easy.template" );

$easy_cgi_template =~ s/\[--DECOR_ROOT--\]/$root/g;
$easy_cgi_template =~ s/\[--DECOR_APP--\]/$app/g;

chdir( $target ) or die "cannot access targer http dir [$target] $!";

file_save( 'index.cgi', $easy_cgi_template ) unless -e 'index.cgi';

if( ! -e 'index.pl' )
  {
  symlink( "index.cgi", 'index.pl' ) or die $!;
  }

if( ! -e 'login.pl' )
  {
  symlink( "index.cgi", 'login.pl' ) or die $!;
  }

if( ! -e 'i' )
  {
  symlink( "$root/web/htdocs/i", 'i' ) or die $!;
  }

mkdir( 'js' ) unless -d 'js';

if( ! -e 'js/reactor.js' )
  {
  symlink( "$easy_dir/perl-web-reactor/htdocs/reactor.js", 'js/reactor.js' ) or die $!;
  }

if( ! -e 'js/vframe.js' )
  {
  symlink( "$easy_dir/js-vframe/vframe.js", 'js/vframe.js' ) or die $!;
  }

print "\nDONE.\n";
