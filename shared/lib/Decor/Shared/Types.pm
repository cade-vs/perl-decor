##############################################################################
##
##  Decor application machinery core
##  2014-2018 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Types;
use strict;

use Decor::Shared::Utils;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(
                  %DE_TYPE_NAMES
                  %DE_LTYPE_NAMES
                  
                  type_set_format
                  type_get_format
                  type_format
                  type_format_human
                  type_revert
                  type_default

                  type_convert
                  type_utime2time
                  type_utime2date
                  type_date2utime
                  type_utime_split
                  type_utime_merge
                  
                  type_widelink_construct
                  type_widelink_parse
                  type_widelink_parse2
                );

use Data::Dumper;
use Exception::Sink;
use Data::Tools 1.09;
use Data::Tools::Math;
use Data::Lock qw( dlock dunlock );

use Date::Format;
use Date::Parse;
use Time::JulianDay;
use Hash::Util qw( lock_hashref unlock_hashref lock_ref_keys );

our %DE_TYPE_NAMES = (
                      'INT'      => 1,
                      'REAL'     => 1,
                      'CHAR'     => 1,
                      'DATE'     => 1,
                      'TIME'     => 1,
                      'UTIME'    => 1,
                      
                      'LINK'     => 1,
                      'BACKLINK' => 1,
                      'WIDELINK' => 1,
                    );
dlock %DE_TYPE_NAMES;

# "logic" types
our %DE_LTYPE_NAMES = (
                      'LOCATION' => [ 'CHAR', 128 ],
                      'EMAIL'    => [ 'CHAR', 128 ],
                      'PHONE'    => [ 'CHAR',  64 ],
                      'FILE'     => [ 'LINK', 'DE_FILES', 'NAME' ],
                    );
dlock %DE_TYPE_NAMES;

my %TYPE_DEFAULTS = (
                      'INT'      => 0,
                      'REAL'     => 0.0,
                      'CHAR'     => '',
                      'DATE'     => 0,
                      'TIME'     => 0,
                      'UTIME'    => 0,

                      'LINK'     => 0,
                      'BACKLINK' => 0,
                      'WIDELINK' => '',
                    );

my $FMT_DATE_DMY = '%d.%m.%Y';
my $FMT_DATE_MDY = '%m.%d.%Y';
my $FMT_DATE_YMD = '%Y.%m.%d';

my $FMT_TIME_24   = '%H:%M:%S';
my $FMT_TIME_12   = '%I:%M:%S %p';
my $FMT_TIME_24S  = '%H:%M';
my $FMT_TIME_12S  = '%I:%M %p';

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
                              '24HS' => {
                                        FMT => $FMT_TIME_24S,
                                        },
                              '12HS' => {
                                        FMT => $FMT_TIME_12S,
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


                              'DMY24S' => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_24S",
                                        },
                              'MDY24S' => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_24S",
                                        },
                              'YMD24S' => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_24S",
                                        },
                              'DMY12S' => {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_12S",
                                        },
                              'MDY12S' => {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_12S",
                                        },
                              'YMD12S' => {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_12S",
                                        },
                              'DMY24SZ'=> {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_24S $FMT_TZ",
                                        },
                              'MDY24SZ'=> {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_24S $FMT_TZ",
                                        },
                              'YMD24SZ'=> {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_24S $FMT_TZ",
                                        },
                              'DMY12SZ'=> {
                                        FMT => "$FMT_DATE_DMY $FMT_TIME_12S $FMT_TZ",
                                        },
                              'MDY12SZ'=> {
                                        FMT => "$FMT_DATE_MDY $FMT_TIME_12S $FMT_TZ",
                                        },
                              'YMD12SZ'=> {
                                        FMT => "$FMT_DATE_YMD $FMT_TIME_12S $FMT_TZ",
                                        },
                              },
                    );

my %FORMAT_DEFAULTS = (
                        'DATE'  => 'YMD',
                        'TIME'  => '24H',
                        'UTIME' => 'YMD24Z',
                        'TZ'    => undef, # local machine TZ if empty
                      );


my %FORMATS = %FORMAT_DEFAULTS;

sub __check_format
{
  my $type_name = shift; # type name, UTIME, DATE, TIME
  my $fmt       = shift; # format string

  boom "unknown type [$type_name]" unless exists $FORMAT_SPECS{ $type_name };
  boom "unknown format [$fmt] for type [$type_name]" unless exists $FORMAT_SPECS{ $type_name }{ $fmt };
  
  return $fmt;
}

