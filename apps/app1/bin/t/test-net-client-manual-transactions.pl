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

my $host = ( shift() || 'localhost:42000' );

my $client = new Decor::Shared::Net::Client;

$| = 1;

$client->connect( $host ) or die "cannot connect";

$client->begin_user_pass( 'test', 'test123', 'local' ) or die "cannot begin with user pass";

$client->begin_work();
$client->insert( 'TEST2', { NAME => 'MANUAL',      CNT => 123456 } );
$client->insert( 'TEST2', { NAME => 'TRANSACTION', CNT => 123456 } );
$client->commit();




















