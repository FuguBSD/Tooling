#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for org/sync/scripts/spec-check against a fixture tree
#
# The tests build a minimal valid specification in a temporary
# directory, then break it one rule at a time. They drive the real
# script as a subprocess, exactly as a consumer runs it.

use v5.36;
use utf8;
use Test::More;
use FindBin    qw($RealBin);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $script = "$RealBin/../../org/sync/scripts/spec-check";
ok( -x $script, 'spec-check script is executable' );

# write_file($path, $content):
#	Write $content to $path, with its parent directories.
sub write_file ( $path, $content )
{
	my ($dir) = $path =~ m{^(.*)/[^/]+$};
	make_path($dir) if $dir;
	open my $fh, '>:encoding(UTF-8)', $path or die "write $path: $!";
	print $fh $content;
	close $fh;

	return;
}

# run_check($root, @args):
#	Run spec-check against $root. Return the exit status and the
#	output.
sub run_check ( $root, @args )
{
	my $output = `$script --root \Q$root\E @args 2>&1`;

	return ( $? >> 8, $output );
}

# fixture(%override):
#	A minimal valid specification tree. An override replaces one
#	file by its relative path; an undef value omits the file.
sub fixture (%override)
{
	my $root  = tempdir( CLEANUP => 1 );
	my %files = (
		'spec/index.md' => <<'EOF',
# Fixture specification

## Specification documents

| Code | Document | Area |
| --- | --- | --- |
| FIX | [fixture.md](fixture.md) | The fixture |

## Governance documents

| Document | Role |
| --- | --- |
| [DECISIONS.md](DECISIONS.md) | The decisions. |
| [ROADMAP.md](ROADMAP.md) | The schedule. |
| [STATUS.md](STATUS.md) | The register. |
EOF
		'spec/fixture.md' => <<'EOF',
# The fixture

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.

<a id="fix-two"></a>

## Unit two

Prose only.
EOF
		'spec/DECISIONS.md' => <<'EOF',
# Decisions

| ID | Decision | Rationale |
| --- | --- | --- |
| D-01 | One fixture. | Small. |
EOF
		'spec/ROADMAP.md' => <<'EOF',
# Roadmap

No phases.
EOF
		'spec/STATUS.md' => <<"EOF",
# Register

## Units

| Unit | State | Done by | Note |
| --- | --- | --- | --- |
| [FIX-ONE](fixture.md#fix-one) | done | \x{2014} | [code](../lib/code.pm) |
| [FIX-TWO](fixture.md#fix-two) | open | \x{2014} | \x{2014} |

## Code roots

| Document | Roots |
| --- | --- |
| fixture.md | `lib` |

## Retired IDs

| ID |
| --- |
EOF
		'lib/code.pm' => "1;\n",
	);
	for my $path ( keys %override ) {
		if ( defined $override{$path} ) {
			$files{$path} = $override{$path};
		}
		else {
			delete $files{$path};
		}
	}
	write_file( "$root/$_", $files{$_} ) for keys %files;

	return $root;
}

# A valid fixture passes.
{
	my ( $exit, $output ) = run_check( fixture() );
	is( $exit, 0, 'a valid fixture passes' ) or diag($output);
	like( $output, qr/1 rules/, 'and the rule is counted' );
}

# A broken link fails.
{
	my $root = fixture();
	write_file( "$root/spec/fixture.md",
		      "# The fixture\n\n[gone](missing.md)\n\n"
		    . "<a id=\"fix-one\"></a>\n\n## Unit one\n\n"
		    . "<a id=\"fix-two\"></a>\n\n## Unit two\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a broken link fails' );
	like( $output, qr/broken link/, 'and is named' );
}

# A register row without a unit fails, and a unit without a row fails.
{
	my ( $exit, $output ) = run_check(
		fixture(
			      'spec/fixture.md' => "# The fixture\n\n"
			    . "<a id=\"fix-one\"></a>\n\n## Unit one\n"
		) );
	isnt( $exit, 0, 'a register row without a unit fails' );
	like( $output, qr/without a unit anchor: FIX-TWO/, 'and is named' );
}

# An unknown state and a bad Done by value fail.
{
	my $status = <<"EOF";
# Register

## Units

| Unit | State | Done by | Note |
| --- | --- | --- | --- |
| [FIX-ONE](fixture.md#fix-one) | someday | P9 | \x{2014} |
| [FIX-TWO](fixture.md#fix-two) | open | \x{2014} | \x{2014} |

## Retired IDs

| ID |
| --- |
EOF
	my ( $exit, $output ) =
	    run_check( fixture( 'spec/STATUS.md' => $status ) );
	isnt( $exit, 0, 'an unknown state fails' );
	like( $output, qr/unknown state: someday/, 'and is named' );
}

# A plan that cites a done unit fails; an open unit passes.
{
	my $root = fixture();
	write_file( "$root/plans/001-x/plan.md",
		"# 001 \x{2014} X\n\nImplements: FIX-TWO.\n" );
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a plan that cites an open unit passes' )
	    or diag($output);

	write_file( "$root/plans/001-x/plan.md",
		"# 001 \x{2014} X\n\nImplements: FIX-ONE.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a plan that cites a done unit fails' );
	like( $output, qr/cites a done unit/, 'and is named' );
}

# An unresolved citation fails.
{
	my $root = fixture();
	write_file( "$root/plans/002-y/plan.md",
		"# 002 \x{2014} Y\n\nThis touches FIX-NINE.\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an unresolved citation fails' );
	like( $output, qr/unresolved citation: FIX-NINE/, 'and is named' );
}

done_testing();
