#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use Cwd qw( abs_path getcwd );
use Data::Tools;

my $USAGE = <<END;

usage: $0  decor-root  decor-app-name  target-http-dir

NOTES:
       decor-root can be 'a' or 'auto' to auto-sense the root directory

END

die $USAGE unless @ARGV == 3;
  
# bit nonsense but keeping it to be the same in all tools
my $root = shift();
$root = ( strip_script_name( $0 ) . "/../" || '/usr/local/decor/' ) if $root =~ /^a(uto)?$/;
$root = abs_path( "$root/" );

print "USING DECOR ROOT FOR SETUP: $root\n";

die "ERROR: NOT A DECOR ROOT: $root\n" unless -d "$root/core" and -d "$root/shared" and -d "$root/web";

my $easy_dir = "$root/easy";
my $easy_lib = "$root/easy/lib";

my $app    = shift;
my $target = shift;

my $app_dir  = find_app_dir( $root, $app );
my $psgi_dir = "$app_dir/web/psgi/";

die "decor app [$app] does not exist or is not accessible at [$app_dir]\n$USAGE" unless -d $app_dir;
die "target http dir [$target] does not exist or is not accessible\n$USAGE" unless -d $target;

print "WILL SETUP CGI FOR APP [$app] INTO HTTP DIR [$target]...\n\n";

dir_path_ensure( $psgi_dir ) or die "cannot access app [$app] psgi dir [$psgi_dir] $!";

install_template( "$root/bin/index.psgi.easy.template", "$psgi_dir/app.psgi" );
install_template( "$root/bin/index.x.easy.template",    "$target/index.x", 0755 );
install_template( "$root/bin/index.x.easy.template",    "$target/login.x", 0755 );

chdir( $target ) or die "cannot access target http dir [$target] $!";

if( ! -e 'i'  and -e "$app_dir/web/htdocs/i" )
  {
  symlink( "$app_dir/web/htdocs/i", 'i' ) or die $!;
  }

if( ! -e 'ii' and -e "$app_dir/web/htdocs/ii" )
  {
  symlink( "$app_dir/web/htdocs/ii", 'ii' ) or die $!;
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

sub strip_script_name
{
  my $s = shift;
  $s =~ s/[^\/]+$//;
  return $s;
}

sub find_app_dir
{
  my $ROOT     = shift;
  my $APP_NAME = shift;
  # TODO: move app dir entirely out of decor dir structure
  for( "$ROOT/apps/$APP_NAME", "$ROOT/apps/$APP_NAME-app-decor", "$ROOT/apps/decor-app-$APP_NAME" )
    {
    return $_ if -d 
    }
  return undef;
}

sub install_template
{
  my $src  = shift;
  my $dst  = shift;
  my $mode = shift;
  
  my $tt = file_load( $src );
  
  $tt =~ s/\[--DECOR_ROOT--\]/$root/g;
  $tt =~ s/\[--DECOR_APP_ROOT--\]/$app_dir/g;
  $tt =~ s/\[--DECOR_APP--\]/$app/g;

  if( -e $dst )
    {
    print "NOTE: destination file [$dst] exists, will not overwrite.\n";
    }
  else
    {  
    file_save( $dst, $tt ) or die "cannot save [$dst] $!";
    print "[$src] --> [$dst]\n";
    }

  chmod( $mode, $dst ) if $mode;
}
