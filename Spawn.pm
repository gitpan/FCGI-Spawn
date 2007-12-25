package FCGI::Spawn;

use vars qw($VERSION);
BEGIN {
  $VERSION = '0.11'; 
  $FCGI::Spawn::Default = 'FCGI::Spawn';
}

=head1 NAME

 FCGI::Spawn - process manager/application server for FastCGI protocol.

=head1 SYNOPSIS

Tried to get know satisfaction with bugzilla... There's no place to dig out that Bugzilla doesn't work out with FastCGI other than Bugzilla's own Bugzilla though.
This is my ./run for daemontools by http://cr.yp.to:

 ===
	#!/usr/bin/perl -w
	use strict;
	use warnings;
	
	our $bugzillaDir; 
	
	BEGIN {
	        $bugzillaDir = '/var/www/somepath/bugzilla';
	        chdir $bugzillaDir or die $!;
	}
	
	
	use lib '/var/www/lib/perl';
	use FCGI::Spawn;
	use lib $bugzillaDir;
	use Bugzilla;
	use Bugzilla::Flag;
	use Bugzilla::CGI;
	use Bugzilla::FlagType;
	use Bugzilla::Util;
	use Bugzilla::Config;
	use Bugzilla::Error;
	use Bugzilla::Template;
	use Bugzilla::User;
	use Bugzilla::DB qw(:DEFAULT :deprecated);
	
	use Carp; $SIG{__DIE__} = sub{ print @_; print Carp::longmess };
	
	my $spawn = FCGI::Spawn->new({ n_processes => 5, sock_name => "/tmp/spawner.sock", sock_chown => [qw/-1 10034/],
	        });
	$spawn -> spawn;
 ===

=head2 Why daemontools?

They have internal log-processing and automatical daemon restart on fault. Sure they posess control like stop/restart. Check em out and see. But those are not strictly necessary.
Another reason is that i'm not experienced much with Perl daemons building like getting rid of STD* file handles and SIG* handling.

=head1 DESCRIPTION

FCGI::Spawn is used to serve as a FastCGI process manager. Besides  the features the FCGI::ProcManager posess itself, the FCGI::Spawn is targeted as web server admin understandable instance for building the own fastcgi server with copy-on-write memory sharing among forks and with single input parameters like socket path and processes number.
Another thing to mention is that it is able to execute any file pointed by Web server ( FastCGI requester ). So we have the daemon that is hot ready for hosting providing :-)

Every other thing is explained in FCGI::ProcManager docs.

=head1 PREREQUISITES

Be sure to have FCGI::ProcManager.

=head1 METHODS

class or instance

=head2 new({hash parameters})

Constructs a new process manager.  Takes an option hash of the sock_name and sock_chown initial parameter values, and passes the entire hash rest to ProcManager's constructor.
The parameters are:

=over

=item *

sock_name is the socket's path, the parameter for FCGI::OpenSocket;

=item *

sock_chown is the array reference which sets the parameters for chown on newly created socket, when needed.

=back

Every other parameter is passed "as is" to the FCGI::ProcManager's constructor.

=head2 spawn

Fork a new process handling request like that being processed by web server.

=cut


use strict;
use warnings;

use FCGI;
use File::Basename;
use FCGI::ProcManager;

sub new {
	my $class = shift;
	my $properties = shift;
	my $proc_manager = FCGI::ProcManager->new({      n_processes => $properties->{n_processes} });
	my $sock_name = $properties->{sock_name};
	unlink $sock_name;
	my $socket = FCGI::OpenSocket( $sock_name, 5 );
	$properties->{socket} = $socket;
	chown @{ $properties->{sock_chown} }, $sock_name if defined $properties->{sock_chown};
	$properties->{request} = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR,
    \%ENV, $socket );
	$proc_manager->pm_manage();
	$properties->{proc_manager} = $proc_manager;
	bless $properties, $class;
}

sub spawn {
	my $this = shift;
	my( $request, $proc_manager, $socket ) = map { $this -> {$_} } qw/request proc_manager socket/;
	#my %fcgi_spawn_main = %main:: ;
	while( $request->Accept() >= 0 ) {
 		$proc_manager->pm_pre_dispatch();
		my $sn = $ENV{SCRIPT_FILENAME};
		my $dn = dirname $sn;
		my $bn = basename $sn;
		chdir $dn;
		do $sn or print $!.$bn;
		delete $INC{ $sn };
 		$proc_manager->pm_post_dispatch();
	#	foreach ( keys %main:: ){ delete $main::{ $_ } unless defined $fcgi_spawn_main{ $_ } };
	}
	FCGI::CloseSocket( $socket );
}

1;
