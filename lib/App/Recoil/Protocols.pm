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
use App::Recoil::Config;

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
    return ( $RED_PROTOCOLS_CACHE{ $name }{ 'CONFIG' }, $RED_PROTOCOLS_CACHE{ $name }{ 'CODEREF' } );
    }

  my $proto_def_fname = red_file_find_first_by_fname_type_order( "$name.def", 'proto', [ 'app', 'mod', 'root' ] );                             
  my $proto_pm_fname  = red_file_def2pm_fname( $proto_def_fname );

  my $proto_config = red_config_load_file( $proto_def_fname );

  my $proto_package = 'App::Recoil::Protocols::' . $name;

  eval
    {
    red_log_debug( "debug: about to load protocol package [$name] from [$proto_pm_fname]" );
    require $proto_pm_fname;
    };
  if( ! $@ )  
    {
    red_log_debug( "debug: loaded protocol [$name] from [$proto_pm_fname]" );
    my $proto_coderef = \&{ "${proto_package}::main" }; # call/function reference
    $RED_PROTOCOLS_CACHE{ $name }{ 'CONFIG'  } = $proto_config;
    $RED_PROTOCOLS_CACHE{ $name }{ 'CODEREF' } = $proto_coderef;
    return ( $proto_config, $proto_coderef );
    }
  elsif( $@ =~ /Can't locate $proto_pm_fname/)
    {
    print STDERR "NOT FOUND: action: [$proto_package] $proto_pm_fname\n";
    }
  else
    {
    print STDERR "ERROR LOADING: action: [$proto_package] $@\n";
    }  
  
  return undef;
}

sub red_exec_protocol
{
  my $name = lc shift;

  red_check_name_boom( $name );

  my ( $proto_config, $proto_code_ref ) = red_get_protocol( $name );

  red_log_debug( "debug: exec protocol [$name] = ( $proto_config, $proto_code_ref )" );
  
  # FIXME error if !$proto_code_ref
  $proto_code_ref->() if $proto_code_ref;
}

### EOF ######################################################################
1;
