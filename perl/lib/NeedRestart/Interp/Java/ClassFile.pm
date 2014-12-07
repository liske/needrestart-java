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
    
    my $fh;

    unless(open($fh, '<', $fn)) {
	print STDERR "Could not open '$fn': $!\n" if($debug);
	return undef;
    }
    binmode($fh);

    my $buf;
    read($fh, $buf, 4 + 2 + 2 + 2);
    
    my %header = buf2struct($buf, "Nnnn", qw(magic minor_version major_version constant_pool_count));
    if($header{magic} != CF_MAGIC) {
	printf(STDERR "$fn has bad magic value: 0x%x != 0x%x\n", $header{magic}, CF_MAGIC) if($debug);
	return undef;
    }

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
	    print STDERR "$fn #$i has unkown CONTENT_info entry (tag $tag)\n" if($debug);
	    return undef;
	}

	$i++;
    }

    read($fh, $buf, 6);
    my %header = (%header, buf2struct($buf, "nnn", qw(access_flags this_class super_class)));
    my $this_class = $utf8{ $classrefs{ $header{this_class} }};
    close($fh);
    
    # strip inner classes;
    my @classes = map { ($utf8{$_} =~ /^$this_class(\$|$)/ ? () : $utf8{$_}) } values %classrefs;
    
    return bless {
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
