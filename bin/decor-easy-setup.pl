#!/usr/bin/perl
use strict;
use Cwd qw( abs_path getcwd );
  
my $root = $0;
$root =~ s/[^\/]+$//; 
$root = '.' if $root eq '';

$root = abs_path( "$root/../" );

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
  
  system( "git clone git://github.com/cade-vs/$pmod.git"    ) unless -d $pmod;
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

    $root/bin/decro-easy-cgi-install.pl  app-name  target-http-dir

otherwise to manually install http index.cgi:

create http/apache web dir, for example:

    /var/www/html/decor

--------------------------------------------------------------------
    
copy:
        $easy_dir/perl-web-reactor/htdocs/reactor.js
        $easy_dir/js-vframe/vframe.js
to:
        /var/www/html/decor/js/
    
--------------------------------------------------------------------

copy or symlink directory:
        $root/web/htdocs/i
as:
        /var/www/html/decor/i


END
