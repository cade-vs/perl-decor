##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record::User;
use strict;

use Exception::Sink;
use Data::Tools;

use Decor::Core::Env;
use Decor::Core::DB::Record;

use parent 'Decor::Core::DB::Record';

### DE_USERS api interface ###################################################

sub get_file_name
{
  my $self   = shift;

  my $root   = de_root();
  my $table  = lc $self->table();
  my $id     =    $self->id();
  my $name = $self->read( 'NAME' );
  $name =~ s/[^A-Z_\-0-9]+/_/g;
  my $path  = "$root/var/core/$app_name/files/$table";
  dir_path_ensure( $path ) or boom "cannot find/access FILES dir [$path] for table [$table] ID [$id] file name [$name]";
  my $fname = "$path/$id\_$name";

  return $fname;
}



### EOF ######################################################################
1;
