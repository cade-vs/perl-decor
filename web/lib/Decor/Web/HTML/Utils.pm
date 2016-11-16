##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::HTML::Utils;
use strict;

use Exception::Sink;
use Data::Tools;
use Web::Reactor::HTML::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_html_alink_block
                de_html_alink_button

                );

##############################################################################

sub __value_image_fix
{
  my $value =    shift;
  $value = "<img src=i/$value>" if $value =~ /^[a-z_0-9]+\.(png|jpg|jpeg|gif)$/i;
  return $value;
}

sub de_html_alink_block
{
  my $reo   =    shift;
  my $type  = lc shift;
  my $value =    shift;
  my $hint  =    shift;
  my @args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint, CLASS => 'block' }, @args );
}

sub de_html_alink_button
{
  my $reo   =    shift;
  my $type  = lc shift;
  my $value =    shift;
  my $hint  =    shift;
  my @args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint, CLASS => 'button' }, @args );
}

### EOF ######################################################################
1;
