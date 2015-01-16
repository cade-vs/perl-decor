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
use App::Recoil::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_protocols_process
                red_exec_protocol
                
                );

our %RED_PROTOCOLS_CACHE;

##############################################################################

sub red_protocols_process
{
  red_log_debug( 'debug: *********** PROTOCOLS PROCESS' );
}

sub red_get_protocol
{
  my $name = lc shift;

  red_check_name_boom( $name );

  if( exists $RED_PROTOCOLS_CACHE{ $name } )
    {
    return $RED_PROTOCOLS_CACHE{ $name };
    }

  my $proto_def = red_file_find( "$name.proto.def", 'app', 'modules::', '::' );                             
  my $proto_pm  = red_file_def2pm( $proto_def );

  my $pp = 'App::Recoil::Protocols::' . $name; # proto package

  eval
    {
    require $proto_pm;
    };
  if( ! $@ )  
    {
    red_log_debug( "debug: loaded protocol [$name] from [$proto_pm]" );
    my $cr = \&{ "${pp}::main" }; # call/function reference
    $RED_PROTOCOLS_CACHE{ $name } = $cr;
    return $cr;
    }
  elsif( $@ =~ /Can't locate $proto_pm/)
    {
    print STDERR "NOT FOUND: action: $pp: $proto_pm\n";
    }
  else
    {
    print STDERR "ERROR LOADING: action: $pp: $@\n";
    }  
  
  return undef;
}

sub red_get_protocol_config
{
  my $name = lc shift;

  red_check_name_boom( $name );

  my @proto_dirs = red_dir_list_by_type_order( 'proto', [ 'root', 'mod', 'app' ] );

  my $proto_config = red_config_load( $name, \@proto_dirs );
  
  return $proto_config;
}

sub red_exec_protocol
{
  my $name = lc shift;

  red_check_name_boom( $name );

  my $proto_config = red_get_protocol_config( $name );

  my $proto_code_ref = red_get_protocol( $name );
  
  # FIXME error if !$proto_code_ref
  $proto_code_ref->() if $proto_code_ref;
}

### EOF ######################################################################
1;
