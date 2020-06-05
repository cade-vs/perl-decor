##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Web::Grid;
use strict;
use Data::Dumper;
use Exception::Sink;
use Time::JulianDay;
use Data::Tools::Time;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(

                de_web_grid_backlink_detach_attach_icon

                );

sub de_web_grid_backlink_detach_attach_icon
{
  my $reo    = shift;
  my $core   = shift;
  
  my $table  = shift;
  my $fname  = shift;
  my $id     = shift;
  my $pa_id  = shift; # parent record id
  my $value  = shift;


  my $tdes = $core->describe( $table );
  
  my ( $detach_link_cue, $detach_link_cue_hint ) = de_web_get_cue( $tdes->{ 'FIELD' }{ $fname }, qw( WEB GRID DETACH_LINK_CUE   ) );
  my ( $attach_link_cue, $attach_link_cue_hint ) = de_web_get_cue( $tdes->{ 'FIELD' }{ $fname }, qw( WEB GRID ATTACH_LINK_CUE   ) );

  my $text; 

  my %args = ( 'TABLE' => $table, 'FNAME' => $fname, 'ID' => $id, 'PA_ID' => $pa_id, 'VALUE' => $value );
  if( $value > 0 )
    {
    # $text .= de_html_alink_icon( $reo, 'new', "detach.svg",  { CLASS => 'plain', HINT => $detach_link_cue_hint, CONFIRM => '[~Are you sure you want to DETACH this record from the parent record?]' }, _AN => 'link_attach_detach', ITYPE => 'mod', %args );
    $text .= de_html_alink_icon( $reo, 'new', "detach.svg",  { CLASS => 'plain', HINT => $detach_link_cue_hint, }, _AN => 'link_attach_detach', ITYPE => 'mod', %args );
    }
  else
    {
    $text .= de_html_alink_icon( $reo, 'new', "attach.svg",  { CLASS => 'plain', HINT => $attach_link_cue_hint, }, _AN => 'link_attach_detach', ITYPE => 'act', %args );
    }  

  return $text;
}


1;
