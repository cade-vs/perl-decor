##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  Web::Reactor application machinery
##  2013-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Web::Reactor::Actions::Decor;
use strict;
use Exception::Sink;
use Web::Reactor::Actions;
use Data::Dumper;

use parent 'Web::Reactor::Actions';

# calls an action (function) by name
# args:
#       name   -- function/action name
#       %args  -- array used as named hash arguments
# args hash keys:
#       ARGS   -- hash reference of attributes/arguments passed to the action
# returns:
#       result text to be replaced in output
sub call
{
  my $self  = shift;

  my $name = lc shift;
  my %args = @_;

  die "invalid action name, expected ALPHANUMERIC, got [$name]" unless $name =~ /^[a-z_\-0-9]+$/;

  my $ap = $self->__find_act_pkg( $name );

#  print STDERR Dumper( $name, $ap, \%args );

  if( ! $ap )
    {
    boom "action package for action name [$name] not found";
    return undef;
    }

  # FIXME: move to global error/log reporting
  print STDERR "reactor::actions::call [$name] action package found [$ap]\n";

  my $cr = \&{ "${ap}::main" }; # call/function reference

  my $data;

  $data = $cr->( $self->get_reo(), %args );

  # print STDERR "reactor::actions::call result: $data\n";

  return $data;
}

sub __find_act_pkg
{
  my $self  = shift;

  my $name = lc shift;
  
  my $act_cache = $self->{ 'ACT_PKG_CACHE' };
  
  return $act_cache->{ $name } if exists $act_cache->{ $name };

  my $app_name = lc $self->{ 'ENV' }{ 'APP_NAME' };
  my $dirs = $self->{ 'ENV' }{ 'ACTIONS_DIRS' } || [];
  
  my $found;
  for my $dir ( @$dirs )
    {
    my $file = "$dir/$name.pm"; # TODO: subdirs?
    next unless -e $file;
    $found = $file;
    last;
    }

  $act_cache->{ $name } = undef;

  return unless $found;

  my $ap = 'decor::actions::' . $name;

  eval
    {
    require $found;
    };
  if( ! $@ )  
    {
    print STDERR "LOADED! action: $ap [$found]\n";
    $act_cache->{ $name } = $ap;
    return $ap;
    }
  elsif( $@ =~ /Can't locate $found/)
    {
    print STDERR "NOT FOUND: action: $ap [$found]\n";
    }
  else
    {
    print STDERR "ERROR LOADING: action: $ap: $@ [$found]\n";
    }  

  return undef;
}

##############################################################################
1;
###EOF########################################################################

