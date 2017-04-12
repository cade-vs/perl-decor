##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Form;
use strict;

use Data::Tools;
use Exception::Sink;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Shared::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_form_gen_rec_data

                );

my %FORM_CACHE;

sub de_form_gen_rec_data
{
  my $form_name = shift;
  my $rec       = shift;
  my $data      = shift;
  my $opts      = shift;
  
  my $form_file = de_core_subtype_file_find( 'forms', 'txt', $form_name );

  my $form_text = file_load( $form_file );

  return $form_text;
}


### EOF ######################################################################
1;
