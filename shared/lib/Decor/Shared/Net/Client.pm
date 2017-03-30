##############################################################################
##
##  Decor application machinery core
##  2014-2017 (c) Vladi Belperchinov-Shabanski "Cade"
##  <cade@bis.bg> <cade@biscom.net> <cade@cpan.org>
##
##  LICENSE: GPLv2
##
##############################################################################
package Decor::Shared::Net::Client;
use strict;
use Exporter;
use Exception::Sink;

use Hash::Util qw( lock_ref_keys unlock_ref_keys );
use IO::Socket::INET;
use Data::Tools;
use Exception::Sink;
use Data::Dumper;

use Decor::Shared::Utils;
use Decor::Shared::Net::Protocols;
use Decor::Shared::Net::Client::Table::Description;
use Decor::Shared::Net::Client::Table::Field::Description;

sub new
{
  my $class = shift;
  $class = ref( $class ) || $class;
  
  my %args = @_;
  
  my $self = {
             %args # FIXME: check and/or filter
             };
  bless $self, $class;

  $self->{ 'TIMEOUT' } = 60 if $self->{ 'TIMEOUT' } < 1;
  
  de_obj_add_debug_info( $self );
  $self->__init();
  return $self;
}

sub __init
{
  0;
}

sub __lock_self_keys
{
  my $self = shift;

  for my $key ( @_ )
    {
    next if exists $self->{ $key };
    $self->{ $key } = undef;
    }
  lock_ref_keys( $self );  
}

sub DESTROY
{
   my $self = shift;
   $self->disconnect();
}

##############################################################################

sub status
{
  my $self = shift;
  
  return $self->{ 'STATUS'  };
}

sub status_ref
{
  my $self = shift;
  
  return $self->{ 'STATUS_REF'  };
}

sub is_connected
{
  my $self = shift;
  
  return $self->{ 'SOCKET' } ? 1 : 0;
}

sub check_connected
{
  my $self = shift;
  
  boom "not connected" unless $self->is_connected();
}

sub connect
{
  my $self        = shift;
  my $server_addr = shift; # ip:port
  my $app_name    = shift;

  my $socket = IO::Socket::INET->new( PeerAddr => $server_addr, Timeout => 2.0 );
  
  if( $socket )
    {
    $socket->autoflush( 1 );
    $self->{ 'SERVER_ADDR' } = $server_addr;
    $self->{ 'SOCKET'      } = $socket;
    
    my $mo = $self->tx_msg( { 'XT' => 'CAPS', 'APP_NAME' => $app_name } );
    if( ! $mo )
      {
      $self->reset();
      return undef;
      }
    }
  else
    {
    $self->reset();
    return undef;
    }  
  
  return 1;
}

sub disconnect
{
  my $self = shift;

  return 1 unless $self->is_connected();

  $self->{ 'SOCKET' }->close();
  $self->{ 'SOCKET' } = undef;

  $self->reset();

  return 1;
}

sub reset
{
  my $self = shift;

  %$self = ();

  return 1;
}

#-----------------------------------------------------------------------------

sub tx_msg
{
  my $self = shift;
  my $mi = shift;

  $self->check_connected();

  my $socket  = $self->{ 'SOCKET'  };
  my $timeout = $self->{ 'TIMEOUT' };
  
  $self->{ 'STATUS'      } = 'E_MSG';
  $self->{ 'STATUS_MSG'  } = 'Communication error';
  $self->{ 'STATUS_REF'  } = undef;
  
  my $ptype = 'p'; # FIXME: config?
  
  my $mi_res = de_net_protocol_write_message( $socket, $ptype, $mi, $timeout );
  if( $mi_res == 0 )
    {
    $self->disconnect();
    return undef;
    }

  my $mo;
  ( $mo, $ptype ) = de_net_protocol_read_message( $socket, $timeout );
  if( ! $mo or ref( $mo ) ne 'HASH' )
    {
    $self->disconnect();
    return undef;
    }


  $self->{ 'STATUS'      } = $mo->{ 'XS'     };
  $self->{ 'STATUS_MSG'  } = $mo->{ 'XS_MSG' };
  $self->{ 'STATUS_REF'  } = $mo->{ 'XS_REF' };

  return undef unless $mo->{ 'XS' } eq 'OK';
  return $mo;
}

#-----------------------------------------------------------------------------

