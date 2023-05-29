#!/usr/bin/perl
use strict;
use Encode;
use Storable;
use Sereal;
use JSON;
use Data::Stacker;
use Data::Tools;
use Data::Dumper;
use utf8;


my $hr = { 'TEST' => "Това е проста проба", 'ИМЕ' => 'nqma' };

print Encode::is_utf8( $hr->{ 'TEST' } );

print "\nStorable: ";

file_save( '/tmp/utf-store-test.data', Storable::nfreeze( $hr ) );
my $new = Storable::thaw( file_load( '/tmp/utf-store-test.data' ) );

print Encode::is_utf8( $new->{ 'TEST' } );

print "\nSereal: ";

file_save( '/tmp/utf-store-test.data', Sereal::encode_sereal( $hr ) );
my $new = Sereal::decode_sereal( file_load( '/tmp/utf-store-test.data' ) );

print Encode::is_utf8( $new->{ 'TEST' } );

print "\nJSON: ";

file_save( '/tmp/utf-store-test.data', JSON::encode_json( $hr ) );
my $new = JSON::decode_json( file_load( '/tmp/utf-store-test.data' ) );

print Encode::is_utf8( $new->{ 'TEST' } );

print "\nData::Stacker: ";

file_save( '/tmp/utf-store-test.data', Data::Stacker::stack_data( $hr ) );
my $new = Data::Stacker::unstack_data( file_load( '/tmp/utf-store-test.data' ) );

print Encode::is_utf8( $new->{ 'TEST' } );

print "\n";

print Dumper( $new );