sub type_set_format
{
  my $type = shift; # hashref with type args
  my $fmt  = shift; # format string
  
  return undef unless $type;
  return undef unless $fmt;

  my $type_name = ref( $type ) ? $type->{ 'NAME' } : $type;

  __check_format( $type_name, $fmt );

  my $old_fmt = $FORMATS{ $type_name };
  $FORMATS{ $type_name } = $fmt;

  return $old_fmt;
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

     my $fmt_name = $FORMATS{ 'DATE' };
     $fmt_name = __check_format( $type_name, $type->{ 'FMT' } ) if $type->{ 'FMT' };
     my $fmt = $FORMAT_SPECS{ 'DATE' }{ $fmt_name }{ 'FMT' };
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
     my $time_int = int( $data );

     my $h = int( ( $time_int / ( 60 * 60 ) ) );
     my $m = int( ( $time_int % ( 60 * 60 ) ) / 60 );
     my $s =        $time_int %   60;

     my @t = ( $s, $m, $h );

     my $fmt_name = $FORMATS{ 'TIME' };
     $fmt_name = __check_format( $type_name, $type->{ 'FMT' } ) if $type->{ 'FMT' };
     my $fmt = $FORMAT_SPECS{ 'TIME' }{ $fmt_name }{ 'FMT' };

     my $dot = $type->{ 'DOT' };
     if( $dot > 0 )
       {
       my $time_frac = str_pad( num_round( ( $data - $time_int ) * ( 10 ** $dot ), 0 ), -$dot, '0' );
       $fmt =~ s/%S/%S.$time_frac/;
       }

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
     my $time_int = int( $data );
     
     my @t = localtime( $time_int );

     my $tz = exists $type->{ 'TZ' } ? ( $type->{ 'TZ' } || $FORMATS{ 'TZ' } ) : $FORMATS{ 'TZ' };

     my $fmt_name = $FORMATS{ 'UTIME' };
     $fmt_name = __check_format( $type_name, $type->{ 'FMT' } ) if exists $type->{ 'FMT' } and $type->{ 'FMT' };
     my $fmt = $FORMAT_SPECS{ 'UTIME' }{ $fmt_name }{ 'FMT' };
     
     my $dot = $type->{ 'DOT' };
     if( $dot > 0 )
       {
       my $time_frac = str_pad( num_round( ( $data - $time_int ) * ( 10 ** $dot ), 0 ), -$dot, '0' );
       $fmt =~ s/%S/%S.$time_frac/;
#print STDERR ">>>>>>>>>>>>>>>>>>>>>>>>>>. [$fmt]\n";
       }
     
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

sub type_format_human
{
  my $data = shift;
  my $type = shift; # hashref with type args
  
  my $fmt_data = type_format( $data, $type );

  my $type_name = $type->{ 'NAME' };

  if( $type_name eq "REAL" or $type_name eq "INT" )
    {
    $fmt_data = str_num_comma( $fmt_data );
    }
  
  return $fmt_data;  
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
    $fmt_name = __check_format( $type_name, $type->{ 'FMT' } ) if $type->{ 'FMT' };
    $data = __canonize_date_str( $data, $fmt_name );

    my ( $y, $m, $d ) = ( $1, $2, $3 ) if $data =~ /^(\d\d\d\d)[\.\/\-](\d\d?)[\.\/\-](\d\d?)$/o;

    return undef if $y == 0 or $m == 0 or $y == 0;
    return julian_day( $y, $m, $d );
    }
  elsif ( $type_name eq "TIME" )
    {
    $data =~ /^(\d+):(\d\d?)(:(\d\d?)(\.(\d+))?)?(\s*(AM|PM))?$/io || return undef;
    my $h = $1;
    my $m = $2;
    my $s = $4;
    my $f = $6;
    my $ampm = uc $8;

    if( $ampm )
      {
      return undef if $h > 12;
      $h -= 12 if $ampm eq 'AM' and $h == 12;
      $h += 12 if $ampm eq 'PM' and $h != 12;
      }

    return ( $h*60*60 + $m*60 + $s ) . ".$f";
    }
  elsif ( $type_name eq "UTIME" )
    {
    my $fmt_name = $FORMATS{ 'UTIME' };
    $fmt_name = __check_format( $type_name, $type->{ 'FMT' } ) if $type->{ 'FMT' };
    $data = __canonize_date_str( $data, $fmt_name );
    my $time_frac = $2 if $data =~ s/(\d\d?:\d\d?:\d\d?)(\.\d*)([^\.]*)$/$1/;
    $time_frac = undef if $time_frac eq '.';

    my @data = ( $data );
    push @data, $type->{ 'TZ' } if $type->{ 'TZ' } ne '';
    return str2time( @data ) . $time_frac;
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

sub type_check_name
{
  return exists $DE_TYPE_NAMES{ $_[0] };
}

sub type_default
{
  my $type_name = uc shift;

  boom "unknown type [$type_name]" unless exists $TYPE_DEFAULTS{ $type_name };
  return $TYPE_DEFAULTS{ $type_name };
}

# convert decor internal data from one type to another
sub type_convert
{
  my $val = shift; # value
  my $tfr = shift; # type from
  my $tto = shift; # type to
  my $opt = shift; # options, currently only TZ

  my $tz  = $opt->{ 'TZ' } if exists $opt->{ 'TZ' };

  if( $tfr eq 'UTIME' and $tto eq 'TIME'  )
    {
    return type_revert( substr( type_format( $val, { NAME => 'UTIME', 'TZ' => $tz } ), 11, 8 ), { NAME => 'TIME' } );
    }
  elsif( $tfr eq 'UTIME' and $tto eq 'DATE' )
    {
    return type_revert( substr( type_format( $val, { NAME => 'UTIME', 'TZ' => $tz } ), 0, 10 ), { NAME => 'DATE' } );
    }
  elsif( $tfr eq 'DATE' and $tto eq 'UTIME' )
    {
    return type_revert( type_format( $val, { NAME => 'DATE' } ), { NAME => 'UTIME', 'TZ' => $tz } );
    }
  else
    {
    boom "type_convert: cannot convert to ($tto) from ($tfr)";
    }
}

sub type_utime2time { return type_convert( shift(), 'UTIME', 'TIME', { TZ => shift() } ); }
sub type_utime2date { return type_convert( shift(), 'UTIME', 'DATE', { TZ => shift() } ); }
sub type_date2utime { return type_convert( shift(), 'DATE', 'UTIME', { TZ => shift() } ); }

sub type_utime_split
{
  my $u = shift; # UTIME value
  my $z = shift; # time zone

  my $us = type_format( $u, { NAME => 'UTIME', 'TZ' => $z } );
  my ( $ds, $ts ) = split / /, $us;

  return ( type_revert( $ds, { NAME => 'DATE' } ), type_revert( $ts, { NAME => 'TIME' } ) );
}

sub type_utime_merge
{
  my $d = shift; # date
  my $t = shift; # time
  my $z = shift; # time zone

  my $ds = type_format( $d, { NAME => 'DATE' } );
  my $ts = type_format( $t, { NAME => 'TIME' } );

  return type_revert( "$ds $ts", { NAME => 'UTIME', 'TZ' => $z } );
}

sub type_widelink_construct
{
  my %args = @_;
  
  my $table = $args{ 'TABLE' };
  my $id    = $args{ 'ID'    };
  my $field = $args{ 'FIELD' };
  
  boom "type_widelink_construct: invalid TABLE [$table]" unless de_check_name( $table );
  boom "type_widelink_construct: invalid ID [$id]"       unless de_check_id( $id );
  boom "type_widelink_construct: invalid FIELD [$field]" if $field and ! de_check_name( $field );
  
  return "$table:$id:$field";
}

sub type_widelink_parse
{
  my $data = shift;

  if( $data eq '' )
    {
    return () if wantarray;
    return undef;
    }
  
  $data = "$1:$2:" if $data =~ /([A-Z_0-9]+)\[(\d+)\]/; # FIXME: compatibility, must be removed in the future
  boom "type_widelink_parse: invalid WIDELINK data [$data]" unless $data =~ /^([a-zA-Z_0-9]+):([0-9]+):([a-zA-Z_0-9]+)?$/;

  return ( $1, $2, $3 ) if wantarray;
  
  my $hr;
  $hr->{ 'TABLE' } = $1;
  $hr->{ 'ID'    } = $2;
  $hr->{ 'FIELD' } = $3 if $3;
  
  return $hr;
}

sub type_widelink_parse2
{
  my $wh;
  eval { $wh = type_widelink_parse( @_ ); };
  return wantarray ? ( $wh->{ 'TABLE' }, $wh->{ 'ID' }, $wh->{ 'FIELD' } ) : $wh;
}

### EOF ######################################################################
1;
