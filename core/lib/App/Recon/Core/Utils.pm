##############################################################################
##
##  App::Recon application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recon::Core::Utils;
use strict;

use Exception::Sink;
use App::Recon::Core::Env;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                reu_check_name
                reu_check_name_boom
                reu_reload_config

                );

##############################################################################

sub reu_check_name
{
  my $name = shift;
  
  return $name =~ /^[a-zA-Z_0-9]+$/ ? 1 : 0;
}

sub reu_check_name_boom
{
  my $name = shift;
  my $msg  = shift || "invalid NAME: [$name]";
  
  reu_check_name( $name ) or boom $msg;
}

sub reu_reload_config
{
  %RED_CONFIG = ();
  if( @RED_CONFIG_FILES > 0 )
    {
    red_merge_config( $_ ) for @RED_CONFIG_FILES;
    }
  else
    {
    red_merge_config( $_ ) for sort glob "$RED_ROOT/etc/env*.def";
    if( $RED_APP_NAME )
      {
      red_merge_config( $_ ) for sort glob "$RED_ROOT/apps/$RED_APP_NAME/etc/env*.def";
      }
    }
};

### EOF ######################################################################
1;
