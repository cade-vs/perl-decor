##############################################################################
##
##  Decor stagelication machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Types::Native;
use strict;

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;

use DateTime;

use Date::Format;
use Date::Calc;
use Time::JulianDay;
use DateTime::Format::Strptime;
use Hash::Util qw( lock_hashref unlock_hashref lock_ref_keys );

my %DEFAULT_FORMATS = (
                        'DATE'  => "%Y.%m.%d",
                        'TIME'  => "%H:%M:%S",
                        'UTIME' => "%Y.%m.%d %H:%M:%S %z",
                        'TZ'    => '', # local machine TZ if empty
                      );
sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my %args = @_;
  
  my $self = {
             };
  bless $self, $class;

  $self->reset_formats();
  
#  de_obj_add_debug_info( $self );
  return $self;
}

sub set_format
{
  my $self = shift;
  my $type = shift; # hashref with type args
  my $fmt  = shift; # format string
  
  my $type_name = $type->{ 'NAME' };
  
  $self->{ 'FORMATS' }{ $type_name } = $fmt;
  
  return $fmt;
}

sub get_format
{
  my $self = shift;
  my $type = shift; # hashref with type args

  my $type_name = $type->{ 'NAME' };
  
  return $self->{ 'FORMATS' }{ $type_name };
}

sub reset_formats
{
  my $self = shift;

  $self->{ 'FORMATS' } = { %DEFAULT_FORMATS },
  lock_ref_keys( $self->{ 'FORMATS' } );

  return 1;
}

# converts from decor internal data to human/visible format
sub format
{
  my $self = shift;
  my $data = shift;
  my $type = shift; # hashref with type args

  my $type_name = $type->{ 'NAME' };

  if( $type_name eq "DATE" )
   {
   if ( $data >= 0 )
     {
     my ( $y, $m, $d ) = inverse_julian_day( $data );

     my @t = ( undef, undef, undef, $d, $m - 1, $y - 1900 );

     return strftime( $self->{ 'FORMATS' }{ 'DATE' }, @t );
     }
   else
     {
     return 'n/a';
     }
   }
  elsif ( $type_name eq "TIME" )
   {
   if ( $data >= 0 )
     {
     my $h = int( ( $data / ( 60 * 60 ) ) );
     my $m = int( ( $data % ( 60 * 60 ) ) / 60 );
     my $s =        $data %   60;

     my @t = ( $s, $m, $h );

     return strftime( $self->{ 'FORMATS' }{ 'TIME' }, @t );
     }
   else
     {
     return 'n/a';
     }
   }
  elsif ( $type_name eq "UTIME" )
   {
   if ( $data >= 0 )
     {
     my @t = localtime( $data );
    
     my $tz = $type->{ 'TZ' } || $self->{ 'FORMATS' }{ 'TZ' };

     return strftime( $self->{ 'FORMATS' }{ 'UTIME' }, @t, $tz );
     }
   else
     {
     return 'n/a';
     }
   }  
  elsif ( $type_name eq "REAL" )
   {
   return undef unless $data =~ /^([-+])?(\d+)?(\.(\d+)?)?$/o;
   
   my $sign = $1;
   my $int  = $2 || '0';
   my $frac = $4 || '0';
   my $dot  = $type->{ 'DOT' };
   
   if ( $dot > 0 )
     {
     $frac .= '0' x $dot;              # pad
     $frac = substr( $frac, 0, $dot ); # cut to the dot position (NOT ROUND!)
     }
   my $dd = $frac eq '' ? '' : '.';
   return "$sign$int$dd$frac";
   }
  elsif ( $type_name eq 'INT' )
   {
   return int( $data );
   }
  else
   {
   return $data;
   }
}

# converts from human/visible format to internal data 
sub revert
{
}

# convert decor internal data from one type to another
sub convert
{
}

### EOF ######################################################################
1;
