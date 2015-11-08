##############################################################################
##
##  App::Recon application machinery core
##  2014-2015 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package App::Recon::Core::Access;
use strict;

use Exception::Sink;

use App::Recon::Core::Env;
use App::Recon::Core::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                rs_access_set_user_groups
                rs_access_add_user_groups
                rs_access_del_user_groups
                rs_access_get_user_groups
                rs_access_clr_user_groups

                );

##############################################################################

my %USER_GROUPS;

##############################################################################

sub rs_access_set_user_groups
{
  rs_access_clr_user_groups();
  rs_access_add_user_groups( @_  );
}

sub rs_access_add_user_groups
{
  my @groups = @_;
  
  for my $group ( @groups )
    {
    $group = lc $group;
    rs_check_name_boom( $group, "invalid group name [$group]" );
    $USER_GROUPS{ $group } = 1; # fixme: group classes/types
    }
}

sub rs_access_del_user_groups
{
  my @groups = @_;
  
  for my $group ( @groups )
    {
    if( $group eq '*' )
      {
      rs_access_clr_user_groups();
      return;
      }
    $group = lc $group;
    rs_check_name_boom( $group, "invalid group name [$group]" );
    delete $USER_GROUPS{ lc $group };
    }
}

sub rs_access_get_user_groups
{
  return %USER_GROUPS;
}

sub rs_access_clr_user_groups
{
  %USER_GROUPS = ();
}

### EOF ######################################################################
1;