sub begin_user_pass
{
  my $self = shift;
  
  my $user   = shift;
  my $pass   = shift;
  my $remote = shift;


  my $mop = $self->tx_msg( { 'XT' => 'P', 'USER' => $user } ) or return undef;

  my $user_salt  = $mop->{ 'USER_SALT'  };
  my $login_salt = $mop->{ 'LOGIN_SALT' };

  my %mi;

  $mi{ 'XT'     } = 'B';
  $mi{ 'USER'   } = $user;
  $mi{ 'PASS'   } = de_password_salt_hash( de_password_salt_hash( $pass, $user_salt ), $login_salt );
  $mi{ 'REMOTE' } = $remote;
  
  my $mo = $self->tx_msg( \%mi ) or return undef;
  # FIXME: TODO: if failed then disconnect?

  $self->{ 'CORE_SESSION_XTIME' } = $mo->{ 'XTIME' } || time() + 10*60;
  $self->{ 'USER_GROUPS'        } = $mo->{ 'UGS'   } || {};

  return $mo->{ 'SID' };
}

sub begin_user_session
{
  my $self = shift;
  
  my $user_sid = shift;
  my $remote   = shift;
 
  my %mi;

  $mi{ 'XT'       } = 'B';
  $mi{ 'USER_SID' } = $user_sid;
  $mi{ 'REMOTE'   } = $remote;
  
  my $mo = $self->tx_msg( \%mi ) or return undef;
  # FIXME: TODO: if failed then disconnect?

  $self->{ 'CORE_SESSION_XTIME' } = $mo->{ 'XTIME' } || time() + 10*60;
  $self->{ 'USER_GROUPS'        } = $mo->{ 'UGS'   } || {};

  return $mo->{ 'SID' };
}

sub end
{
  my $self = shift;
 
  my %mi;

  $mi{ 'XT'    } = 'E';

  delete $self->{ 'CORE_SESSION_XTIME' };
  delete $self->{ 'USER_GROUPS'        };
  
  my $mo = $self->tx_msg( \%mi ) or return undef;

  return 1;
}

#-----------------------------------------------------------------------------

sub describe
{
  my $self = shift;

  my $table  = uc shift;

  return $self->{ 'CACHE' }{ 'DESCRIBE' }{ $table }
      if $self->{ 'CACHE' }{ 'DESCRIBE' }{ $table };


  my %mi;

  $mi{ 'XT'    } = 'D';
  $mi{ 'TABLE' } = $table;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  $self->{ 'CACHE' }{ 'DESCRIBE' }{ $table } = $mo->{ 'DES' };

  $mo->{ 'DES' }{ 'CACHE' } = {};
  $mo->{ 'DES' }{ ':CLIENT_OBJECT' } = $self;
  bless $mo->{ 'DES' }, 'Decor::Shared::Net::Client::Table::Description';
  for my $field ( keys %{ $mo->{ 'DES' }{ 'FIELD' } } )
    {
    $mo->{ 'DES' }{ 'FIELD' }{ $field }{ ':CLIENT_OBJECT' } = $self;
    bless $mo->{ 'DES' }{ 'FIELD' }{ $field }, 'Decor::Shared::Net::Client::Table::Field::Description';
    }
  hash_lock_recursive( $mo->{ 'DES' } );
#  lock_ref_keys( $mo->{ 'DES' } );  
  unlock_ref_keys( $mo->{ 'DES' }{ 'CACHE' } );

  return $mo->{ 'DES' };
}

sub menu
{
  my $self = shift;
  my $name = shift; # menu name

  return $self->{ 'CACHE' }{ 'MENU' }{ $name }
      if $self->{ 'CACHE' }{ 'MENU' }{ $name };


  my %mi;

  $mi{ 'XT'    } = 'M';
  $mi{ 'MENU'  } = $name;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  $self->{ 'CACHE' }{ 'MENU' }{ $name } = $mo->{ 'MENU' };

  return $mo->{ 'MENU' };
}

#-----------------------------------------------------------------------------

sub select
{
  my $self = shift;

  my $table  = uc shift;
  my $fields = shift;
  my $opt    = shift;
  
  my $filter   = $opt->{ 'FILTER' } || {};
  my $limit    = $opt->{ 'LIMIT'  };
  my $offset   = $opt->{ 'OFFSET' };
  my $lock     = $opt->{ 'LOCK'   };
  my $order_by = $opt->{ 'ORDER_BY' };
  my $group_by = $opt->{ 'GROUP_BY' };
  
  my $filter_name = $opt->{ 'FILTER_NAME' };

  $fields = join( ',',      @$fields ) if ref( $fields ) eq 'ARRAY';
  $fields = join( ',', keys %$fields ) if ref( $fields ) eq 'HASH';

  my %mi;

  $mi{ 'XT' } = 'S';
  $mi{ 'TABLE'    } = $table;
  $mi{ 'FIELDS'   } = uc $fields;
  $mi{ 'FILTER'   } = $filter;
  $mi{ 'LIMIT'    } = $limit;
  $mi{ 'OFFSET'   } = $offset;
  $mi{ 'LOCK'     } = $lock;
  $mi{ 'ORDER_BY' } = $order_by;
  $mi{ 'GROUP_BY' } = $group_by;
  $mi{ 'FILTER_NAME' } = $filter_name;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'SELECT_HANDLE' };
}

