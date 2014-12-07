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

package NeedRestart::Interp::Java::ClassFile;

use List::Util qw(sum);

# ClassFile {
#     u4             magic;
#     u2             minor_version;
#     u2             major_version;
#     u2             constant_pool_count;
#     cp_info        constant_pool[constant_pool_count-1];
#     u2             access_flags;
#     u2             this_class;
#     u2             super_class;
#     u2             interfaces_count;
#     u2             interfaces[interfaces_count];
#     u2             fields_count;
#     field_info     fields[fields_count];
#     u2             methods_count;
#     method_info    methods[methods_count];
#     u2             attributes_count;
#     attribute_info attributes[attributes_count];
# }

use constant {
    CF_MAGIC => 0xCAFEBABE,

    CF_HDR_MAGIC_TMPL => q(Nnnn),
    CF_HDR_MAGIC_KEYS => [qw(magic minor_version major_version constant_pool_count)],

    CF_HDR_CLASS_TMPL => q(nnn),
    CF_HDR_CLASS_KEYS => [qw(access_flags this_class super_class)],

    CF_CONSTANT_Utf8 => 1,
    CF_CONSTANT_Integer => 3,
    CF_CONSTANT_Float => 4,
    CF_CONSTANT_Long => 5,
    CF_CONSTANT_Double => 6,
    CF_CONSTANT_Class => 7,
    CF_CONSTANT_String => 8,
    CF_CONSTANT_Fieldref => 9,
    CF_CONSTANT_Methodref => 10,
    CF_CONSTANT_InterfaceMethodref => 11,
    CF_CONSTANT_NameAndType => 12,
    CF_CONSTANT_MethodHandle => 15,
    CF_CONSTANT_MethodType => 16,
    CF_CONSTANT_InvokeDynamic => 18,
};

my %CF_CONSTANT_lengths = (
    (CF_CONSTANT_Utf8) => q(n),
    (CF_CONSTANT_Integer) => q(N),
    (CF_CONSTANT_Float) => q(N),
    (CF_CONSTANT_Long) => q(NN),
    (CF_CONSTANT_Double) => q(NN),
    (CF_CONSTANT_Class) => q(n),
    (CF_CONSTANT_String) => q(n),
    (CF_CONSTANT_Fieldref) => q(nn),
    (CF_CONSTANT_Methodref) => q(nn),
    (CF_CONSTANT_InterfaceMethodref) => q(nn),
    (CF_CONSTANT_NameAndType) => q(nn),
    (CF_CONSTANT_MethodHandle) => q(Cn),
    (CF_CONSTANT_MethodType) => q(n),
    (CF_CONSTANT_InvokeDynamic) => q(nn),
);

my $LOGPREF = '[Java-CF]';

sub buf2struct {
    my $buf = shift;
    my $tpl = shift;

    return map { my $v = $_; (shift(@_) => $v); } unpack($tpl, $buf);
}

my %patlens = (
    C => 1,
    n => 2,
    N => 4,
);

sub tpllen {
    my $tpl = shift;

    return sum map {($patlens{$_} || 0)} split(//, $tpl);
}

sub load {
    my $class = shift;
    my $fn = shift;
    my $debug = shift;

    # open classfile from filename
    my $fh;
    unless(open($fh, '<', $fn)) {
	print STDERR "$LOGPREF Could not open '$fn': $!\n" if($debug);
	return undef;
    }
    binmode($fh);

    # check for magic number and some header values
    my $buf;
    read($fh, $buf, tpllen(CF_HDR_MAGIC_TMPL));
    my %header = buf2struct($buf, CF_HDR_MAGIC_TMPL, @{(CF_HDR_MAGIC_KEYS)});
    if($header{magic} != CF_MAGIC) {
	printf(STDERR "$LOGPREF $fn has bad magic value: 0x%x != 0x%x\n", $header{magic}, CF_MAGIC) if($debug);
	return undef;
    }

    # get class refs from CONSTANT_Pool
    my $i = 1;
    my %classrefs;
    my %utf8;
    while($i < $header{constant_pool_count}) {
	read($fh, $buf, 1);
	my $tag = unpack('C', $buf);

	if(exists($CF_CONSTANT_lengths{$tag})) {
	    read($fh, $buf, tpllen($CF_CONSTANT_lengths{$tag}));

	    if($tag == CF_CONSTANT_Utf8) {
		my $len = unpack('n', $buf);
		read($fh, $buf, $len);
		$utf8{$i} = $buf;
	    }
	    elsif($tag == CF_CONSTANT_Class) {
		my $idx = unpack('n', $buf);
		$classrefs{$i} = $idx;
	    }
	    # Long and Double are counting twice
	    elsif($tag == CF_CONSTANT_Double || $tag == CF_CONSTANT_Long) {
		$i++;
	    }
	}
	else {
	    print STDERR "$LOGPREF $fn #$i has unkown CONTENT_info entry (tag $tag)\n" if($debug);
	    return undef;
	}

	$i++;
    }

    # get class info from header (this_class)
    read($fh, $buf, tpllen(CF_HDR_CLASS_TMPL));
    %header = (%header, buf2struct($buf, CF_HDR_CLASS_TMPL, @{(CF_HDR_CLASS_KEYS)}));
    my $this_class = $utf8{ $classrefs{ $header{this_class} }};
    close($fh);

    # strip inner classes;
    my @classes = map { ($utf8{$_} =~ /^$this_class(\$|$)/ ? () : $utf8{$_}) } values %classrefs;

    return bless {
	debug => $debug,
	cf_fn => $fn,
	cf_class => $this_class,
	cf_classrefs => \@classes,
    }, $class;
}

sub getClass {
    my $self = shift;

    return $self->{cf_class};
}

sub getClassRefs {
    my $self = shift;

    return @{$self->{cf_classrefs}};
}
