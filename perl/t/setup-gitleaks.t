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

# MK-GITLEAKS-4 keeps a second pin in the action until WFL-GITLEAKS
# retires it. The manifest pin and the action pin must name one
# version and one digest. Two pins otherwise run two binaries.
subtest 'the action pin matches the manifest pin' => sub {
	my $sums = _slurp("$root/deps/SHA256.txt");
	plan skip_all => 'no digest file' unless defined $sums;

	opendir my $dh, "$root/deps" or plan skip_all => 'no deps directory';
	my @manifest =
	    sort grep { /\.txt\z/ && !/\A(?:SHA256|KEYS)/ } readdir $dh;
	closedir $dh;

	# MK-GITLEAKS-4: the repository holds one manifest for each
	# operating system that it supports, so the operator gate runs
	# on each one.
	is_deeply(
		\@manifest,
		[ 'Darwin.txt', 'Linux.txt' ],
		'deps/ holds a manifest for each supported system'
	);

	# MK-GITLEAKS-4: every manifest of the repository provides
	# gitleaks, and it provides it in the tool environment.
	my ( %version, %url );
	for my $name (@manifest) {
		my $text = _slurp("$root/deps/$name") // next;
		my ($entry) =
		    grep { /\A\s*tool\s+bin\s+gitleaks\s/ } split /\n/, $text;
		ok( $entry, "deps/$name provides gitleaks in tool" ) or next;
		my ($v) = $entry =~ m{/download/v([0-9.]+)/};
		$version{$name} = $v;
		my ($u) = $entry =~ /\A\s*tool\s+bin\s+gitleaks\s+(\S+)/;
		$url{$name} = $u;
	}

	# MK-GITLEAKS-4 requires the entry, so an absent one fails
	# here. A skip_all after an assertion would turn the failed
	# assertion above into a pass.
	if ( !%version ) {
		fail('a manifest names gitleaks in the tool environment');
		return;
	}

	my ($default) = $yml =~ /default:\s*"([0-9.]+)"/;

	# Every manifest pins the operator gate of one platform, so
	# each one must name the version that the action pins.
	for my $name ( sort keys %version ) {
		is( $version{$name}, $default,
			"deps/$name pins the version of the action" );
	}
	my $version = $default;

	my %digest;
	for my $line ( split /\n/, $sums ) {
		$digest{$1} = $2
		    if $line =~ /\ASHA256 \(([^()\s]+)\) = ([0-9a-f]{64})\z/;
	}

	my ($checksum) = $yml =~ /default:\s*"([0-9a-f]{64})"/;

	# The digest file keys on the whole download URL, so the test
	# expands the Linux entry into the platform of the action. A
	# match on the file name alone would take the line of another
	# upstream that publishes the same asset name.
	# A skip_all after an assertion turns a failed one into a pass,
	# so an absent entry fails here instead.
	my $template = $url{'Linux.txt'};
	if ( !defined $template ) {
		fail('deps/Linux.txt names a gitleaks URL');
		return;
	}
	my $key = $template;
	$key =~ s/\{os\}/linux/g;
	$key =~ s/\{arch\}/x64/g;
	ok( exists $digest{$key}, "deps/SHA256.txt records $key" );
	is( $checksum, $digest{$key},
		'and the action pins the recorded linux_x64 digest' );
};

done_testing();
