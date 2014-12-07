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
use Getopt::Std;
use NeedRestart qw(:interp);
use NeedRestart::Utils;

use NeedRestart::Interp::ClassFile;

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
    my $self = shift;
    my $pid = shift;
    my $ptable = nr_ptable_pid($pid);
    my $cwd = getcwd();
    chdir($ptable->{cwd});

    chdir($cwd);

#    return $src;
}

sub files {
    my $self = shift;
    my $pid = shift;
    my $ptable = nr_ptable_pid($pid);
    my $cwd = getcwd();
    chdir($ptable->{cwd});

    # get original ARGV
    (my $bin, local @ARGV) = nr_parse_cmd($pid);

    chdir($cwd);
#    return %ret;
}

1;
