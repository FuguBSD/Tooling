#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for the Python project files of a consumer repository
#
# This test is a synced copy, owned by FuguBSD/Tooling at
# python/sync/t/ci/python.t. The consumer owns pyproject.toml,
# .python-version, and uv.lock (MK-PYTHON-2), and the synced
# ruff.toml is the one Ruff configuration (MK-PYTHON-3). A
# [tool.ruff] section in pyproject.toml loses to ruff.toml in
# silence, so this test refuses it, and any of its subtables. The
# default TEST_GLOBS covers t/ci/*.t, so make test runs this in
# every python consumer.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root = "$RealBin/../..";

# _slurp($path):
#	Whole file as text, or undef with a failed assertion.
sub _slurp ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return;
	};
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

# MK-PYTHON-2: the consumer owns the project files, next to the
# synced configuration.
ok( -f "$root/pyproject.toml",  'pyproject.toml exists' );
ok( -f "$root/.python-version", '.python-version exists' );
ok( -f "$root/uv.lock",         'uv.lock exists' );
ok( -f "$root/ruff.toml",       'the synced ruff.toml exists' );

# MK-PYTHON-3: ruff.toml is the one Ruff configuration. The pattern
# also refuses a subtable such as [tool.ruff.lint], which TOML
# permits without the parent table.
unlike(
	_slurp("$root/pyproject.toml") // '',
	qr/^\[tool\.ruff[\].]/m,
	'pyproject.toml holds no [tool.ruff] section'
);

# MK-PYTHON-2: a dependency group holds Ruff, so uv run finds the
# locked release, never a PATH fallback of any version.
like(
	_slurp("$root/uv.lock") // '',
	qr/^name = "ruff"$/m,
	'the lockfile holds ruff'
);

done_testing();
