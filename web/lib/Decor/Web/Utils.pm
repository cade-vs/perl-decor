##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::Utils;
use strict;

use Exception::Sink;
use Data::Tools;
use Web::Reactor::HTML::Utils;
use Decor::Web::View;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_web_handle_redirect_buttons
                
                de_web_get_cue
                
                );

##############################################################################

sub de_web_handle_redirect_buttons
{
  my $reo   = shift; # web::reactor object

  my $button    = $reo->get_input_button();
  return unless $button eq 'REDIRECT';

  my $button_id = $reo->get_input_button_id();
  my $ps        = $reo->get_page_session();

  if( ! exists $ps->{ 'BUTTON_REDIRECT' }{ $button_id } )
    {
    my $psid        = $reo->get_page_session_id();
    my $usid        = $reo->get_user_session_id();
    $reo->log( "error: requesting unknown REDIRECT [$button_id] usid [$usid] psid [$psid]" );
    return undef;
    }
    
  return $reo->forward_type( @{ $ps->{ 'BUTTON_REDIRECT' }{ $button_id } } );  
}

##############################################################################

sub de_web_get_cue
{
  my $des_obj = shift;
  
  my $cue = $des_obj->get_attr( @_ );
  if( ! $cue and ! $des_obj->is_self_category() )
    {
#use Data::Dumper;
#print STDERR Dumper( '+-*-' x 200, $des_obj->is_self_category(), $des_obj );

    $cue = $des_obj->get_self_des()->get_attr( @_ );
    }
  
  my @cue = split /\s*;\s*/, $cue;
  
  s/%t/$des_obj->get_label()/gie for @cue;
  
  if( wantarray() )
    {
    if( @cue > 1 )
      {
      return @cue[ 0 ] if $cue[ 1 ] eq '-';
      return @cue[ 0, 1 ];
      }
    else
      {
      return @cue[ 0, 0 ];
      }  
    }
  else
    {
    return $cue[ 0 ];
    }  
}

### EOF ######################################################################
1;
