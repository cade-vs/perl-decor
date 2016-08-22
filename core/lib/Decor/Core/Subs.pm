##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Subs;
use strict;
use Exception::Sink;
use Decor::Core::Log;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                subs_process_xt_message

                );

##############################################################################

my %DISPATCH_MAP = (
                     'GLOBAL' => {
                                   'CAPS'     => \&sub_caps,
                                 },
                     'MAIN'   => {
                                   'LOGIN'    => \&sub_login,
                                 },
                     'USER'   => {
                                   'DESCRIBE' => \&sub_describe,
                                   'MENU'     => \&sub_menu,
                                   'SELECT'   => \&sub_select,
                                   'FETCH'    => \&sub_fetch,
                                   'FINISH'   => \&sub_finish,
                                   'INSERT'   => \&sub_insert,
                                   'UPDATE'   => \&sub_update,
                                   'DELETE'   => \&sub_delete,
                                   'COMMIT'   => \&sub_commit,
                                   'ROLLBACK' => \&sub_rollback,
                                   'LOGOUT'   => \&sub_logout,
                                 },
                   );

my %MAP_SHORTCUTS = (
                    'A'   => 'CAPS',
                    'LI'  => 'LOGIN',
                    'LO'  => 'LOGOUT',
                    'D'   => 'DESCRIBE',
                    'M'   => 'MENU',
                    'S'   => 'SELECT',
                    'F'   => 'FETCH',
                    'H'   => 'FINISH',
                    'I'   => 'INSERT',
                    'U'   => 'UPDATE',
                    'D'   => 'DELETE',
                    'C'   => 'COMMIT',
                    'R'   => 'ROLLBACK',
                    );

my $DISPATCH_MAP = 'MAIN';

sub subs_set_dispatch_map
{
  my $map = uc shift;
  
  boom "unknown DISPATCH MAP [$map]" unless exists $DISPATCH_MAP{ $map };
  $DISPATCH_MAP = $map;
}

sub subs_reset_dispatch_map
{
  $DISPATCH_MAP = 'MAIN';
}

sub subs_process_xt_message
{
  my $mi = shift;
  my $mo = shift;
  
  my $xt = uc $mi->{ 'XT' };

  $xt = $MAP_SHORTCUTS{ $xt } if exists $MAP_SHORTCUTS{ $xt };

  my $mapc = $DISPATCH_MAP{ $DISPATCH_MAP }; # current 
  my $mapg = $DISPATCH_MAP{ 'GLOBAL' };      # global
  boom "unknown or forbidden DMAP:XTYPE [$DISPATCH_MAP:$xt] current DMAP is [$DISPATCH_MAP]" unless exists $mapc->{ $xt } or exists $mapg->{ $xt };

  my $handle = $mapc->{ $xt } || $mapg->{ $xt };

  my $res = $handle->( $mi, $mo );
}

##############################################################################

sub sub_caps
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- LOGIN/LOGOUT ------------------------------------------------------------

sub sub_login
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_logout
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- DESCRIBE/MENU -----------------------------------------------------------

sub sub_describe
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_menu
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- SELECT/FETCH/FINISH -----------------------------------------------------

sub sub_select
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_fetch
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_finish
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- INSERT/UPDATE/DELETE ----------------------------------------------------

sub sub_insert
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_update
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_delete
{
  my $mi = shift;
  my $mo = shift;
  
};

#--- CONTROLS/COMMIT/ROLLBACK/ETC. -------------------------------------------

sub sub_commit
{
  my $mi = shift;
  my $mo = shift;
  
};


sub sub_rollback
{
  my $mi = shift;
  my $mo = shift;
  
};


### EOF ######################################################################
1;
