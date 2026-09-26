#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for actions/brew-bump/action.yml, per WFL-BREW
#
# Nothing under actions/ runs outside a runner, so the test reads the
# action as text, as setup-perl.t reads the setup-perl action. Each
# guard reads one step. A wrong step here reaches the tap on the
# next release of five repositories, and no test of a caller reads
# this file.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $root   = "$RealBin/../..";
my $action = "$root/actions/brew-bump/action.yml";

# The input that each BUMP_ name carries into the script step
# (WFL-BREW-6).
my %BIND = (
	repository => 'BUMP_REPOSITORY',
	url        => 'BUMP_URL',
	file       => 'BUMP_FILE',
	tag        => 'BUMP_TAG',
);

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
#	step, or undef when the action holds no such step.
sub _step ( $yml, $name )
{
	my ($block) =
	    $yml =~ /^ {4}- name: \Q$name\E\n(.*?)(?=^ {4}- name: |\z)/ms;

	return $block;
}

# _script($step):
#	The `run: |` script of one step, or undef.
sub _script ($step)
{
	my ($script) = ( $step // '' ) =~ /^\s+run: \|\n(.*)\z/ms;

	return $script;
}

plan skip_all => 'no brew-bump action' unless -f $action;
my $yml = _slurp($action);

my $CHECKOUT = _step( $yml, 'Checkout the tap' );
my $BUMP     = _step( $yml, 'Bump the formula' );

subtest 'the checkout takes the tap with the deploy key' => sub {
	ok( $CHECKOUT, 'the checkout step is there' ) or return;

	like(
		$CHECKOUT,
		qr{^\s+uses: actions/checkout\@v\d+$}m,
		'it is the checkout action of GitHub'
	);
	like(
		$CHECKOUT,
		qr{^\s+repository: FuguBSD/homebrew-tap$}m,
		'and it names the tap'
	);
	like( $CHECKOUT, qr/^\s+path: tap$/m, 'under tap/' );

	# The checkout configures the key for the push of the same
	# checkout, so the key input reaches it and nothing else.
	like(
		$CHECKOUT,
		qr/^\s+ssh-key: \$\{\{\s*inputs\.key\s*\}\}$/m,
		'and its ssh-key input reads the key input'
	);
};

subtest 'each value reaches the script through the environment' => sub {
	ok( $BUMP, 'the bump step is there' ) or return;

	for my $input ( sort keys %BIND ) {
		my $name = $BIND{$input};
		like(
			$BUMP,
			qr/^\s+$name:\s*\$\{\{\s*inputs\.$input\s*\}\}$/m,
			"$input reaches the step as $name"
		);
	}

	# A value that reached the script text would become part of a
	# command.
	my $script = _script($BUMP);
	ok( $script, 'the step holds a script' ) or return;
	unlike( $script, qr/\$\{\{/,
		'no expression expands inside the script' );
};

subtest 'the script bumps the formula of the caller' => sub {
	my $script = _script($BUMP);
	ok( $script, 'the step holds a script' ) or return;

	# WFL-BREW-2: the repository name after the slash, in lower
	# case. A with: expression cannot lower-case.
	like(
		$script,
		qr{
			name=\$\( printf \s '%s\\n' \s "\$\{BUMP_REPOSITORY\#\*/\}"
			\s \| \s tr \s 'A-Z' \s 'a-z' \)
		}x,
		'the name is the repository name after the slash, in lower case'
	);
	like(
		$script,
		qr{formula="tap/Formula/\$name\.rb"},
		'and the formula path is Formula/<name>.rb in the tap'
	);

	# WFL-BREW-3: the digest of the tarball that the workflow built.
	like(
		$script,
		qr/digest=\$\(sha256sum "\$BUMP_FILE" \| cut -d' ' -f1\)/,
		'the digest is the SHA-256 of the built tarball'
	);
	like(
		$script,
		qr{
			perl \s "\$GITHUB_ACTION_PATH/bump"
			\s "\$formula" \s "\$BUMP_URL" \s "\$digest"
		}x,
		'and bump takes the formula, the URL and the digest'
	);

	# WFL-BREW-5: one commit to main of the tap.
	like(
		$script,
		qr/commit -am "feat\(\$name\): \$BUMP_TAG"/,
		'the commit subject is feat(<name>): <tag>'
	);
	like(
		$script,
		qr/^\s*git -C tap push origin HEAD:main$/m,
		'and the push goes to main of the tap'
	);
};

done_testing();