sub fetch
{
  my $self = shift;

  my $select_handle = shift;

  return undef unless $select_handle;

  my %mi;

  $mi{ 'XT' } = 'F';
  $mi{ 'SELECT_HANDLE'  } = $select_handle;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'DATA' };
}

sub finish
{
  my $self = shift;

  my $select_handle = shift;

  my %mi;

  $mi{ 'XT' } = 'H';
  $mi{ 'SELECT_HANDLE'  } = $select_handle;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return 1;
}

#-----------------------------------------------------------------------------

sub next_id
{
  my $self = shift;

  my $table  = uc shift;
  
  my %mi;

  $mi{ 'XT' } = 'N';
  $mi{ 'TABLE'  } = $table;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'RESERVED_ID' };
}

sub insert
{
  my $self = shift;

  my $table  = uc shift;
  my $data   = shift;
  my $id     = shift;
  my $opt    = shift || {};
  
  my %mi;

  $mi{ 'XT'     } = 'I';
  $mi{ 'TABLE'  } = $table;
  $mi{ 'DATA'   } = $data;
  $mi{ 'ID'     } = $id;

#print STDERR Dumper( $opt );
  
  for( qw( LINK_TO_TABLE LINK_TO_FIELD LINK_TO_ID ) )
    {
    next unless exists $opt->{ $_ };
    $mi{ $_ } = $opt->{ $_ };
    }

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return $mo->{ 'NEW_ID' };
}

sub update
{
  my $self = shift;

  my $table  = uc shift;
  my $data   = shift;
  my $opt    = shift;
  
  my $filter = $opt->{ 'FILTER' } || {};
  my $id     = $opt->{ 'ID'     };
  my $lock   = $opt->{ 'LOCK'   };

  my %mi;

  $mi{ 'XT'     } = 'U';
  $mi{ 'TABLE'  } = $table;
  $mi{ 'DATA'   } = $data;
  $mi{ 'FILTER' } = $filter;
  $mi{ 'ID'     } = $id;
  $mi{ 'LOCK'   } = $lock;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return 1;
}

sub delete
{
  my $self = shift;

  boom "sub_delete is not yet implemented";
}

#-----------------------------------------------------------------------------

sub recalc
{
  my $self = shift;

  my $table  = uc shift;
  my $data   = shift;
  my $id     = shift;
  my $opt    = shift || {};
  
  my %mi;

  $mi{ 'XT'     } = 'L';
  $mi{ 'TABLE'  } = $table;
  $mi{ 'DATA'   } = $data;
  $mi{ 'ID'     } = $id;

  my $mo = $self->tx_msg( \%mi ) or return undef;

  return wantarray ? ( $mo->{ 'RDATA' }, $mo->{ 'MERRS' } ) : $mo->{ 'RDATA' };
}

### helpers ##################################################################

sub select_first1_by_id
{
  my $self   = shift;
  my $table  = shift;
  my $fields = shift;
  my $id     = shift;

  my $select   = $self->select( $table, $fields, { LIMIT => 1, FILTER => { '_ID' => $id } } ) or return undef;
  my $row_data = $self->fetch( $select ) or return undef;
                 $self->finish( $select );
  
  return $row_data;
}

sub read_field
{
  my $self  = shift;
  my $table = shift;
  my $field = shift;
  my $id    = shift;

  my $select   = $self->select( $table, $field, { LIMIT => 1, FILTER => { '_ID' => $id } } ) or return undef;
  my $row_data = $self->fetch( $select ) or return undef;
                 $self->finish( $select );
  
  return $row_data->{ $field };
}

sub count
{
  my $self  = shift;
  my $table = shift;
  my $opt    = shift;

  my $select   = $self->select( $table, 'COUNT(*)', $opt ) or return undef;
  my $row_data = $self->fetch( $select ) or return undef;
                 $self->finish( $select );
  
  return $row_data->{ 'COUNT(*)' };
}

##############################################################################
1;
