#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Data::Dumper;
use Decor::Shared::Utils;
use Decor::Shared::Net::Client;

my $host = ( shift() || 'localhost:4243' );

my $client = new Decor::Shared::Net::Client;

$| = 1;

$client->connect( $host ) or die "cannot connect to [$host] error [$!]";

$client->begin_user_pass( 'test', 'test123', 'local' ) or die "cannot begin with user pass";

my $ss = $client->select( 'test1', '*' );
print "ss: $ss\n";
while( my $hr = $client->fetch( $ss ) )
  {
  print Dumper( $hr );
  }



















