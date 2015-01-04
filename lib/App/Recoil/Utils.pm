##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil::Utils;
use strict;

use Exception::Sink;
use App::Recoil::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_check_name
                red_check_name_boom
                red_reload_config

                );

##############################################################################

sub red_check_name
{
  my $name = shift;
  
  return $name =~ /^[a-zA-Z_0-9]+$/ ? 1 : 0;
}

sub red_check_name_boom
{
  my $name = shift;
  
  red_check_name( $name ) or boom "invalid NAME: [$name]";
}

sub red_reload_config
{

  %RED_CONFIG = ();
  if( @RED_CONFIG_FILES > 0 )
    {
    red_merge_config( $_ ) for @RED_CONFIG_FILES;
    }
  else
    {
    red_merge_config( $_ ) for sort glob "$RED_ROOT/etc/env*.def";
    red_merge_config( $_ ) for sort glob "$ENV{HOME}/.recoil/etc/env*.def";
    if( $RED_APP_NAME )
      {
      red_merge_config( $_ ) for sort glob "$RED_ROOT/apps/$RED_APP_NAME/etc/env*.def";
      }
    }
};

### EOF ######################################################################
1;
