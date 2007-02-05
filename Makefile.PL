use 5.005;
use strict;

use ExtUtils::MakeMaker;

my @all_module_filenames = (
	"perllib/Text/WikiText.pm",
	glob("perllib/Text/WikiText/*.pm"),
	glob("perllib/Text/WikiText/*/*.pm"),
);

WriteMakefile(
	NAME => 'Text::WikiText',
	DISTNAME => 'wikitext',
	dist => {
		# default CP 'ln' is buggy, it changes source file permissions
		DIST_CP => 'cp',
		COMPRESS => 'gzip --best --force',
	},
	test => {
		TESTS => 'tests/*-[1-9]',
	},
	PM => {
		map {
			my $t = $_; $t =~ s!^perllib/!!;
			($_, '$(INST_LIB)/' . $t)
		} @all_module_filenames
	},
	# this translation should not be needed, but MakeMaker is buggy again
	MAN3PODS => {
		map {
			my $t = $_; $t =~ s!^perllib/!!; 
			$t =~ s!/!::!g; $t =~ s/\.pm$//;
			($_, '$(INST_MAN3DIR)/' . "$t.3pm")
		} @all_module_filenames
	},
	EXE_FILES => [ 'bin/wikitext-convert' ],
	VERSION_FROM => 'perllib/Text/WikiText.pm',
	ABSTRACT => 'WikiText Markup Conversion',
	AUTHOR => 'Enno Cramer <uebergeek@web.de>, Mikhael Goikhman <migo@homemail.com>',
);

open MANIFEST, "<MANIFEST";
my @old_lines = grep !/^META.yml/, <MANIFEST>;
close MANIFEST;
my @new_lines = map { "$_\n" } (
	qw(
		AUTHORS
		COPYING
		Makefile.PL
		MANIFEST
		INSTALL
		NEWS
		README
	),
	glob("bin/*"),
	glob("doc/*"),
	@all_module_filenames,
	glob("tests/*-[1-9]"),
);
if (join(',', @old_lines) ne join(',', @new_lines)) {
	print "Creating MANIFEST file\n";
	open MANIFEST, ">MANIFEST" or die "Can't write MANIFEST: $!\n";
	print MANIFEST @new_lines;
	close MANIFEST;
}

