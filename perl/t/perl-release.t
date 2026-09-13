#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for .github/workflows/perl-release.yml, per WFL-SIGN and
# per WFL-ACTIONS-4
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

my $SIGN   = _step( $yml, 'Sign the release assets' );
my $ASSETS = _step( $yml, 'Check the release assets' );

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

	# The step must leave the release to continue. Without the
	# exit the run falls into the arm that names an unknown slot,
	# and every release then fails.
	like(
		$SIGN,
		qr/signed=no" >> "\$GITHUB_OUTPUT"\n\s+exit 0/,
		'and it leaves the release to continue'
	);

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

subtest 'the build step reaches the version and the names' => sub {
	my $build = _step( $yml, 'Build the distribution tarball' );
	ok( $build, 'the build step is there' ) or return;

	# The step exports no name that a make fragment leaves open,
	# per WFL-ACTIONS-4. A step that exported DIST replaced the
	# path of scripts/dist, and the recipe then ran the
	# distribution name as a command. perl/t/workflow-env.t holds
	# the general guard, and this one holds the step that broke.
	like(
		$build,
		qr/DIST_NAME:\s*\$\{\{\s*inputs\.dist\s*\}\}/,
		'the distribution name reaches it under a free name'
	);
	like(
		$build,
qr/DIST_VERSION:\s*\$\{\{\s*steps\.version\.outputs\.version\s*\}\}/,
		'and the version of this release with it'
	);
	unlike( $build, qr/^\s+DIST:/m,    'and never as DIST' );
	unlike( $build, qr/^\s+VERSION:/m, 'and never as VERSION' );

	# The command line beats the environment, so the recipe takes
	# the version of this release and never a stale one.
	like(
		$build,
		qr/make dist VERSION="\$DIST_VERSION"/,
		'the recipe takes the version on the command line'
	);

	# The stable name serves releases/latest/download, which the
	# deps manifest of each consumer names. The copy stands on two
	# lines, so one match reads both. A lost continuation would
	# leave the destination as a command of its own.
	like(
		$build,
		qr{
			cp \s "build/\$DIST_NAME-\$DIST_VERSION\.tar\.gz"
			\s* \\ \n \s+ "build/\$DIST_NAME\.tar\.gz"
		}x,
		'the copy joins the versioned name to the stable one'
	);
};

subtest 'the manifest names both tarballs' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	# scripts/deps keys the signed manifest on the file name
	# (SYNC-DOWNLOAD-6), and a consumer can name the versioned
	# tarball or the stable one.
	like(
		$SIGN,
		qr/for name in "\$DIST_NAME-\$DIST_VERSION\.tar\.gz"/,
		'the versioned name enters the manifest'
	);
	like( $SIGN, qr/"\$DIST_NAME\.tar\.gz"/, 'and the stable name' );
	like( $SIGN, qr/sha256sum/,              'the step digests each file' );

	# The manifest names a file and never a path, because one
	# release directory holds unique names. A key that held a path
	# makes scripts/deps die for every consumer, so the guard
	# reads the argument of the printf and not the format alone.
	like(
		$SIGN,
		qr/printf 'SHA256 \(%s\) = %s\\n' "\$name" "\$digest"/,
		'and it writes the line form with the bare name'
	);
	unlike(
		$SIGN,
		qr{printf 'SHA256[^\n]*"build/},
		'so no path enters the manifest'
	);
	like(
		$SIGN,
		qr{sort -o build/SHA256},
		'the order is fixed, so two runs write one file'
	);
};

subtest 'the manifest takes the name it is given' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	# The manifest reader of a consumer takes no whitespace and no
	# parenthesis in a key.
	like(
		$SIGN,
		qr/the dist name holds whitespace or a/,
		'the step refuses a name that the form cannot carry'
	);
	like( $SIGN, qr/\*\[\[:space:\]/,
		'and the class holds every whitespace, a tab included' );

	# A release with no slot signs nothing, and a name that no
	# manifest can carry is still a name that a later release
	# would sign. The guard therefore runs first.
	my ($before) = $SIGN =~ /\A(.*?)the dist name holds/s;
	ok( defined $before, 'the guard is in the step' );
	unlike(
		$before,
		qr/-z "\$SLOT"/,
		'and it runs before the release with no slot leaves'
	);

	# A digest that no read produced would sign a manifest of
	# nothing.
	like(
		$SIGN,
		qr/cannot digest/,
		'and it refuses a digest that it could not read'
	);
};

