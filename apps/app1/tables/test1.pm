package decor::tables::test1;
use strict;
use cade::tools;

use Data::Dumper;

sub on_recalc
{
  my $r = shift;

  my $sum;

  $sum += $_ for $r->read( qw( AMOUNT1 AMOUNT2 AMOUNT3 ) );
  $r->write( AMOUNT4 => $sum );
  $r->write( CTIME   => time() );

  $r->method_add_field_error( 'AMOUNT4', 'Field sum cannot be less than 100' ) if $sum < 100;
  $r->method_add_field_error( 'AMOUNT4', 'Field sum cannot be above 500' ) if $sum > 500;
  $r->method_add_field_error( 'AMOUNT4', 'Field sum cannot be above 500' ) if $sum > 500;

  $r->method_add_error( 'Field sum cannot be above 500' ) if $sum > 500;
  $r->method_add_error( 'Field sum cannot be above 500' ) if $sum > 500;
  $r->method_add_error( 'Field sum cannot be above 500' ) if $sum > 500;

  print Dumper( 'RECALC-'x10, $r );
}

sub on_test
{
  print "test";
}

sub on_more
{
  print "more test";
}


sub on_do_date_test
{
  my $r = shift;
  
  $r->write( 'DATE_TEST' => 123 );
}

1;
