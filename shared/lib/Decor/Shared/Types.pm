##############################################################################
##
##  Decor stagelication machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Types;
use strict;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(
                  type_set_format
                  type_get_format
                  type_format
                  type_revert
                );

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;
use Data::Lock qw( dlock dunlock );

use DateTime;

use Date::Format;
use Date::Parse;
#use Date::Calc;
use Time::JulianDay;
#use DateTime::Format::Strptime;
use Hash::Util qw( lock_hashref unlock_hashref lock_ref_keys );

my %TYPE_NAMES   = map { $_ => 1 } qw( INT REAL CHAR DATE TIME UTIME );

my $FMT_DATE_DMY = '%d.%m.%Y';
my $FMT_DATE_MDY = '%m.%d.%Y';
my $FMT_DATE_YMD = '%Y.%m.%d';

my $FMT_TIME_24  = '%H:%M:%S';
my $FMT_TIME_12  = '%I:%M:%S %p';

my $FMT_TZ       = '%z %Z';

my %FORMAT_SPECS = (
                    'DATE' => {
                              'DMY'  => {
                                        FMT => $FMT_DATE_DMY,
                                        },
                              'MDY'  => {
                                        FMT => $FMT_DATE_MDY,
                                        },
                              'YMD'  => {
                                        FMT => $FMT_DATE_YMD,
                                        },
                              },
                    'TIME' => {
                              '24H'  => {
                                        FMT => $FMT_TIME_24,
                                        },
                              '12H'  => {
                                        FMT => $FMT_TIME_12,
                                        },
                              },
                   'UTIME' => {
                              'DMY24'  => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_24",
                                        },
                              'MDY24'  => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_24",
                                        },
                              'YMD24'  => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_24",
                                        },
                              'DMY12'  => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_12",
                                        },
                              'MDY12'  => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_12",
                                        },
                              'YMD12'  => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_12",
                                        },
                              'DMY24Z' => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_24 $FMT_TZ",
                                        },
                              'MDY24Z' => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_24 $FMT_TZ",
                                        },
                              'YMD24Z' => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_24 $FMT_TZ",
                                        },
                              'DMY12Z' => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_12 $FMT_TZ",
                                        },
                              'MDY12Z' => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_12 $FMT_TZ",
                                        },
                              'YMD12Z' => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_12 $FMT_TZ",
                                        },
                              },
                    );                      

my %FORMAT_DEFAULTS = (
                        'DATE'  => 'YMD',
                        'TIME'  => '24',
                        'UTIME' => 'YMD24Z',
                        'TZ'    => undef, # local machine TZ if empty
                      );
                      

my %FORMATS = %FORMAT_DEFAULTS;
                      
sub type_set_format
{
  my $type = shift; # hashref with type args
  my $fmt  = shift; # format string
  
  my $type_name = $type->{ 'NAME' };

  boom "unknown type [$type_name]" unless exists $FORMAT_SPECS{ $type_name };
  boom "unknown format [$fmt] for type [$type_name]" unless exists $FORMAT_SPECS{ $type_name }{ $fmt };
  
  $FORMATS{ $type_name } = $fmt;
  
  return $fmt;
}

sub type_get_format
{
  my $type = shift; # hashref with type args

  my $type_name = $type->{ 'NAME' };
  
  return $FORMATS{ $type_name };
}

sub type_reset_formats
{
  %FORMATS = %FORMAT_DEFAULTS;

  return 1;
}

# converts from decor internal data to human/visible format
sub type_format
{
  my $data = shift;
  my $type = shift; # hashref with type args

  my $type_name = $type->{ 'NAME' };

  if( $type_name eq "DATE" )
   {
   if ( $data > 0 )
     {
     my ( $y, $m, $d ) = inverse_julian_day( $data );

     my @t = ( undef, undef, undef, $d, $m - 1, $y - 1900 );

     my $fmt = $FORMAT_SPECS{ 'DATE' }{ $FORMATS{ 'DATE' } }{ 'FMT' };
     return strftime( $fmt, @t );
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

     my $fmt = $FORMAT_SPECS{ 'TIME' }{ $FORMATS{ 'TIME' } }{ 'FMT' };
     return strftime( $fmt, @t );
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
    
     my $tz = $type->{ 'TZ' } || $FORMATS{ 'TZ' };

     my $fmt = $FORMAT_SPECS{ 'UTIME' }{ $FORMATS{ 'UTIME' } }{ 'FMT' };
     return strftime( $fmt, @t, $tz );
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

sub __canonize_date_str
{
  my $date     = shift;
  my $fmt_name = shift;

  if( $fmt_name =~ /^DMY/ )
    {
    $date =~ s/^(\d\d?)([\.\/\-])(\d\d?)([\.\/\-])(\d\d\d\d)/$5$4$3$2$1/;
    }
  elsif( $fmt_name =~ /^MDY/ )
    {
    $date =~ s/^(\d\d?)([\.\/\-])(\d\d?)([\.\/\-])(\d\d\d\d)/$5$4$1$2$3/;
    }  
  
  return $date;
}

# converts from human/visible format to internal data 
sub type_revert
{
  my $data = shift;
  my $type = shift; # hashref with type args

  my $type_name = $type->{ 'NAME' };

  if( $type_name eq "DATE" )
    {
    return undef if $data =~ m/^\s*(n\/a|\(?empty\)?)\s*$/;
    
    my $fmt_name = $FORMATS{ 'DATE' };
    $data = __canonize_date_str( $data, $fmt_name );

    my ( $y, $m, $d ) = ( $1, $2, $3 ) if $data =~ /^(\d\d\d\d)[\.\/\-](\d\d?)[\.\/\-](\d\d?)$/o;

    return undef if $y == 0 or $m == 0 or $y == 0;
    return julian_day( $y, $m, $d );
    }
  elsif ( $type_name eq "TIME" )
    {
    $data =~ /^(\d+):(\d\d?)(:(\d\d?))?(\s*(AM|PM))?$/io || return undef;
    my $h = $1;
    my $m = $2;
    my $s = $4;
    my $ampm = uc $6;

    if( $ampm )
      {
      return undef if $h > 12;
      $h -= 12 if $ampm eq 'AM' and $h == 12;
      $h += 12 if $ampm eq 'PM' and $h != 12;
      }

    return $h*60*60 + $m*60 + $s;
    }
  elsif ( $type_name eq "UTIME" )
    {
    my $fmt_name = $FORMATS{ 'DATE' };
    $data = __canonize_date_str( $data, $fmt_name );

    return str2time( $data );
    }  
    elsif ( $type_name eq "REAL" )
    {
    return undef if $data eq '';
    $data =~ s/[\s_\'\`]//go; # '
    return undef unless $data =~ /^[\-\+]?\d*(\.(\d+)?)?$/o;
    return $data;
    }
  elsif ( $type_name eq 'INT' )
    {
    return undef if $data eq '';
    $data =~ s/[\s_\'\`]//go; # '
    return undef unless $data =~ /^([\-\+]?\d*)(\.(\d+)?)?$/o;
    return $1;
    }
  else
    {
    return $data;
    }
}

# convert decor internal data from one type to another
sub type_convert
{
}

sub type_check_name
{
  return exists $TYPE_NAMES{ $_[0] };
}

### EOF ######################################################################
1;
