##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::set_val;
use strict;
use Web::Reactor::HTML::Utils;
use Web::Reactor::HTML::Layout;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Data::Dumper;

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $table  = $reo->param( 'TABLE' );
  my $fname  = $reo->param( 'FNAME' );
  my $id     = $reo->param( 'ID'    );
  my $value  = $reo->param( 'VALUE' );
  my $vtype  = $reo->param( 'VTYPE' ); # view type


  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );

  my $res = $core->update( $table, { $fname => $value }, { ID => $id } );

  my $data = $core->read_field( $table, $fname, $id );

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( [ $fname ], $tdes, \%bfdes, \%lfdes, \%basef );
  my $lfdes     = $lfdes{ $fname };
  
  my $data_fmt  = de_web_format_field( $data, $lfdes, $vtype, { ID => $id } );
  
  $text = $data_fmt;
  
  return $text;
}

1;
