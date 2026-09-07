#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for .github/workflows/perl-release.yml, per WFL-SIGN
#
# The workflow signs the release assets of every Perl distribution of
# the organization, so one defect here reaches four repositories.
# Nothing under .github/ runs outside a runner, so the test reads the
# workflow as text, as setup-gitleaks.t does for its action.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root     = "$RealBin/../..";
my $workflow = "$root/.github/workflows/perl-release.yml";

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

plan skip_all => 'no perl-release workflow' unless -f $workflow;
my $yml = _slurp($workflow);

subtest 'the signing step reads the active slot' => sub {

	# A step that named one fixed secret could not rotate without
	# a human, so the variable decides and the secrets keep fixed
	# names.
	like(
		$yml,
		qr/SLOT:\s*\$\{\{\s*vars\.SIGNIFY_RELEASE_SLOT\s*\}\}/,
		'the variable names the active slot'
	);
	like(
		$yml,
		qr/KEY_A:\s*\$\{\{\s*secrets\.SIGNIFY_RELEASE_KEY_A\s*\}\}/,
		'and slot A reaches the step'
	);
	like(
		$yml,
		qr/KEY_B:\s*\$\{\{\s*secrets\.SIGNIFY_RELEASE_KEY_B\s*\}\}/,
		'and slot B with it'
	);

	# A secret that reached the step through the script text would
	# become part of a command.
	unlike(
		$yml,
		qr/run:[^\n]*secrets\.SIGNIFY/,
		'no secret reaches a run line by expansion'
	);
};

subtest 'a release with no key still releases' => sub {

	# The organization holds no key until FuguBSD/Website
	# publishes one, and FuguWeb must release before that.
	like( $yml, qr/signed=no/, 'the step reports that it signed nothing' );
	like( $yml, qr/exit 0/,    'and it leaves the release to continue' );
	like(
		$yml,
		qr/if \[ -z "\$key" \]/,
		'because an empty slot is what it tests'
	);
};

subtest 'the manifest names both tarballs' => sub {

	# scripts/deps keys the signed manifest on the file name
	# (SYNC-DOWNLOAD-6), and a consumer can name the versioned
	# tarball or the stable one.
	# The expression holds a dollar and two braces, which Perl
	# reads as a dereference inside a pattern. The literal
	# therefore arrives as a single-quoted string.
	my $versioned = '-${{ steps.version.outputs.version }}.tar.gz';
	ok( index( $yml, $versioned ) >= 0,
		'the versioned name reaches the manifest' );
	like( $yml, qr/sha256sum/, 'the step digests the files' );
	like(
		$yml,
		qr/SHA256 \(" \$2 "\) = " \$1/,
		'and it writes the line form that the script parses'
	);

	# One release directory holds unique names, so the key of the
	# manifest is the name alone and never a path.
	like(
		$yml,
		qr/\( cd build &&/,
		'the digest runs in the build directory, so no path enters'
	);
};

subtest 'the release attaches the manifest pair' => sub {
	like( $yml, qr{build/SHA256'},      'SHA256 reaches the release' );
	like( $yml, qr{build/SHA256\.sig'}, 'and its signature' );
	like(
		$yml,
		qr/steps\.sign\.outputs\.signed == 'yes'/,
		'and both only when the step signed'
	);
};

subtest 'the private key leaves no file behind' => sub {
	like( $yml, qr/umask 077/,       'the key file takes no wider mode' );
	like( $yml, qr/rm -rf "\$work"/, 'and the step removes it' );
};

done_testing();
