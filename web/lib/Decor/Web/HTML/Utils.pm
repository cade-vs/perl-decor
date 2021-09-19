##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
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
                de_html_alink_button_fill
                de_html_alink_icon

                de_html_popup
                de_html_popup_icon

                );

##############################################################################

sub de_html_form_button_redirect
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $form  = shift; # web::reactor::html::form object
  my $value = shift; # button text
  my $hint  = shift; # button hover hint
  my %args  = @_;    # redirect data

  my $button_id = uc( $args{ 'BUTTON_ID' } || $reo->html_new_id() ); # button name, random, unique
#  my $href = $reo->args_type( $type, @args );

  my $opt = ref( $hint ) eq 'HASH' ? $hint : { HINT => $hint };

  my $hint     = $opt->{ 'HINT'     };
  my $disabled = $opt->{ 'DISABLED' };

  my $hl_handle = html_hover_layer( $reo, VALUE => $hint, DELAY => 1000 ) if $hint;

  my $ps = $reo->get_page_session();

  $ps->{ 'BUTTON_REDIRECT' }{ $button_id } = [ $type, %args ];

  my $args;

  $args .= " $hl_handle ";

  my $btype = $args{ 'BTYPE' };
  $btype = "$btype-button" if $btype;

  my $text;

  if( $value =~ /([a-z_0-9]+\.(png|jpg|jpeg|gif|svg))/ )
    {
    $text .= $form->image_button( NAME => "REDIRECT:$button_id", SRC => "i/$value", CLASS => "icon $btype", DISABLED => $disabled, ARGS => $args );
    }
  else
    {
    $text .= $form->button( NAME => "REDIRECT:$button_id", VALUE => $value, CLASS => "button $btype", DISABLED => $disabled, ARGS => $args );
    }

  return $text;
}

sub __value_image_fix
{
  my $value =    shift;
  my %args  = @_;
  my $class = $args{ 'CLASS' } || 'icon';
  #$value = "<img class=icon src=i/$value>" if $value =~ /^[a-z_0-9]+\.(png|jpg|jpeg|gif)$/i;
  $value =~ s/^([a-z_\-0-9]+\.(png|jpg|jpeg|gif|svg))/<img class='$class' src=i\/$1>/g;
  return $value;
}

sub de_html_alink
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my %args  = @_;

  $value = __value_image_fix( $value );
  
  my $opt = ref( $hint ) eq 'HASH' ? $hint : { HINT => $hint };

  return html_alink( $reo, $type, $value, $opt, %args );
}

sub de_html_alink_block
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my %args  = @_;

  $value = __value_image_fix( $value );

  return html_alink( $reo, $type, $value, { HINT => $hint, CLASS => 'block' }, %args );
}

sub de_html_alink_button
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my %args  = @_;

  $value = __value_image_fix( $value );

  my $opt = ref( $hint ) eq 'HASH' ? { %$hint } : { HINT => $hint };

  my $btype = $opt->{ 'BTYPE' } || $args{ 'BTYPE' };
  $btype = "$btype-button" if $btype;

  $opt = { %$opt, CLASS => "button $btype" };

  return html_alink( $reo, $type, $value, $opt, %args );
}

sub de_html_alink_button_fill
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my %args  = @_;

  $value = __value_image_fix( $value );

  my $opt = ref( $hint ) eq 'HASH' ? { %$hint } : { HINT => $hint };

  my $btype = $opt->{ 'BTYPE' } || $args{ 'BTYPE' };
  $btype = "$btype-button" if $btype;

  $opt = { %$opt, CLASS => "button $btype fill" };

  return html_alink( $reo, $type, $value, $opt, %args );
}

sub de_html_alink_icon
{
  my $reo   = shift; # web::reactor object
  my $type  = shift; # redirect type: new, back, here, none
  my $value = shift; # link text
  my $hint  = shift; # link hover hint
  my %args  = @_;

  # TODO: FIXME: fix the opt/args mess here!

  my $itype = $args{ 'ITYPE' };
  $itype = "$itype-icon" if $itype;

  $value = __value_image_fix( $value, CLASS => "icon $itype" );

  my $opt = ref( $hint ) eq 'HASH' ? { CLASS => "plain", %$hint } : { HINT => $hint, CLASS => "plain" };

  return html_alink( $reo, $type, $value, $opt, %args );
}

sub de_html_popup
{
  my $reo   = shift; # web::reactor object
  my $value = shift; # link text
  my $popup = shift; # popup text


  if( wantarray )
    {
    my ( $handle, $popup_html ) = html_popup_layer( $reo, VALUE => $popup, TYPE => 'CLICK' );
    return ( "<div $handle>$value</div>", $popup_html );
    }
  else
    {
    my $handle = html_popup_layer( $reo, VALUE => $popup, TYPE => 'CLICK' );
    return "<div $handle>$value</div>";
    }  
}

sub de_html_popup_icon
{
  my $reo   = shift; # web::reactor object
  my $value = shift; # link text
  my $popup = shift; # popup text


  if( wantarray )
    {
    my ( $handle, $popup_html ) = html_popup_layer( $reo, VALUE => $popup, TYPE => 'CLICK' );
    return ( "<img class='icon' src='i/$value' $handle>", $popup_html );
    }
  else
    {
    my $handle = html_popup_layer( $reo, VALUE => $popup, TYPE => 'CLICK' );
    return "<img class='icon' src='i/$value' $handle>";
    }  
}


### EOF ######################################################################
1;
