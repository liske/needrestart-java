use ExtUtils::MakeMaker;

WriteMakefile(
    'AUTHOR'		=> 'Thomas Liske <thomas@fiasko-nw.net>',
    'LICENSE'		=> 'gpl',
    'NAME'		=> 'NeedRestart::Interp::Java',
    'PREREQ_PM'		=> {
	Archive::Zip => 0,
	List::Util => 0,
    },
);
