#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The root copies of the org files must equal the canon
#
# Tooling owns the org pack and also lives by it. sync refuses to run
# inside this repository, so this test holds the root copies to the
# canon byte for byte (SYNC-CHECK-3). It also compiles the canonical
# scripts, so a syntax error never reaches a consumer.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root = "$RealBin/../..";

my @COPIES = (
	'CLAUDE.md',
	'spec/CLAUDE.md',
	'plans/CLAUDE.md',
	'plans/.gitkeep',
	'.claude/skills/review-panel/SKILL.md',
	'.github/pull_request_template.md',
);

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

for my $path (@COPIES) {
	is(
		_slurp("$root/$path"),
		_slurp("$root/org/sync/$path"),
		"$path equals the canon"
	);
}

for my $script (qw(deps spec-check ste-lint)) {
	my $output = `perl -c "$root/org/sync/scripts/$script" 2>&1`;
	is( $? >> 8, 0, "$script compiles" ) or diag($output);
}

done_testing();
