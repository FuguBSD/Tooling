#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The root copies of the org files must equal the canon
#
# Tooling owns the org pack and also lives by it. sync refuses to run
# inside this repository, so this test holds the root copies to the
# canon byte for byte (SYNC-CHECK-3). The copy list derives from the
# canon tree, so a new canon file cannot escape the gate, and the
# orphan sweep catches a root skill whose canon file is gone.
# scripts/ runs in place and t/ serves the consumers, so neither has
# a root copy. The test also compiles the canonical scripts, so a
# syntax error never reaches a consumer.

use v5.36;
use Test::More;
use File::Find ();
use FindBin    qw($RealBin);

my $root  = "$RealBin/../..";
my $canon = "$root/org/sync";

# _walk($base, $strip):
#	Every file under the base, relative to the strip prefix.
sub _walk ( $base, $strip )
{
	my @files;
	File::Find::find( {
			no_chdir => 1,
			wanted   => sub {
				return unless -f $File::Find::name;
				my $rel = $File::Find::name;
				$rel =~ s{^\Q$strip/\E}{};
				push @files, $rel;
			},
		},
		$base
	);

	my @sorted = sort @files;

	return @sorted;
}

# _slurp($path):
#	Whole file as bytes, or undef with a failed assertion.
sub _slurp ($path)
{
	open my $fh, '<:raw', $path or do {
		fail("$path is readable");
		return;
	};
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

my @copies = grep { !m{^(?:scripts|t)/} } _walk( $canon, $canon );
ok( scalar @copies, 'the canon walk finds the org files' );

for my $path (@copies) {
	is( _slurp("$root/$path"), _slurp("$canon/$path"),
		"$path equals the canon" );
}

# SYNC-CHECK-4: the root holds a copy of the dispatcher, of each
# included pack fragment, and of each pack configuration that the
# root gates read. The walk above covers the GNUmakefile and
# mk/org.mk; the perl and python fragments live in their packs. The
# path Makefile stays free for the BSD dispatcher (MK-DISPATCH-4).
is(
	_slurp("$root/mk/perl.mk"),
	_slurp("$root/perl/sync/mk/perl.mk"),
	'mk/perl.mk equals the canon'
);
is(
	_slurp("$root/mk/python.mk"),
	_slurp("$root/python/sync/mk/python.mk"),
	'mk/python.mk equals the canon'
);
is(
	_slurp("$root/ruff.toml"),
	_slurp("$root/python/sync/ruff.toml"),
	'ruff.toml equals the canon'
);
is(
	_slurp("$root/.perlcriticrc"),
	_slurp("$root/perl/sync/.perlcriticrc"),
	'.perlcriticrc equals the canon'
);
is(
	_slurp("$root/.perltidyrc"),
	_slurp("$root/perl/sync/.perltidyrc"),
	'.perltidyrc equals the canon'
);
ok( !-f "$root/Makefile", 'the root holds no Makefile' );

my @orphans = grep { !-f "$canon/$_" } _walk( "$root/.claude", $root );
is( "@orphans", q{}, 'no orphaned root copy under .claude' );

for my $script (qw(deps spec-check ste-lint)) {
	my $output = `perl -c "$canon/scripts/$script" 2>&1`;
	is( $? >> 8, 0, "$script compiles" ) or diag($output);
}

my $sh = `sh -n "$canon/scripts/ftp" 2>&1`;
is( $? >> 8, 0, 'ftp parses' ) or diag($sh);

done_testing();