subtest 'a caller can name one more release asset' => sub {

	# The three callers of today name no asset. A required input,
	# or a default that held a name, would change every release of
	# the organization.
	my ($input) = $yml =~ /^ {6}assets:\n((?:^ {8}\N+\n)+)/m;
	ok( $input, 'the workflow takes an assets input' ) or return;

	like( $input, qr/^ {8}required: false$/m, 'the input is optional' );
	like( $input, qr/^ {8}type: string$/m,    'it takes a list of names' );
	like( $input, qr/^ {8}default: ""$/m,     'and its default is empty' );
};

subtest 'the check step reads the assets before the key' => sub {
	ok( $ASSETS, 'the check step is there' ) or return;

	# The list reaches the shell through the environment, under a
	# name that carries the scope of the workflow. WFL-ACTIONS-9
	# asks for the prefix, because no test holds a shared workflow
	# to the fragments of a consumer.
	like(
		$ASSETS,
		qr/DIST_ASSETS:\s*\$\{\{\s*inputs\.assets\s*\}\}/,
		'the list reaches the step under a free name'
	);
	unlike( $ASSETS, qr/secrets\./, 'and no secret reaches it' );

	# A bad name and an absent file are both faults of the build.
	# The run must stop on one before the signing step reads a
	# key, so the step order carries the guard.
	my $build_at = index $yml, '- name: Build the distribution tarball';
	my $check_at = index $yml, '- name: Check the release assets';
	my $sign_at  = index $yml, '- name: Sign the release assets';
	ok( $build_at < $check_at, 'the build writes the files first' );
	ok( $check_at < $sign_at,  'and the check runs before the key' );

	# The name guard of the signing step, and a / with it. The
	# manifest names a file and never a path.
	like(
		$ASSETS,
		qr{\*\[\[:space:\]\\\(\\\)/\]\*\)},
		'the step refuses whitespace, a parenthesis and a /'
	);
	like(
		$ASSETS,
		qr{if \[ ! -f "build/\$name" \]},
		'and a name that the build wrote no file for'
	);
	like( $ASSETS, qr/exit 1/, 'and each refusal stops the run' );

	# The release step takes one list, and the two tarballs stand
	# first in it. A caller that names no asset gets those two.
	like(
		$ASSETS,
		qr{echo "build/\$DIST_NAME-\$DIST_VERSION\.tar\.gz"},
		'the list holds the versioned tarball'
	);
	like(
		$ASSETS,
		qr{echo "build/\$DIST_NAME\.tar\.gz"},
		'and the stable one'
	);
	like( $ASSETS, qr{echo "build/\$name"}, 'and each asset after them' );
	like(
		$ASSETS,
		qr{>> "\$GITHUB_OUTPUT"},
		'and the step writes the list to an output'
	);
};

subtest 'the manifest names each asset of the caller' => sub {
	ok( $SIGN, 'the signing step is there' ) or return;

	like(
		$SIGN,
		qr/DIST_ASSETS:\s*\$\{\{\s*inputs\.assets\s*\}\}/,
		'the list reaches the signing step too'
	);

	# One loop writes every line, so an asset takes the line form
	# of the tarballs. The loop stands on two lines: a lost
	# continuation would leave the stable name as a command of its
	# own.
	like(
		$SIGN,
		qr{
			for \s name \s in
			\s "\$DIST_NAME-\$DIST_VERSION\.tar\.gz"
			\s* \\ \n \s+ "\$DIST_NAME\.tar\.gz"
			\s \$DIST_ASSETS; \s do
		}x,
		'and the loop names the list beside the two tarballs'
	);

	# A line that the sort never read would leave two runs with
	# two manifests of one release.
	like(
		$SIGN,
		qr{\$DIST_ASSETS.*sort -o build/SHA256}s,
		'the loop runs before the sort'
	);

	# The loop is the one writer of the manifest. A caller that
	# names no asset therefore gets the manifest of today, line
	# for line.
	my $writes = () = $SIGN =~ m{>> build/SHA256}g;
	is( $writes, 1, 'and no other line reaches the manifest' );
};

subtest 'the release attaches the manifest pair' => sub {
	my $release = _step( $yml, 'Release to GitHub' );
	ok( $release, 'the release step is there' ) or return;

	# The check step held each name, so the release attaches the
	# list that it wrote and no name of its own.
	like(
		$release,
		qr/steps\.assets\.outputs\.files/,
		'the list of the check step reaches the release'
	);

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
