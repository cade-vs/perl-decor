##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
##
##  Web::Reactor application machinery
##  2013-2017 (c) Vladi Belperchinov-Shabanski "Cade"
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

  my $reo = $self->get_reo();
  
  if( $name !~ /^[a-z_\-0-9]+$/ )
    {
    $reo->log( "error: invalid action name [$name] expected ALPHANUMERIC" );
    return undef;
    }

  my $cr = $self->__load_action_file( $name );

  if( ! $cr )
    {
    $reo->log( "error: cannot load action [$name]" );
    return undef;
    }

  my $data;
  
  eval
    {
    $data = $cr->( $reo, %args );
    };
  if( $@ )  
    {
    $reo->log( "error: call decor action failed: $name(%args): $@" );
    return undef;
    }

  return $data;
}

sub __load_action_file
{
  my $self  = shift;

  my $name = shift;

  my $reo = $self->get_reo();
  my $cfg = $self->get_cfg();
  
  my $cr = $self->{ 'ACT_CODE_CACHE' }{ $name };
  
  return $cr if $cr;
  
  my $dirs = $cfg->{ 'ACTIONS_DIRS' } || [];
  
  my $found;
  for my $dir ( @$dirs )
    {
    my $file = "$dir/$name.pm"; # TODO: subdirs?
    next unless -e $file;
    $found = $file;
    last;
    }

  return undef unless $found;

  my $ap = 'decor::actions::' . $name;

  eval
    {
    delete $INC{ $found };
    require $found;
    };

  if( ! $@ )  
    {
    $reo->log_debug( "status: load action ok: $ap [$found]" );
    $self->{ 'ACT_CODE_CACHE' }{ $name } = $cr = \&{ "${ap}::main" }; # call/function reference
    return $cr;
    }
  elsif( $@ =~ /Can't locate $found/)
    {
    $reo->log( "error: action not found: $ap [$found]" );
    }
  else
    {
    $reo->log( "error: load action failed: $ap: $@ [$found]" );
    }  

  return undef;
}

##############################################################################
1;
###EOF########################################################################

