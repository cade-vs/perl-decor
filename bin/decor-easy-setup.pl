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
  
my $root = shift() || strip_script_name( $0 ) . "/../" || '/usr/local/decor/';
$root = abs_path( "$root/" );

print "USING DECOR ROOT FOR SETUP: $root\n";

die "ERROR: NOT A DECOR ROOT: $root\n" unless -d "$root/core" and -d "$root/shared" and -d "$root/web";

chdir( $root ) or die "cannot chdir to decor root [$root] $!\n";
system( "git pull origin master" );

my $easy_dir = "$root/easy";
my $easy_lib = "$root/easy/lib";
my $easy_var = "$root/easy/var";

#die "please remove existing [$easy_dir] first\n" if -d $easy_dir;

mkdir( $easy_dir ) unless -d $easy_dir;
mkdir( $easy_lib ) unless -d $easy_lib;

chdir( $easy_dir ) or die "cannot create or chdir to [$easy_dir] $!\n";

mkdir( $easy_var ) unless -d $easy_var;
chmod( 01777, $easy_var );

-d $easy_var or die "cannot create [$easy_var] $!\n";

for my $pmod ( qw( perl-web-reactor perl-data-tools perl-exception-sink js-vframe ) )
  {
  print "\n\nUPDATING GIT REPO: $pmod...\n\n";
  
  system( "git clone https://github.com/cade-vs/$pmod.git"    ) unless -d $pmod;
  chdir( $pmod );
  system( "git checkout master" );
  system( "git pull origin master" );
  chdir( '..' );
  }


print "\n\nCREATING SYMLINKS...\n\n";

chdir( $easy_lib ) or die "cannot create or chdir to [$easy_lib] $!\n";

if( ! -e 'Web' )
  {
  symlink( "$easy_dir/perl-web-reactor/lib/Web",          'Web'       ) or die $!;
  }
  
if( ! -e 'Data' )
  {
  symlink( "$easy_dir/perl-data-tools/lib/Data",          'Data'      ) or die $!;
  }
  
if( ! -e 'Exception' )
  {
  symlink( "$easy_dir/perl-exception-sink/lib/Exception", 'Exception' ) or die $!;
  }
  



print <<END;


Decor Easy Setup Done.

you should export:

    export DECOR_CORE_ROOT="$root"
    export PERLLIB="\$PERLLIB:$easy_lib"

to install http index.cgi use:

    $root/bin/decor-easy-cgi-install.pl  $root  app-name  target-http-dir

END

sub strip_script_name
{
  my $s = shift;
  $s =~ s/[^\/]+$//;
  return $s;
}
