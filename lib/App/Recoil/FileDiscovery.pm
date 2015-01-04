##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil::FileDiscovery;
use strict;

use Exception::Sink;
use Data::Tools;
use App::Recoil::Env;
use App::Recoil::Log;
use App::Recoil::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_file_find
                red_file_find_rescan
                
                red_file_find_modules_list
                red_file_def2pm
                
                );

our %RED_FILE_DISCOVERY_CACHE;

##############################################################################

sub red_file_find
{
  my $fname = lc shift; # file name
  my @loc   = map { $_ eq 'modules::' ? red_file_find_modules_list() : $_ } @_; # location ( core/global, app or in modules )        

  while( @loc )
    {
    my $loc = lc shift @loc;
    next unless exists $RED_FILE_DISCOVERY_CACHE{ $loc }{ $fname };
    return $RED_FILE_DISCOVERY_CACHE{ $loc }{ $fname };
    }
  return undef;
}

##############################################################################

sub red_file_find_modules_list
{
  my @modules = grep { /^module::/ } keys %RED_FILE_DISCOVERY_CACHE;  
  
  return @modules;
}

sub red_file_def2pm
{
  my $fname = shift;
  
  $fname =~ s/\.def$/.pm/;
  
  return $fname;
}

##############################################################################

sub red_file_find_rescan
{
  for my $dir ( qw( proto class menu ) )
    {
    __red_ff_rescan_dir( $dir );
    }
}

sub __red_ff_rescan_dir
{
  my $dir = lc shift;
  
  my @paths;
  if( $RED_APP_NAME )
    {
    __red_ff_rescan_cache_fill( "app", "$RED_ROOT/apps/$RED_APP_NAME/$dir" );
    for my $mod_path ( sort glob( "$RED_ROOT/apps/$RED_APP_NAME/modules/*" ) )
      {
      my $mod_name = $1 if $mod_path =~ /\/([^\/]+)$/;
      red_check_name_boom( $mod_name );
      __red_ff_rescan_cache_fill( "module::$mod_name", "$RED_ROOT/apps/$RED_APP_NAME/modules/$mod_name/$dir" );
      }
    }
  __red_ff_rescan_cache_fill( '::', "$RED_ROOT/$dir" );
 
}

sub __red_ff_rescan_cache_fill
{
  my $loc  = lc shift; # location ( core/global, app or in modules )        
  my $path = lc shift; # path to start from

  #print STDERR "__red_fd_rescan_cache_fill: [$key][$path]\n";
  
  my @files;
  push @files, glob_tree( "$path/*.def" );
  
  for my $file ( @files )
    {
    next unless $file =~ /\/([^\/]+)$/;
    my $fname = $1;
    if( exists $RED_FILE_DISCOVERY_CACHE{ $loc }{ $fname } )
      {
      my $org_file = $RED_FILE_DISCOVERY_CACHE{ $loc }{ $fname };
      red_log( "error: file duplicate [$file] first found at [$org_file]" );
      }
    else
      {  
      $RED_FILE_DISCOVERY_CACHE{ $loc }{ $fname } = $file;
      }
    }
}

### EOF ######################################################################
1;
