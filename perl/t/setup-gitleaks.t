#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for actions/setup-gitleaks, per the workflows specification
#
# The action installs the binary that reads every secret finding, so
# the release is pinned and the checksum verifies the download
# (WFL-GITLEAKS-1). The test reads the action as text, as
# setup-uv.t does for the uv toolchain.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root   = "$RealBin/../..";
my $action = "$root/actions/setup-gitleaks/action.yml";

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

plan skip_all => 'no setup-gitleaks action' unless -f $action;
my $yml = _slurp($action);

subtest 'the action pins the release' => sub {
	like( $yml, qr/^\s+version:$/m, 'declares a version input' );
	like(
		$yml,
		qr/^\s+default:\s*"\d+\.\d+\.\d+"\s*$/m,
		'defaults to a pinned release'
	);
	like( $yml, qr/is not a release number/,
		'rejects a malformed version' );

	# The inputs reach the shell through env, never by raw
	# interpolation into the script, as setup-uv does it.
	like(
		$yml,
		qr/^\s+GITLEAKS_VERSION:\s*\$\{\{\s*inputs\.version\s*\}\}/m,
		'the version input passes through env'
	);
	like(
		$yml,
		qr/^\s+GITLEAKS_SHA256:\s*\$\{\{\s*inputs\.checksum\s*\}\}/m,
		'the checksum input passes through env'
	);
	my @raw = grep { /\$\{\{/ && !/^\s+[A-Z0-9_]+:\s*\$\{\{/ }
	    split /\n/, $yml;
	is( "@raw", q{}, 'no expression reaches the script raw' );

	# A pinned release tarball, not an action (WFL-GITLEAKS-1).
	# The third-party sweep of setup-perl.t covers the uses:
	# lines.
	like(
		$yml,
		qr{releases/download/v\$\{GITLEAKS_VERSION\}},
		'installs the pinned release tarball'
	);
};

subtest 'the checksum verifies the download' => sub {
	like( $yml, qr/^\s+checksum:$/m, 'declares a checksum input' );
	like(
		$yml,
		qr/^\s+default:\s*"[0-9a-f]{64}"\s*$/m,
		'defaults to a sha256 value'
	);
	like(
		$yml,
		qr/\|\s*sha256sum -c -/,
		'the checksum runs against the download'
	);

	# The verification runs before the install: a changed tarball
	# never reaches the path.
	my $verify  = index $yml, 'sha256sum -c';
	my $install = index $yml, 'install -m 755';
	cmp_ok( $verify,  '>', -1,      'the verification exists' );
	cmp_ok( $install, '>', $verify, 'and runs before the install' );
};

done_testing();
