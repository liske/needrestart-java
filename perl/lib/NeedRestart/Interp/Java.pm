# needrestart-java - Java interpreter support for needrestart
#
# Authors:
#   Thomas Liske <thomas@fiasko-nw.net>
#
# Copyright Holder:
#   2014 (C) Thomas Liske [http://fiasko-nw.net/~thomas/]
#
# License:
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this package; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#

package NeedRestart::Interp::Java;

use strict;
use warnings;

use parent qw(NeedRestart::Interp);
use Cwd qw(abs_path getcwd);
use File::Basename;
use Getopt::Long;
use NeedRestart qw(:interp);
use NeedRestart::Utils;

use NeedRestart::Interp::Java::JarFile;
use NeedRestart::Interp::Java::ClassFile;

my $LOGPREF = '[Java]';

needrestart_interp_register(__PACKAGE__);

sub isa {
    my $self = shift;
    my $pid = shift;
    my $bin = shift;

    return 1 if($bin =~ m@/.+/bin/java@);

    return 0;
}

sub cpbuild {
    my $self = shift;
    my $pid = shift;
    my $opts = shift;

    my $javadir = abs_path(dirname(nr_readlink($pid)).'/..');
    my @cp = ("$javadir/lib/rt.jar", <$javadir/lib/ext/*.jar>, <$javadir/lib/ext/*.zip>);

    if(exists($opts->{jar})) {
	push(@cp, $opts->{jar});
    }
    elsif(exists($opts->{cp})) {
	push(@cp, @{$opts->{cp}});
    }

    return @cp;
}

sub _scan($$$$$$) {
    my $debug = shift;
    my $pid = shift;
    my $class = shift;
    my $files = shift;
    my $cpaths = shift;
    my $cache = shift;

    print STDERR "$LOGPREF searching $class...\n" if($debug);
    unless(exists($cache->{$class})) {
	foreach my $cp (@$cpaths) {
	    if(-f $cp) {
		print STDERR "$LOGPREF scanning $cp...\n" if($debug);

		if((my $jf = NeedRestart::Interp::Java::JarFile->load($cp))) {
		    foreach my $c (map {
			my $f = $_->{fileName};
			$f =~ s@/@.@g;
			$f =~ s/\.class$//;
			$f;
				   } $jf->getClassFiles) {
			$cache->{$c} = $cp;
		    }

		    if(exists($cache->{$class})) {
			print STDERR "$LOGPREF found $class within $cp\n" if($debug);
			last;
		    }
		}
	    }
	}
    }

    if(exists($cache->{$class})) {
	# track file
	$files->{$cache->{$class}}++;
    }
}

sub source {
    # not implemented
    return undef;

    my $self = shift;
    my $pid = shift;
    my $ptable = nr_ptable_pid($pid);
    my $cwd = getcwd();
    chdir($ptable->{cwd});

    # get original ARGV
    (my $bin, local @ARGV) = nr_parse_cmd($pid);

    # eat Java's command line options
    my $p = Getopt::Long::Parser->new(
	config => [qw(bundling_override)],
	);
    my %opts;
    $p->getoptions(\%opts,
		   'cp|classpath=s@',
		   'jar=s',
		   'D=s@',
		   'X=s@',
    );

    chdir($cwd);

    return undef;
}

sub files {
    my $self = shift;
    my $pid = shift;
    my $ptable = nr_ptable_pid($pid);
    my $cwd = getcwd();
    chdir($ptable->{cwd});

    # get original ARGV
    (my $bin, local @ARGV) = nr_parse_cmd($pid);

    # eat Java's command line options
    my $p = Getopt::Long::Parser->new(
	config => [qw(bundling_override)],
	);
    my %opts;
    $p->getoptions(\%opts,
		   'cp|classpath=s@',
		   'jar=s',
		   'D=s@',
		   'X=s@',
    );

    my @cp = $self->cpbuild($pid, \%opts);
    
    my $class = shift(@ARGV);
    return () unless($class =~ /\w+\.\w+/);

    my %files;
    my %cfcache;
    _scan($self->{debug}, $pid, $class, \%files, \@cp, \%cfcache);

    my %ret = map {
	my $stat = nr_stat($_);
	$_ => ( defined($stat) ? $stat->{ctime} : undef );
    } keys %files;

    chdir($cwd);
    return %ret;
}

1;
