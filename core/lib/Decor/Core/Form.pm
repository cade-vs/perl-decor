##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Core::Form;
use strict;

use Data::Dumper;
use Data::Tools;
use Exception::Sink;

use Decor::Core::Env;
use Decor::Core::Utils;
use Decor::Core::Describe;
use Decor::Shared::Utils;
use Decor::Shared::Types;

use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( 

                de_form_gen_rec_data
                de_form_process_text

                );

my %FORM_CACHE;

sub de_form_gen_rec_data
{
  # print STDERR Dumper( '+++++++++++++++++++++++++++++++++++++++++++++++++', \@_ );
  
  my $form_name = shift;
  my $rec       = shift;
  my $data      = shift;
  my $opts      = shift;
  
  my $form_file = de_core_subtype_file_find( 'forms', 'txt', $form_name );

  my $form_text = file_load( $form_file );
  
  $form_text = de_form_process_text( $form_text, $rec, $data, $opts );

  return $form_text;
}

sub de_form_process_text
{
  my $text = shift;
  my $rec  = shift;
  my $data = shift;
  my $opts = shift;

  $text =~ s/\[(.*?)\]/__form_process_item( $1, 'F', $rec, $data, $opts )/gie;
  $text =~ s/\{(.*?)\}/__form_process_item( $1, 'T', $rec, $data, $opts )/gie;

  return $text;
}

sub __form_process_item
{
  my $item = shift;
  my $type = shift;
  my $rec  = shift;
  my $data = shift;
  my $opts = shift;

  my $item_len = 0;
  my $item_align = '<';
  
  $item =~ s/^\s*//;
  $item =~ s/\s*$//;
  
#  my ( $name, $fmt ) = split $type eq 'T' ? /\s*;+\s*/ : /\s+/, $item, 2;

  my ( $name, $fmt );
  ( $name, $fmt ) = split      /\s+/, uc $item, 2 if $type eq 'F'; # fields
  ( $name, $fmt ) = split /\s*;+\s*/,    $item, 2 if $type eq 'T'; # text, plain text

  my $item_dot = 8;
  ( $item_len, $item_dot ) = ( ( $1 || $item_len ), ( $3 || $4 ) ) if $fmt =~ /(\d+)(\.(\d+))?|\.(\d+)/;
  $item_align = $1 if $fmt =~ /([<=~>])/;
  my ( $item_format, $item_format_name ) = ( 1, $2 ) if $fmt =~ /F(\(\s*([A-Z]+)\s*\))?/;
  my $sub_form_name = uc( $1 ) if $fmt =~ /\@([a-z_]+)/i;

  my $value;
  if( $type eq 'T' )
    {
    # text
    $value = $name;
    }
  elsif( $data and exists $data->{ $name } )  
    {
    $value = $data->{ $name };
    $value = type_format( $value, { NAME => $item_format_name, DOT => $item_dot } ) if $item_format;
    }
  elsif( $rec )
    {  
    my $tdes = describe_table( $rec->table() );
    my ( $bfdes, $lfdes ) = $tdes->resolve_path( $name );

    if( $bfdes->is_backlinked() )
      {
      my $brec = $rec->select_backlinked_records( $name );
      while( $brec->next() )
        {
        $value .= de_form_gen_rec_data( $sub_form_name, $brec, $data, $opts );
        }
      chomp( $value );  
      $item_align = '~';  
      }
    elsif( $lfdes )
      {
      $value = $rec->read( $name );
      my $ftype;
      if( ! $item_format_name )
        {
        $ftype = $lfdes->{ 'TYPE' };
        }
      else
        {
        $ftype = { NAME => $item_format_name, DOT => $item_dot };
        }  
      $value = type_format( $value, $ftype );
      }
    else
      {
      # TODO: warning: no such record field or data
      $value = '*?*';
      }
    }  
  else
    {
    # TODO: warning: no such record field or data
    $value = '*??*';
    }

  return $value unless $item_len > 0;

  if( $item_align eq '<' )
    {
    $value = str_pad( $value, $item_len );
    }
  elsif( $item_align eq '>' )
    {
    $value = str_pad( $value, -$item_len );
    }
  elsif( $item_align eq '=' )
    {
    $value = str_pad_center( $value, $item_len );
    }  

  return $value;  
}


### EOF ######################################################################
1;
