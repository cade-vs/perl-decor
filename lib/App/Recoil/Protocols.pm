##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil::Protocols;
use strict;

use App::Recoil::Log;
use App::Recoil::FileDiscovery;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_protocols_process
                
                );

##############################################################################

sub red_protocols_process
{
  red_log_debug( 'debug: *********** PROTOCOLS PROCESS' );
}

sub red_get_protocol
{
  my $name = shift;

  red_check_name_boom( $name );

  # FIXME: caching!
  
  my @proto_defs;
  if( $APP_NAME )
    {
    push @proto_defs, "$ROOT/apps/$APP_NAME/protocols/$name.proto.def";
    for my $mod_name ( sort glob_tree( "$ROOT/apps/$APP_NAME/modules" ) )
      {
      push @proto_defs, "$mod_name/protocols/$name.proto.def";
      }
    }
  push @proto_defs, "$ROOT/protocols/$name.proto.def";


  
  my $proto_def = red_find_file( 
                                 "$ROOT/protocols/$name.proto.def", 
                                 "$ROOT/$APP_NAME/protocols/$name.proto.def", 
                               );
  my $proto_pm  = red_find_file( 
                                 "$ROOT/protocols/$name.proto.pm", 
                                 "$ROOT/$APP_NAME/protocols/$name.proto.pm", 
                               );
                               
                               
                               
}

### EOF ######################################################################
1;
