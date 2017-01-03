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

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_web_handle_redirect_buttons
                
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

### EOF ######################################################################
1;
