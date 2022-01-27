package decor::tables::test2;
use utf8;
use strict;
use cade::tools;

use Decor::Core::Log;

use Exception::Sink;
use Data::Dumper;

sub on_recalc
{
  my $rec = shift;

  my $name = $rec->read( 'NAME' );
#  $rec->write( 'NAME', $name . '|ю');

  de_log( "info: \n\n\n\n\n\n\n****************************** $name\n\n\n\n\n\n\n\n\n\n" );
}

sub on_access_disabled
{
  my $rec = shift;
  my $oper = shift;
  
  my $r = rand();
  print STDERR "++++++++++++++++++++++++($r)++++++$oper+++++++++++++++\n\n\n\n\n\n";
  return $r > 0.5;
}

sub on_filter_method_filter1
{
  my $hr = shift;

my $rr = $hr->{ 'NAME' } =~ /^M/;
print "++++++++++++++++++++++++++++++++(( $rr ))++++++++++++++++++$hr->{ '_ID' } [$hr->{ 'NAME' }]\n" . Dumper( $hr );

  return $rr;
}

1;
