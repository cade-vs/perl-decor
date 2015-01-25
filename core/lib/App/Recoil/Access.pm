##############################################################################
##
##  App::Recoil application machinery server
##  2014 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recoil::Access;
use strict;

use Exception::Sink;
use App::Recoil::Env;
use App::Recoil::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                red_access_set_user_groups
                red_access_add_user_groups
                red_access_del_user_groups
                red_access_get_user_groups

                red_access_protocol

                );

##############################################################################

my %USER_GROUPS;

##############################################################################

sub red_access_set_user_groups
{
  red_access_del_user_groups( '*' );
  red_access_add_user_groups( @_  );
}

sub red_access_add_user_groups
{
  my @groups = @_;
  
  for my $group ( @groups )
    {
    $group = lc $group;
    red_check_name_boom( $group, "invalid group name [$group]" );
    $USER_GROUPS{ $group } = 1; # fixme: group classes/types
    }
}

sub red_access_del_user_groups
{
  my @groups = @_;
  
  for my $group ( @groups )
    {
    if( $group eq '*' )
      {
      %USER_GROUPS = ();
      return;
      }
    $group = lc $group;
    red_check_name_boom( $group, "invalid group name [$group]" );
    delete $USER_GROUPS{ lc $group };
    }
}

sub red_access_get_user_groups
{
  return %USER_GROUPS;
}


##############################################################################

sub red_access_protocol
{
  my $proto_config = shift;


  
  return $name =~ /^[a-zA-Z_0-9]+$/ ? 1 : 0;
}

### EOF ######################################################################
1;
