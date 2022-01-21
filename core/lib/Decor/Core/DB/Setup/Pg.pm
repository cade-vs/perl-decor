##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Setup::Pg;
use strict;

use parent 'Decor::Core::Base';
use Exception::Sink;

sub setup_dbh 
{
  my $self = shift;
  my $dbh  = shift;
  
  # $dbh->{ 'pq_enable_utf8' } = 1;
}  

### EOF ######################################################################
1;
