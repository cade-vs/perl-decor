#!/usr/bin/perl
##############################################################################
##
##  Decor application machinery core
##  2014-2016 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
use strict;
use lib ( map { die "invalid DECOR_CORE_ROOT dir [$_]\n" unless -d; ( "$_/core/lib", "$_/shared/lib" ) } ( $ENV{ 'DECOR_CORE_ROOT' } || '/usr/local/decor' ) );
use Data::Dumper;
use IO::Socket::INET;
use Decor::Shared::Net::Protocols;

my $host = ( shift() || 'localhost:4243' );
my $socket = IO::Socket::INET->new( PeerAddr => $host )
      or die "cannot connect to [$host] $!\n";

$| = 1;
$socket->autoflush(1);
while(42)
  {
  my $mi = {};
  print "enter query data?\n";
  while(<>)
    {
    chomp;
    last if /^---$/;
    if( /^\s*(\S+)\s*=+\s*((.*?)|(['"])(.*?)\4)\s*$/ )
      {
      $mi->{ uc $1 } = $3 || $5;
      }
    else
      {
      print "invalid line [$_] ignored...\n";
      }  
    }
  print "sending query message:\n";
  print Dumper( $mi );

  my $res = de_net_protocol_write_message( $socket, 'p', $mi );
  
  die "error sending message [$res]\n" unless $res;

  my $mo = de_net_protocol_read_message( $socket );

  print "receiving query reply message:\n";
  print Dumper( $mo );
  }

$socket->close();
























