##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::DB::Record::File;
use strict;

use Exception::Sink;
use Data::Tools;

use Decor::Core::Env;
use Decor::Core::DB::Record;

use parent 'Decor::Core::DB::Record';

### DE_FILE api interface ####################################################

sub get_file_name
{
  my $self   = shift;

  my $root     = de_root();
  my $app_name = de_app_name();
  
  my $table  = lc $self->table();
  my $id     =    $self->id();
  my $name   = $self->read( 'NAME' );
  my $sfname = $self->read( 'SYS_FNAME' );
  my $ext    = $1 if $name =~ s/\.([a-z_0-9]+)$//i;

  # FIXME: absolute SYS_FNAME: second value is NAME without extension, not the short name, and wantarray is ignored,
  #        sub_file_save() then saves SYS_FNAME as the bare NAME, sub_file_load() (scalar context) gets the bare NAME as file path
  return ( $sfname, $name ) if substr( $sfname, 0, 1 ) eq '/';

  $name =~ s/[^A-Z_\-0-9]+/_/gi;
  my $path  = "$root/var/core/$app_name/files/$table";
  dir_path_ensure( $path ) or boom "cannot find/access FILES dir [$path] for table [$table] ID [$id] file name [$name]";
  # fixme:to-be-reviewed files stored earlier without extension end with a dot (e.g. 60 in rdx/audit_files) and will not be found
  my $dext  = $ext ne '' ? ".$ext" : ''; # no trailing dot for names without extension
  my $fname = "$path/$id.$name$dext";
  my $short = "$table/$id.$name$dext";

  return wantarray ? ( $fname, $short ) : $fname;
}


### EOF ######################################################################
1;
