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

my $FMT_DATE_DMY = '%d.%m.%Y';
my $FMT_DATE_MDY = '%m.%d.%Y';
my $FMT_DATE_YMD = '%Y.%m.%d';

my $FMT_TIME_24  = '%H:%M:%S';
my $FMT_TIME_12  = '%I:%M:%S %p';

my $FMT_TZ       = '%z %Z';

my $REX_DATE_DMY  = '(?<day>\d\d?)[\.\/](?<month>\d\d?)[\.\/](?<year>\d\d\d\d)';
my $REX_DATE_MDY  = '(?<month>\d\d?)[\.\/](?<day>\d\d?)[\.\/](?<year>\d\d\d\d)';
my $REX_DATE_YMD  = '(?<year>\d\d\d\d)[\.\/](?<month>\d\d?)[\.\/](?<day>\d\d?)';

my $REX_TIME_24   = '(?<hours>\d+)[\.\/](?<minutes>\d\d?)[\.\/](?<seconds>\d\d?)';
my $REX_TIME_12   = "$REX_TIME_24\s*(\s+(?<ampm>AM|PM))";

my $REX_TZ        = '(?<tzoffset>[-+]\d\d\d\d)(\s+(?<tzname>[A-Z]+))?';

my %FORMATS_SPECS = (
                    'DATE' => {
                              'DMY'  => {
                                        FMT => $FMT_DATE_DMY,
                                        REX => $REX_DATE_DMY,
                                        },
                              'MDY'  => {
                                        FMT => $FMT_DATE_MDY,
                                        REX => $REX_DATE_MDY,
                                        },
                              'YMD'  => {
                                        FMT => $FMT_DATE_YMD,
                                        REX => $REX_DATE_YMD,
                                        },
                              },
                    'TIME' => {
                              '24'   => {
                                        FMT => $FMT_TIME_24,
                                        REX => $REX_TIME_24,
                                        },
                              '12'   => {
                                        FMT => $FMT_TIME_12,
                                        REX => $REX_TIME_12,
                                        },
                              },
                   'UTIME' => {
                              'DMY24'  => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_24",
                                        REX => "$REX_DATE_DMY\s+$REX_TIME_24",
                                        },
                              'MDY24'  => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_24",
                                        REX => "$REX_DATE_MDY\s+$REX_TIME_24",
                                        },
                              'YMD24'  => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_24",
                                        REX => "$REX_DATE_YMD\s+$REX_TIME_24",
                                        },
                              'DMY12'  => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_12",
                                        REX => "$REX_DATE_DMY\s+$REX_TIME_12",
                                        },
                              'MDY12'  => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_12",
                                        REX => "$REX_DATE_MDY\s+$REX_TIME_12",
                                        },
                              'YMD12'  => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_12",
                                        REX => "$REX_DATE_YMD\s+$REX_TIME_12",
                                        },
                              'DMY24Z' => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_24 $FMT_TZ",
                                        REX => "$REX_DATE_DMY\s+$REX_TIME_24",
                                        },
                              'MDY24Z' => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_24 $FMT_TZ",
                                        REX => "$REX_DATE_MDY\s+$REX_TIME_24",
                                        },
                              'YMD24Z' => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_24 $FMT_TZ",
                                        REX => "$REX_DATE_YMD\s+$REX_TIME_24",
                                        },
                              'DMY12Z' => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_12 $FMT_TZ",
                                        REX => "$REX_DATE_DMY\s+$REX_TIME_12\s+$REX_TZ",
                                        },
                              'MDY12Z' => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_12 $FMT_TZ",
                                        REX => "$REX_DATE_MDY\s+$REX_TIME_12\s+$REX_TZ",
                                        },
                              'YMD12Z' => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_12 $FMT_TZ",
                                        REX => "$REX_DATE_YMD\s+$REX_TIME_12\s+$REX_TZ",
                                        },
                              },
                    );                      

my %FORMATS_DEFAULTS = (
                        'DATE'  => 'YMD',
                        'TIME'  => '24',
                        'UTIME' => 'YMD24Z',
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

  $self->{ 'FORMATS' } = { %FORMATS_DEFAULTS },
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
