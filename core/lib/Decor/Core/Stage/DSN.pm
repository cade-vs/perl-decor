##############################################################################
##
##  Decor stagelication machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Stage;
use strict;

### DATA SOURCE NAMES SUPPORT AND DB HANDLERS ################################

sub __dsn_parse_config
{
}

sub dsn_get_dbh_by_name
{
  my $self  =    shift;
  my $name  = uc shift;

}

sub dsn_get_dbh_by_table
{
  my $self  =    shift;
  my $table = uc shift;
  
  
}

### EOF ######################################################################
1;
