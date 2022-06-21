##############################################################################
##
##  Decor application machinery core
##  2014-2021 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::update_record;
use strict;

sub main
{
  my $reo = shift;

  my $table  = $reo->param( 'TABLE' );
  my $id     = $reo->param( 'ID'    );

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();

  my %ui_si = ( %$ui, %$si ); # merge inputs, SAFE_INPUT has priority
  
  while( my ( $k, $v ) = each %ui_si )
    {
    next unless $k =~ /^F:([A-Z_0-9]+)$/;
    $data{ $k } = $v;
    }

  my %data;

  my $core = $reo->de_connect();

  my $res = $core->update( $table, \%data, { ID => $id } );

  return $reo->forward_back();
}

1;
