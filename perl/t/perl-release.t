#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for .github/workflows/perl-release.yml, per WFL-SIGN
#
# The workflow signs the release assets of every Perl distribution of
# the organization, so one defect here reaches four repositories.
# Nothing under .github/ runs outside a runner, so the test reads the
# workflow as text, as setup-gitleaks.t does for its action.
#
# Each guard reads one step and never the whole file. The file names
# the tarballs in five places, so a guard over the whole text would
# pass on a line of another step.

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

# _step($yml, $name):
#	The text of one step, from its name to the name of the next
#	step, or undef when the workflow holds no such step.
sub _step ( $yml, $name )
{
	my ($block) =
	    $yml =~ /^ {6}- name: \Q$name\E\n(.*?)(?=^ {6}- name: |\z)/ms;

	return $block;
}

plan skip_all => 'no perl-release workflow' unless -f $workflow;
my $yml = _slurp($workflow);

my $SIGN = _step( $yml, 'Sign the release assets' );

subtest 'the signing step reads the active slot' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

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

	# A value that reached the script text would become part of a
	# command. Every run step here is a block scalar, so a guard
	# that read the 'run:' line alone would never fire.
	my ($script) = $SIGN =~ /^\s+run: \|\n(.*)\z/ms;
	ok( $script, 'the step holds a script' ) or return;

	unlike( $script, qr/\$\{\{/,
		'no expression expands inside the script of the step' );
};

subtest 'a release with no key still releases' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	# The organization names no slot until FuguBSD/Website
	# publishes the first key, and FuguWeb must release before
	# that.
	like(
		$SIGN,
		qr/if \[ -z "\$SLOT" \]/,
		'an absent slot is what the step tests'
	);
	like( $SIGN, qr/signed=no/, 'it reports that it signed nothing' );

	# A slot that names an empty secret is a different thing. That
	# is a release that was meant to carry a signature.
	like(
		$SIGN,
		qr/slot \$SLOT names no key/,
		'and an empty secret of a named slot fails'
	);
	like(
		$SIGN,
		qr/and the slots are A and B/,
		'as does a slot word that names neither'
	);
};

subtest 'the manifest names both tarballs' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	# scripts/deps keys the signed manifest on the file name
	# (SYNC-DOWNLOAD-6), and a consumer can name the versioned
	# tarball or the stable one.
	like(
		$SIGN,
		qr/for name in "\$DIST-\$VERSION\.tar\.gz"/,
		'the versioned name enters the manifest'
	);
	like( $SIGN, qr/"\$DIST\.tar\.gz"/, 'and the stable name' );
	like( $SIGN, qr/sha256sum/,         'the step digests each file' );

	# The manifest names a file and never a path, because one
	# release directory holds unique names.
	like(
		$SIGN,
		qr/printf 'SHA256 \(%s\) = %s/,
		'and it writes the line form that the script parses'
	);
	like(
		$SIGN,
		qr{sort -o build/SHA256},
		'the order is fixed, so two runs write one file'
	);
};

subtest 'the manifest takes the name it is given' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	# The line form reserves a parenthesis, and a reader that
	# splits a line on a space needs a name with none.
	like(
		$SIGN,
		qr/the dist name holds a space or a/,
		'the step refuses a name that the form cannot carry'
	);

	# A digest that no read produced would sign a manifest of
	# nothing.
	like(
		$SIGN,
		qr/cannot digest/,
		'and it refuses a digest that it could not read'
	);
};

subtest 'the release attaches the manifest pair' => sub {
	my $release = _step( $yml, 'Release to GitHub' );
	ok( $release, 'the release step is there' ) or return;

	like( $release, qr{build/SHA256'},      'SHA256 reaches the release' );
	like( $release, qr{build/SHA256\.sig'}, 'and its signature' );
	like(
		$release,
		qr/steps\.sign\.outputs\.signed == 'yes'/,
		'and both only when the step signed'
	);
};

subtest 'the private key leaves no file behind' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	like( $SIGN, qr/umask 077/, 'the key file takes no wider mode' );

	# A removal on the success path alone would leave the key for
	# each step that follows a failure.
	like(
		$SIGN,
		qr/trap 'rm -rf "\$work"' EXIT/,
		'and the step removes it whatever the outcome'
	);

	# signify(1) refuses a key file with no final newline, so a
	# release with a key would fail at the signature.
	like(
		$SIGN,
		qr/printf '%s\\n' "\$key"/,
		'the key file ends in a newline'
	);
};

subtest 'the install runs beside no key' => sub {

	# An unpinned package install must not run while a private key
	# sits in the environment of the same step.
	my $install = _step( $yml, 'Install signify' );
	ok( $install, 'the install has a step of its own' ) or return;

	unlike( $install, qr/SIGNIFY_RELEASE_KEY/, 'and no key reaches it' );
	ok( $SIGN, 'the signing step is there' ) or return;
	unlike( $SIGN, qr/apt-get/, 'and the signing step installs nothing' );
};

done_testing();
