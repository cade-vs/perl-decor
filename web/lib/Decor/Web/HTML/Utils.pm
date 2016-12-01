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

                de_html_form_button_redirect
                
                de_html_alink
                de_html_alink_block
                de_html_alink_button
                de_html_alink_icon

                );

##############################################################################

sub de_html_form_button_redirect
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $form  = shift; # web::reactor::html::form object
  my $name  = shift; # button name
  my $value = shift; # button text
  my $hint  = shift; # button hover hint
  my @args  = @_;    # redirect data

#  my $href = $reo->args_type( $type, @args );

  my $hl_handle = html_hover_layer( $reo, VALUE => $hint, DELAY => 250 ) if $hint;

  my $ps = $reo->get_page_session();

  $ps->{ 'BUTTON_REDIRECT' }{ $name } = [ $type, @args ];

  my $args;
  
  $args .= " $hl_handle ";

  my $text;

  $text .= $form->button( NAME => "REDIRECT:$name", VALUE => $value, ARGS => $args );
  
  return $text;
}

sub __value_image_fix
{
  my $value =    shift;
  #$value = "<img class=icon src=i/$value>" if $value =~ /^[a-z_0-9]+\.(png|jpg|jpeg|gif)$/i;
  $value =~ s/([a-z_0-9]+\.(png|jpg|jpeg|gif))/<img class=icon src=i\/$1>/g;
  return $value;
}

sub de_html_alink
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my @args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint }, @args );
}

sub de_html_alink_block
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my @args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint, CLASS => 'block' }, @args );
}

sub de_html_alink_button
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my @args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint, CLASS => 'button' }, @args );
}

sub de_html_alink_icon
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my @args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint, CLASS => 'icon' }, @args );
}

### EOF ######################################################################
1;
