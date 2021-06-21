##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package decor::actions::grid_export;
use strict;

use Data::Dumper;
use Data::Tools 1.21;

use Web::Reactor::HTML::Utils;

use Decor::Shared::Types;
use Decor::Web::HTML::Utils;
use Decor::Web::View;
use Decor::Web::Grid;
use Decor::Web::Utils;

my %FMT_CLASSES = (
                  'CHAR'  => 'fmt-left',
                  'DATE'  => 'fmt-left',
                  'TIME'  => 'fmt-left',
                  'UTIME' => 'fmt-left',

                  'INT'   => 'fmt-right fmt-mono',
                  'REAL'  => 'fmt-right fmt-mono',
                  );

sub main
{
  my $reo = shift;

  return unless $reo->is_logged_in();

  my $text;

  my $si = $reo->get_safe_input();
  my $ui = $reo->get_user_input();
  my $ps = $reo->get_page_session();
  my $rs = $reo->get_page_session( 1 );

  my $table  = $reo->param( 'TABLE'  );

  my $core = $reo->de_connect();
  my $tdes = $core->describe( $table );
  my $sdes = $tdes->get_table_des(); # table "Self" description

  my $grid_export = $rs->{ 'GRID_EXPORT' };

print STDERR Dumper( $grid_export );
  
  return "<#e_data>" unless ref( $grid_export ) eq 'ARRAY';

  my @fields = split /,/, $grid_export->[1];

  my %bfdes; # base/begin/origin field descriptions, indexed by field path
  my %lfdes; # linked/last       field descriptions, indexed by field path, pointing to trail field
  my %basef; # base fields map, return base field NAME by field path

  de_web_expand_resolve_fields_in_place( \@fields, $tdes, \%bfdes, \%lfdes, \%basef );

  my $select = $core->select( @$grid_export );

  my $grid_export_text;

  my $row_counter;
  while( my $row_data = $core->fetch( $select ) )
    {
    my @row_data;
    my $id = $row_data->{ '_ID' };
    for my $field ( @fields )
      {
      my $bfdes     = $bfdes{ $field };
      my $lfdes     = $lfdes{ $field };
      my $type_name = $lfdes->{ 'TYPE' }{ 'NAME' };

      next if $bfdes->get_attr( qw( WEB GRID HIDE ) );

      my $lpassword = $lfdes->get_attr( 'PASSWORD' ) ? 1 : 0;

      my $base_field = exists $basef{ $field } ? $basef{ $field } : $field;

      my $data = $row_data->{ $field };
      my $data_base = $row_data->{ $basef{ $field } } if exists $basef{ $field };

      my ( $data_fmt, $fmt_class_fld ) = de_web_format_field( $data, $lfdes, 'GRID', { ID => $id, REO => $reo, CORE => $core } );

      $data_fmt =~ s/`//g; # FIXME: REMOVE ASAP!

      if( $bfdes->is_linked() or $bfdes->is_widelinked() )
        {
          my ( $linked_table, $linked_id, $linked_field );
          if( $bfdes->is_linked() ) 
            {
            ( $linked_table, $linked_field ) = $bfdes->link_details();
            $linked_id = $data_base;
            }
          else
            {
            # $bfdes->is_widelinked()
            ( $linked_table, $linked_id, $linked_field ) = type_widelink_parse2( $data );
            if( $linked_table )
              {
              $data_fmt = '';
              }
            else
              {
              $data_fmt   = "(empty)";
              }  
            }  
          
          if( $linked_table )
            {
            my $ltdes = $core->describe( $linked_table );
            
            my $linked_table_label = $ltdes->get_label();
            if( $bfdes->is_widelinked() )
              {
              if( $linked_field )
                {
                $data_fmt = $core->read_field( $linked_table, $linked_field, $linked_id );
                my $lfdes = $ltdes->get_field_des( $linked_field );
                $data_fmt  = de_web_format_field( $data_fmt, $lfdes, 'VIEW', { ID => $linked_id } );
                }
              else
                {
                $data_fmt = "[~Linked to a record from:] $linked_table_label";
                }  
              }
            else
              {
              ( $data_fmt, $fmt_class_fld ) = de_web_format_field( $data, $lfdes, 'GRID', { ID => $id, REO => $reo, CORE => $core } );
              }  
            
            if( $linked_id > 0 )
              {
              $data_fmt =~ s/\././g;
              }
            else
              {
              $data_fmt   = "(empty)";
              }
            } # if $linked_table  
        }
      elsif( $bfdes->is_backlinked() )
        {
        my ( $backlinked_table, $backlinked_field ) = $bfdes->backlink_details();
        my $bltdes = $core->describe( $backlinked_table );

        $data_fmt = ""; # TODO: hide count, which is currently unsupported
        my $bcnt = 'n/a';
        if( uc( $bfdes->get_attr( 'WEB', 'GRID', 'BACKLINK_GRID_MODE' ) ) eq 'ALL' )
          {
          $bcnt = $core->count( $backlinked_table, { FILTER => { $backlinked_field => [ { OP => 'IN', VALUE => [ $id, 0 ] } ] } } );
          }
        else
          {  
          $bcnt = $core->count( $backlinked_table, { FILTER => { $backlinked_field => $id } } );
          # my $ucnt = $core->count( $backlinked_table, { FILTER => { $backlinked_field =>   0 } } );
          }
        $data_fmt = $bcnt || '';
        }

      if( $lpassword )
        {
        $data_fmt = "(*****)";
        }

      push @row_data, $data_fmt;
      }
    $grid_export_text .= join( ';', @row_data ) . "\n";
    }

  return $reo->render_data( $grid_export_text, 'text/csv', FILE_NAME => time() . '.csv' );
}

1;
