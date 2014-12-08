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
use Getopt::Long;
use NeedRestart qw(:interp);
use NeedRestart::Utils;

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

sub source {
    print STDERR "HI\n";
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


    use Data::Dumper;
    print STDERR "$LOGPREF ".Dumper(\%opts) if($self->{debug});

    chdir($cwd);

    return ();
}

sub resolver {
    my $self = shift;
    my $cmap = shift;
    my $class = shift;
    my @cp = @_;

    foreach my $cp (@cp) {
	if(-d $cp) {
	}
	elsif(-f $cp) {
	}
	else {
	    print STDERR "$LOGPREF ignore unknown classpath '$cp'" if($self->{debug});
	}
    }
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


    my $class = shift(@ARGV);
    return () unless($class =~ /\w+\.\w+/);

    my %cmap = ();
    $self->resolver(\%cmap, $class, $opts{cp});

    use Data::Dumper;
    print STDERR "$LOGPREF ".Dumper(\%cmap) if($self->{debug});

    chdir($cwd);

    return ();
}

1;
