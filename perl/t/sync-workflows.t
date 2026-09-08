#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for the synced test org/sync/t/ci/workflows.t
#
# That test guards the workflows of a consumer, and no consumer of
# this repository can guard it back. This test drives it against
# fixture trees: it copies the test into a temporary checkout, writes
# a workflow beside it, and reads the verdict.
#
# WFL-ACTIONS-3 is the rule under test. A guard that refuses
# "make deps-test" turns a correct step red in every consumer at once.

use v5.36;
use Test::More;
use FindBin    qw($RealBin);
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);
use File::Spec;

my $guard = "$RealBin/../../org/sync/t/ci/workflows.t";

plan skip_all => 'no synced workflows test' unless -f $guard;

# _write($path, $text):
#	Write $text to $path, making each parent directory.
sub _write ( $path, $text )
{
	my ( undef, $dir, undef ) = File::Spec->splitpath($path);
	make_path($dir);
	open my $fh, '>', $path or die "cannot write $path: $!\n";
	print {$fh} $text;
	close $fh;

	return;
}

# _verdict($workflow):
#	Run the guard over one fixture workflow. Returns the pair
#	(exit status, output).
sub _verdict ($workflow)
{
	my $tmp = tempdir( CLEANUP => 1 );

	# The guard reads $RealBin/../../.github/workflows, so it
	# sits two directories under the root of the fixture.
	_write( "$tmp/t/ci/workflows.t",            _slurp($guard) );
	_write( "$tmp/.github/workflows/check.yml", $workflow );

	my $output = qx{$^X "$tmp/t/ci/workflows.t" 2>&1};

	return ( $?, $output );
}

# _slurp($path):
#	Whole file as text.
sub _slurp ($path)
{
	open my $fh, '<', $path or die "cannot read $path: $!\n";
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

# The gitleaks job of a migrated consumer. It installs the tool
# environment itself, and it uses no setup-perl action.
my $DEPS = <<'YML';
name: Check

jobs:
  gitleaks:
    name: Gitleaks
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install dependencies
        run: |
          make deps
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Scan for secrets
        run: make gitleaks
YML

subtest 'a job that runs make deps passes' => sub {
	my ( $status, $output ) = _verdict($DEPS);
	is( $status, 0, 'the guard accepts the step' ) or diag($output);
};

subtest 'a job that runs make deps-test passes' => sub {

	# WFL-ACTIONS-3 names one target. deps-test and deps-develop
	# are targets of their own, and a guard that ends the name at
	# a word boundary reads "-test" as an argument.
	for my $target (qw(deps-test deps-develop)) {
		my $yml = $DEPS =~ s/\bmake deps\b/make $target/r;
		my ( $status, $output ) = _verdict($yml);
		is( $status, 0, "the guard accepts make $target" )
		    or diag($output);
	}
};

subtest 'a job that gives make deps an argument fails' => sub {
	my $yml = $DEPS =~ s/^          make deps$/          make deps tool/mr;
	isnt( $yml, $DEPS, 'the fixture holds the argument' );

	my ( $status, $output ) = _verdict($yml);
	isnt( $status, 0, 'the guard refuses the step' );
	like( $output, qr/takes no argument/, 'and it names the rule' );
};

subtest 'a job that installs beside the shared action fails' => sub {
	my $yml = $DEPS =~ s{
	    (- \s uses: \s actions/checkout\@v4\n)
	}{$1 . "      - uses: FuguBSD/Tooling/perl/actions/setup-perl\@main\n"}xer;
	isnt( $yml, $DEPS, 'the fixture holds the action' );

	my ( $status, $output ) = _verdict($yml);
	isnt( $status, 0, 'the guard refuses the job' );
};

done_testing();
