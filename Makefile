all:
	cd perl && perl Makefile.PL PREFIX=$(PREFIX) INSTALLDIRS=vendor 
	cd perl && $(MAKE)

install: all
	cd perl && $(MAKE) install

clean:
	[ ! -f perl/Makefile ] || ( cd perl && $(MAKE) realclean ) 
