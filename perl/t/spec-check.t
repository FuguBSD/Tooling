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

# slurp($path):
#	The whole file as decoded text.
sub slurp ($path)
{
	open my $fh, '<:encoding(UTF-8)', $path or die "read $path: $!";
	local $/ = undef;
	my $text = <$fh>;
	close $fh;

	return $text;
}

# git_fixture():
#	A fixture tree under git, with one commit on the main branch.
#	Return the root, the git command prefix, and the base commit.
sub git_fixture ()
{
	my $root = fixture();
	my $git =
	      "git -C \Q$root\E -c commit.gpgsign=false -c core.hooksPath="
	    . "/dev/null -c user.email=t\@example.com -c user.name=Test";
	for my $step ( 'init -q -b main', 'add -A', 'commit -qm base' ) {
		qx($git $step 2>&1);
		die "git $step failed\n" if $?;
	}
	my $base = qx($git rev-parse HEAD);
	die "git rev-parse failed\n" if $?;
	chomp $base;

	return ( $root, $git, $base );
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
	like(
		$output,
		qr/cite it under Extends/,
		'and the message points at Extends'
	);
}

# A plan that extends a done unit passes, on its own line and beside
# an Implements citation in either order. An open unit, an unknown
# unit, and a rule ID under Extends each fail.
{
	my $root = fixture();
	my $plan = "$root/plans/004-w/plan.md";
	write_file( $plan, "# 004 \x{2014} W\n\nExtends: FIX-ONE.\n" );
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a plan that extends a done unit passes' )
	    or diag($output);

	write_file( $plan,
		"# 004 \x{2014} W\n\nImplements: FIX-TWO. Extends: FIX-ONE.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'two verbs on one line each scan their own citation' )
	    or diag($output);

	write_file( $plan,
"# 004 \x{2014} W\n\n- Implements: FIX-TWO\n- Extends: FIX-ONE\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'two verbs on separate lines pass' ) or diag($output);

	write_file( $plan,
		"# 004 \x{2014} W\n\nExtends: FIX-ONE. Implements: FIX-TWO.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'the two verbs pass in the other order too' )
	    or diag($output);

	write_file( $plan,
		"# 004 \x{2014} W\n\nImplements: FIX-TWO. Defers: FIX-ONE.\n" );
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a Defers segment on an Implements line is exempt' )
	    or diag($output);

	write_file( $plan,
"# 004 \x{2014} W\n\nImplements: FIX-TWO. Implements: FIX-ONE.\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a second Implements segment on one line still scans' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan,
		"# 004 \x{2014} W\n\n- Implements: FIX-TWO and\n  FIX-ONE\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a wrapped Implements list scans its continuation' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan,
		"# 004 \x{2014} W\n\n- Extends: FIX-ONE and\n  FIX-TWO\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a wrapped Extends list scans its continuation' );
	like( $output, qr/Extends cites a unit that is not done/,
		'and is named' );

	write_file( $plan, "# 004 \x{2014} W\n\nExtends: FIX-TWO.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a plan that extends an open unit fails' );
	like( $output, qr/Extends cites a unit that is not done/,
		'and is named' );

	write_file( $plan, "# 004 \x{2014} W\n\nExtends: FIX-NINE.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a plan that extends an unknown unit fails' );
	like( $output, qr/Extends cites an unknown unit/, 'and is named' );

	write_file( $plan, "# 004 \x{2014} W\n\nExtends: FIX-ONE-1.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a rule ID under Extends fails' );
	like( $output, qr/Extends must cite a unit, not a rule/,
		'and is named' );
}

# A partial unit under Extends fails.
{
	my $root = fixture(
		'spec/STATUS.md' => <<"EOF",
# Register

## Units

| Unit | State | Done by | Note |
| --- | --- | --- | --- |
| [FIX-ONE](fixture.md#fix-one) | done | \x{2014} | [code](../lib/code.pm) |
| [FIX-TWO](fixture.md#fix-two) | partial | \x{2014} | Absent: the prose. |

## Code roots

| Document | Roots |
| --- | --- |
| fixture.md | `lib` |

## Retired IDs

| ID |
| --- |
EOF
	);
	write_file( "$root/plans/005-v/plan.md",
		"# 005 \x{2014} V\n\nExtends: FIX-TWO.\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a plan that extends a partial unit fails' );
	like( $output, qr/Extends cites a unit that is not done/,
		'and is named' );
}

# The scan joins a wrapped paragraph, and it ends a citation at the
# first sentence end. A nested sub-item and a prose continuation stay
# out of the citation, and a without clause under Extends fails.
{
	my $root = fixture();
	my $plan = "$root/plans/006-u/plan.md";
	write_file( $plan,
		"# 006 \x{2014} U\n\nImplements: FIX-TWO and\nFIX-ONE.\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a wrapped paragraph citation scans its second line' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan,
"# 006 \x{2014} U\n\n- Implements: FIX-TWO\n  - FIX-ONE stays as it is\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a nested sub-item stays out of the citation' )
	    or diag($output);

	write_file( $plan,
"# 006 \x{2014} U\n\n- Implements: FIX-TWO.\n  The old FIX-ONE rules guide this.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'prose after the sentence end stays out of the citation' )
	    or diag($output);

	write_file( $plan,
		"# 006 \x{2014} U\n\nExtends: FIX-ONE without FIX-ONE-1.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0,
		'a rule ID inside a without clause fails as a rule ID' );
	like( $output, qr/Extends must cite a unit, not a rule/,
		'and is named' );
}

# A citation starts a paragraph or a list item, and a prose sentence
# that names a verb is not one. A blank line and a heading each end a
# citation. Then a without clause with a unit, an empty citation, a
# second verb with no sentence end, and a period before a unit ID.
{
	my $root = fixture();
	my $plan = "$root/plans/007-t/plan.md";
	write_file( $plan,
"# 007 \x{2014} T\n\nThe plan cites no unit under Implements:, because FIX-ONE stays done.\n"
	);
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a prose sentence that names a verb is not a citation' )
	    or diag($output);

	write_file( $plan,
"# 007 \x{2014} T\n\nThis plan cites nothing under Extends:, because\nFIX-TWO stays open.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a wrapped prose sentence is not a citation either' )
	    or diag($output);

	write_file( $plan,
"# 007 \x{2014} T\n\nImplements: FIX-TWO\n\nFIX-ONE guides this.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a blank line ends a citation' ) or diag($output);

	write_file( $plan,
		"# 007 \x{2014} T\n\nImplements: FIX-TWO\n## FIX-ONE\n" );
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a heading ends a citation' ) or diag($output);

	write_file( $plan,
		"# 007 \x{2014} T\n\nExtends: FIX-ONE without FIX-ONE.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a without clause with a unit under Extends fails' );
	like( $output, qr/Extends takes no without clause/, 'and is named' );

	write_file( $plan, "# 007 \x{2014} T\n\nExtends:\n\n- FIX-TWO\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an empty Extends citation fails' );
	like( $output, qr/Extends holds no citation text/, 'and is named' );

	write_file( $plan,
		"# 007 \x{2014} T\n\nImplements: FIX-TWO and Extends: FIX-ONE\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a second verb with no sentence end fails as a fold' );
	like( $output, qr/runs into another verb/, 'and the fold is named' );
	unlike( $output, qr/holds no citation text/, 'and no bare verb error' );

	write_file( $plan,
"# 007 \x{2014} T\n\nImplements: FIX-TWO. FIX-ONE guides this.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a period before a unit ID ends the citation' )
	    or diag($output);
}

# A bold verb is a verb, and a bare verb is an error. A citation with no
# unit passes. A wrapped prose sentence that puts a verb at a line start
# is prose, and a list item after prose is a citation.
{
	my $root = fixture();
	my $plan = "$root/plans/008-s/plan.md";
	write_file( $plan, "# 008 \x{2014} S\n\n**Implements:** FIX-ONE\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a bold verb is a verb' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan, "# 008 \x{2014} S\n\nImplements:\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a bare verb fails' );
	like( $output, qr/Implements holds no citation text/, 'and is named' );

	write_file( $plan, "# 008 \x{2014} S\n\nImplements: none.\n" );
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a citation with no unit passes' ) or diag($output);

	write_file( $plan,
"# 008 \x{2014} S\n\nFIX-ONE is done, so this plan cites it nowhere under\nImplements:, per the plans rule.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a verb at the start of a wrapped prose line is prose' )
	    or diag($output);

	write_file( $plan,
"# 008 \x{2014} S\n\nSome prose names Implements: here.\n- Implements: FIX-ONE\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a list item after prose is a citation' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan,
"# 008 \x{2014} S\n\nImplements: FIX-TWO. The plan cites nothing under Implements:, because FIX-ONE stays done.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a mid-sentence verb after a citation is prose' )
	    or diag($output);
}

# A prose mention of another verb after a citation raises no error. A
# bare Defers fails. The underscore and the italic marks around a verb
# come off, and a second citation in a wrapped paragraph starts a
# sentence.
{
	my $root = fixture();
	my $plan = "$root/plans/009-r/plan.md";
	write_file( $plan,
"# 009 \x{2014} R\n\nImplements: FIX-TWO. The plan cites nothing under Extends:, because FIX-ONE stays done.\n"
	);
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a prose mention of another verb raises no error' )
	    or diag($output);

	write_file( $plan, "# 009 \x{2014} R\n\nDefers:\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a bare Defers fails' );
	like( $output, qr/Defers holds no citation text/, 'and is named' );

	write_file( $plan, "# 009 \x{2014} R\n\n__Implements:__ FIX-ONE\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an underscore bold verb is a verb' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan, "# 009 \x{2014} R\n\n*Implements:* FIX-ONE\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an italic verb is a verb' );
	like( $output, qr/cites a done unit/, 'and is named' );

	write_file( $plan,
		"# 009 \x{2014} R\n\nImplements: FIX-TWO.\nExtends: FIX-ONE.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0,
		'a second citation in a wrapped paragraph starts a sentence' )
	    or diag($output);
}

# The marks around a verb come off in every form, a numbered list item
# is a citation, an n-a unit is not done, a without clause passes on an
# open unit with a rule, a sibling token is exempt, and the first
# period ends a citation with no space after it.
{
	my $root = fixture(
		'spec/fixture.md' => <<'EOF',
# The fixture

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.

<a id="fix-two"></a>

## Unit two

- **FIX-TWO-1** — The fixture can grow.
EOF
	);
	my $plan = "$root/plans/010-q/plan.md";
	for my $form (
		'**Implements**: FIX-ONE',
		'`Implements:` FIX-ONE',
		'1. Implements: FIX-ONE'
	    )
	{
		write_file( $plan, "# 010 \x{2014} Q\n\n$form\n" );
		my ( $exit, $output ) = run_check($root);
		isnt( $exit, 0, "the form '$form' is a citation" );
		like( $output, qr/cites a done unit/, 'and is named' );
	}

	write_file( $plan,
		"# 010 \x{2014} Q\n\nImplements: FIX-TWO without FIX-TWO-1.\n"
	);
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a without clause on an open unit passes' )
	    or diag($output);

	write_file( $plan, "# 010 \x{2014} Q\n\nExtends: FuguVM FIX-NINE.\n" );
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a sibling token under Extends is exempt' )
	    or diag($output);

	write_file( $plan,
		"# 010 \x{2014} Q\n\nImplements: FIX-TWO.FIX-ONE\n" );
	( $exit, $output ) = run_check($root);
	is( $exit, 0,
		'the first period ends a citation with no space after it' )
	    or diag($output);

	write_file( $plan,
		"# 010 \x{2014} Q\n\nExtends: FIX-ONE Implements: FIX-TWO\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a citation that runs into another verb fails' );
	like( $output, qr/Extends citation runs into another verb/,
		'and is named' );
}

# An n-a unit under Extends is not done.
{
	my $root = fixture(
		'spec/STATUS.md' => <<"EOF",
# Register

## Units

| Unit | State | Done by | Note |
| --- | --- | --- | --- |
| [FIX-ONE](fixture.md#fix-one) | done | \x{2014} | [code](../lib/code.pm) |
| [FIX-TWO](fixture.md#fix-two) | n-a | \x{2014} | Citation only. |

## Code roots

| Document | Roots |
| --- | --- |
| fixture.md | `lib` |

## Retired IDs

| ID |
| --- |
EOF
	);
	write_file( "$root/plans/011-p/plan.md",
		"# 011 \x{2014} P\n\nExtends: FIX-TWO.\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an n-a unit under Extends fails' );
	like( $output, qr/Extends cites a unit that is not done/,
		'and is named' );
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

# A sibling-repository citation is exempt, for a unit and for a
# decision. A capitalized word that is not a repository name is not.
{
	my $root = fixture();
	write_file( "$root/plans/003-z/plan.md",
		"# 003 \x{2014} Z\n\nFuguVM FIX-NINE guides this plan.\n" );
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a sibling unit citation is exempt' )
	    or diag($output);

	my $doc = <<'EOF';
# The fixture

FuguOracle D-77 guides unit one.

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.

<a id="fix-two"></a>

## Unit two

Prose only.
EOF
	( $exit, $output ) =
	    run_check( fixture( 'spec/fixture.md' => $doc ) );
	is( $exit, 0, 'a sibling decision citation is exempt' )
	    or diag($output);

	$doc =~ s/FuguOracle D-77 guides unit one\./See D-77 for unit one./;
	( $exit, $output ) =
	    run_check( fixture( 'spec/fixture.md' => $doc ) );
	isnt( $exit, 0, 'a local unresolved decision fails' );
	like( $output, qr/unresolved decision: D-77/, 'and is named' );
}

# A unit sits under one verb only. One unit under Defers and under
# Implements, or under Defers and Extends, fails in one block and
# across two blocks. A without clause leaves the unit token in place.
# Two different units, and a deferred rule of an implemented unit,
# each pass.
{
	my $root = fixture(
		'spec/fixture.md' => <<'EOF',
# The fixture

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.

<a id="fix-two"></a>

## Unit two

- **FIX-TWO-1** — The fixture can grow.
EOF
	);
	my $plan = "$root/plans/012-o/plan.md";
	write_file( $plan,
		"# 012 \x{2014} O\n\nImplements: FIX-TWO. Defers: FIX-TWO.\n" );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'one unit under Implements and Defers fails' );
	like(
		$output,
		qr/under Implements and Defers: FIX-TWO/,
		'and the verbs and the unit are named'
	);

	write_file( $plan,
		"# 012 \x{2014} O\n\n- Implements: FIX-TWO\n- Defers: FIX-TWO\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'the two verbs contradict across two blocks too' );
	like(
		$output,
		qr/under Implements and Defers: FIX-TWO/,
		'and the verbs and the unit are named'
	);

	write_file( $plan,
		"# 012 \x{2014} O\n\nExtends: FIX-ONE. Defers: FIX-ONE.\n" );
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'one unit under Extends and Defers fails' );
	like(
		$output,
		qr/under Extends and Defers: FIX-ONE/,
		'and the verbs and the unit are named'
	);

	write_file( $plan,
"# 012 \x{2014} O\n\nImplements: FIX-TWO without FIX-TWO-1. Defers: FIX-TWO.\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a without clause leaves the unit token in place' );
	like(
		$output,
		qr/under Implements and Defers: FIX-TWO/,
		'and the verbs and the unit are named'
	);

	write_file( $plan,
		"# 012 \x{2014} O\n\nImplements: FIX-TWO. Defers: FIX-ONE.\n" );
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'two different units under the two verbs pass' )
	    or diag($output);

	write_file( $plan,
"# 012 \x{2014} O\n\nImplements: FIX-TWO without FIX-TWO-1. Defers: FIX-TWO-1.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a deferred rule of an implemented unit passes' )
	    or diag($output);
}

# One unit under Implements and under Extends fails, because the unit
# is done or it is not. A Defers citation marks every unit token of
# its text.
{
	my $root = fixture(
		'spec/fixture.md' => <<'EOF',
# The fixture

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.

<a id="fix-two"></a>

## Unit two

- **FIX-TWO-1** — The fixture can grow.
EOF
	);
	my $plan = "$root/plans/013-n/plan.md";
	write_file( $plan,
		"# 013 \x{2014} N\n\nImplements: FIX-ONE. Extends: FIX-ONE.\n"
	);
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a done unit under Implements and Extends fails' );
	like( $output, qr/Implements cites a done unit/, 'and is named' );

	write_file( $plan,
		"# 013 \x{2014} N\n\nImplements: FIX-TWO. Extends: FIX-TWO.\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an open unit under Implements and Extends fails' );
	like( $output, qr/Extends cites a unit that is not done/,
		'and is named' );

	write_file( $plan,
"# 013 \x{2014} N\n\nImplements: FIX-TWO. Defers: FIX-ONE and FIX-TWO.\n"
	);
	( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a Defers citation marks each of its unit tokens' );
	like(
		$output,
		qr/under Implements and Defers: FIX-TWO/,
		'and the second token is named'
	);

	write_file( $plan,
"# 013 \x{2014} N\n\nImplements: FIX-TWO. Defers: FIX-ONE. FIX-TWO lands here.\n"
	);
	( $exit, $output ) = run_check($root);
	is( $exit, 0, 'a period ends the citation before the prose token' )
	    or diag($output);
}

# SPC-LINKS-2 and the SPC-DOCS rules each reject their own defect.
{
	my ( $exit, $output ) = run_check(
		fixture(
			      'spec/fixture.md' => "# The fixture\n\n"
			    . "[gone](index.md#no-such-heading)\n"
		) );
	isnt( $exit, 0, 'a broken anchor fails' );
	like( $output, qr/broken anchor/, 'and is named' );

	( $exit, $output ) =
	    run_check( fixture( 'spec/other.md' => "# Other\n\nProse.\n" ) );
	isnt( $exit, 0, 'a document that the index omits fails' );
	like( $output, qr/does not list spec\/other\.md/, 'and is named' );

	( $exit, $output ) = run_check(
		fixture(
			'spec/index.md' => <<'EOF',
# Fixture specification

## Specification documents

| Code | Document | Area |
| --- | --- | --- |
| FIX | [fixture.md](fixture.md) | The fixture |
| OTH | [other.md](other.md) | The absent one |

## Governance documents

| Document | Role |
| --- | --- |
| [DECISIONS.md](DECISIONS.md) | The decisions. |
| [ROADMAP.md](ROADMAP.md) | The schedule. |
| [STATUS.md](STATUS.md) | The register. |
EOF
		) );
	isnt( $exit, 0, 'an index row for an absent document fails' );
	like( $output, qr/lists a missing document: other\.md/,
		'and is named' );

	for my $absent (qw(ROADMAP.md DECISIONS.md STATUS.md)) {
		( $exit, $output ) =
		    run_check( fixture( "spec/$absent" => undef ) );
		isnt( $exit, 0, "an absent spec/$absent fails" );
		like( $output, qr/\Q$absent\E does not exist/, 'and is named' );
	}

	( $exit, $output ) = run_check(
		fixture(
			      'spec/fixture.md' => "# The fixture\n\n"
			    . "<a id=\"fix-one\"></a>\n\n## Unit one\n\n"
			    . "- **FIX-ONE-1** \x{2014} The fixture must exist.\n\n"
			    . "<a id=\"fix-two\"></a>\n\n## Unit two\n\n"
			    . "The work starts in Phase 2.\n"
		) );
	isnt( $exit, 0, 'a schedule phase in a unit document fails' );
	like( $output, qr/must not state a schedule phase/, 'and is named' );
}

# A fenced code block is exempt from the scan rules.
{
	my ( $exit, $output ) = run_check(
		fixture(
			      'spec/fixture.md' => "# The fixture\n\n"
			    . "```\n[gone](missing.md)\nFIX-NINE\n```\n\n"
			    . "<a id=\"fix-one\"></a>\n\n## Unit one\n\n"
			    . "- **FIX-ONE-1** \x{2014} The fixture must exist.\n\n"
			    . "<a id=\"fix-two\"></a>\n\n## Unit two\n\nProse.\n"
		) );
	is( $exit, 0, 'a fence hides a broken link and a stray token' )
	    or diag($output);

	( $exit, $output ) = run_check(
		fixture(
			      'plans/014-m/plan.md' => "# 014 \x{2014} M\n\n"
			    . "```\nImplements: FIX-ONE.\n```\n"
		) );
	is( $exit, 0, 'a fenced citation is not a citation' ) or diag($output);
}

# A unit anchor and a rule definition each sit in one document, once.
{
	my $twice = <<'EOF';
# The fixture

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.
- **FIX-ONE-1** — The fixture must exist twice.

<a id="fix-two"></a>

## Unit two

Prose only.
EOF
	my ( $exit, $output ) =
	    run_check( fixture( 'spec/fixture.md' => $twice ) );
	isnt( $exit, 0, 'a duplicate rule fails' );
	like( $output, qr/duplicate rule: FIX-ONE-1/, 'and is named' );

	my $stray = <<'EOF';
# Fixture specification

## Specification documents

| Code | Document | Area |
| --- | --- | --- |
| FIX | [fixture.md](fixture.md) | The fixture |
| OTH | [other.md](other.md) | The other |

## Governance documents

| Document | Role |
| --- | --- |
| [DECISIONS.md](DECISIONS.md) | The decisions. |
| [ROADMAP.md](ROADMAP.md) | The schedule. |
| [STATUS.md](STATUS.md) | The register. |
EOF
	( $exit, $output ) = run_check(
		fixture(
			'spec/index.md' => $stray,
			'spec/other.md' => "# Other\n\n"
			    . "- **FIX-TWO-1** \x{2014} This rule left its document.\n"
		) );
	isnt( $exit, 0, 'a rule outside the document of its unit fails' );
	like( $output, qr/rule outside the document of its unit: FIX-TWO-1/,
		'and is named' );

	( $exit, $output ) = run_check(
		fixture(
			'spec/index.md' => $stray,
			'spec/other.md' => "# Other\n\n"
			    . "<a id=\"fix-two\"></a>\n\n"
			    . "## Unit two, in the wrong document\n\nProse.\n"
		) );
	isnt( $exit, 0, 'a unit anchor in the wrong document fails' );
	like( $output, qr/unit anchor in the wrong document: fix-two/,
		'and is named' );

	my $dup = <<'EOF';
# The fixture

<a id="fix-one"></a>

## Unit one

- **FIX-ONE-1** — The fixture must exist.

<a id="fix-one"></a>

## Unit one again

Prose only.

<a id="fix-two"></a>

## Unit two

Prose only.
EOF
	( $exit, $output ) = run_check( fixture( 'spec/fixture.md' => $dup ) );
	isnt( $exit, 0, 'a duplicate unit anchor fails' );
	like( $output, qr/duplicate unit anchor: fix-one/, 'and is named' );
}

# A register row carries a state, a note, an evidence link, and no
# retired ID. The register needs a Units table.
{
	my $head = "# Register\n\n## Units\n\n"
	    . "| Unit | State | Done by | Note |\n| --- | --- | --- | --- |\n";
	my $tail = "\n## Code roots\n\n| Document | Roots |\n| --- | --- |\n"
	    . "| fixture.md | `lib` |\n\n## Retired IDs\n\n| ID |\n| --- |\n";
	my $two = "| [FIX-TWO](fixture.md#fix-two) | open | \x{2014} | "
	    . "\x{2014} |\n";

	my ( $exit, $output ) = run_check(
		fixture(
			      'spec/STATUS.md' => $head
			    . "| [FIX-ONE](fixture.md#fix-one) | done | "
			    . "\x{2014} | \x{2014} |\n"
			    . $two
			    . $tail
		) );
	isnt( $exit, 0, 'a done row without an evidence link fails' );
	like( $output, qr/a done row needs an evidence link/, 'and is named' );

	( $exit, $output ) = run_check(
		fixture(
			      'spec/STATUS.md' => $head
			    . "| [FIX-ONE](fixture.md#fix-one) | done | "
			    . "\x{2014} | [code](../lib/code.pm) |\n"
			    . "| [FIX-TWO](fixture.md#fix-two) | partial | "
			    . "\x{2014} | \x{2014} |\n"
			    . $tail
		) );
	isnt( $exit, 0, 'a partial row without a note fails' );
	like( $output, qr/a partial row needs a note/, 'and is named' );

	( $exit, $output ) = run_check(
		fixture(
			      'spec/STATUS.md' => $head
			    . "| [FIX-ONE](fixture.md#fix-one) | done | "
			    . "\x{2014} | [gone](../lib/absent.pm) |\n"
			    . $two
			    . $tail
		) );
	isnt( $exit, 0, 'a broken evidence link fails' );
	like( $output, qr/broken evidence link/, 'and is named' );

	( my $retired =
		      $head
		    . "| [FIX-ONE](fixture.md#fix-one) | done | \x{2014} | "
		    . "[code](../lib/code.pm) |\n"
		    . $two
		    . $tail ) =~
	    s/\| ID \|\n\| --- \|\n/| ID |\n| --- |\n| FIX-ONE |\n/;
	( $exit, $output ) =
	    run_check( fixture( 'spec/STATUS.md' => $retired ) );
	isnt( $exit, 0, 'a retired ID with an anchor fails' );
	like( $output, qr/a retired ID still has an anchor/, 'and is named' );

	( $exit, $output ) = run_check(
		fixture( 'spec/STATUS.md' => "# Register\n\nNo table.\n" ) );
	isnt( $exit, 0, 'a register without a Units table fails' );
	like( $output, qr/holds no Units table/, 'and is named' );
}

# The root must hold a spec directory.
{
	my $root = tempdir( CLEANUP => 1 );
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'a root without a spec directory fails' );
	like( $output, qr/no spec directory/, 'and is named' );
}

# The drift gate reads the change of the branch. A lone document
# change fails, and a register change in the same branch satisfies the
# gate.
{
	my ( $root, $git, $base ) = git_fixture();
	qx($git checkout -q -b work 2>&1);
	die "git checkout failed\n" if $?;
	write_file( "$root/spec/fixture.md",
		slurp("$root/spec/fixture.md") . "\nOne more line.\n" );
	qx($git commit -qam doc 2>&1);
	die "git commit failed\n" if $?;
	my ( $exit, $output ) = run_check( $root, "--drift $base" );
	isnt( $exit, 0, 'a lone document change fails the drift gate' );
	like( $output, qr/must also update/, 'and is named' );

	write_file( "$root/spec/STATUS.md",
		slurp("$root/spec/STATUS.md") . "\nA note.\n" );
	qx($git commit -qam register 2>&1);
	die "git commit failed\n" if $?;
	( $exit, $output ) = run_check( $root, "--drift $base" );
	is( $exit, 0, 'a register change satisfies the drift gate' )
	    or diag($output);
}

# A code root change alone satisfies the drift gate.
{
	my ( $root, $git, $base ) = git_fixture();
	qx($git checkout -q -b work 2>&1);
	write_file( "$root/spec/fixture.md",
		slurp("$root/spec/fixture.md") . "\nOne more line.\n" );
	write_file( "$root/lib/code.pm", "1;\n# more\n" );
	qx($git add -A 2>&1);
	qx($git commit -qm both 2>&1);
	die "git commit failed\n" if $?;
	my ( $exit, $output ) = run_check( $root, "--drift $base" );
	is( $exit, 0, 'a code root change satisfies the drift gate' )
	    or diag($output);
}

# The gate reads the merge base, not the base tip. The work branch
# changes the document only, so the gate must fail. The base branch
# alone changes the code root, so a two-dot diff would read that
# change and pass the gate.
{
	my ( $root, $git ) = git_fixture();
	qx($git checkout -q -b work 2>&1);
	die "git checkout failed\n" if $?;
	write_file( "$root/spec/fixture.md",
		slurp("$root/spec/fixture.md") . "\nOne more line.\n" );
	qx($git commit -qam doc 2>&1);
	die "git commit failed\n" if $?;

	qx($git checkout -q main 2>&1);
	write_file( "$root/lib/code.pm", "1;\n# more\n" );
	qx($git commit -qam code 2>&1);
	die "git commit failed\n" if $?;
	my $tip = qx($git rev-parse HEAD);
	chomp $tip;

	qx($git checkout -q work 2>&1);
	die "git checkout failed\n" if $?;
	my ( $exit, $output ) = run_check( $root, "--drift $tip" );
	isnt( $exit, 0, 'the gate reads the merge base, not the base tip' );
	like( $output, qr/must also update/, 'and is named' );
}

# The contradiction state holds no leak between two plans. The check
# reads the plans in name order. Plan 016 would see the claim of plan
# 015, and plan 017 would see the deferral of plan 016.
{
	my $root = fixture();
	write_file( "$root/plans/015-l/plan.md",
		"# 015 \x{2014} L\n\nImplements: FIX-TWO.\n" );
	write_file( "$root/plans/016-k/plan.md",
		"# 016 \x{2014} K\n\nDefers: FIX-TWO.\n" );
	write_file( "$root/plans/017-j/plan.md",
		"# 017 \x{2014} J\n\nImplements: FIX-TWO.\n" );
	my ( $exit, $output ) = run_check($root);
	is( $exit, 0, 'one verb in each of three plans passes' )
	    or diag($output);
}

# The contradiction rule compares a known unit only.
{
	my $root = fixture();
	write_file( "$root/plans/018-i/plan.md",
		"# 018 \x{2014} I\n\nImplements: FIX-NINE. Defers: FIX-NINE.\n"
	);
	my ( $exit, $output ) = run_check($root);
	isnt( $exit, 0, 'an unknown unit under two verbs fails' );
	like(
		$output,
		qr/Implements cites an unknown unit: FIX-NINE/,
		'and the unknown unit is named'
	);
	unlike(
		$output,
		qr/under Implements and Defers/,
		'and the contradiction error stays away'
	);
}

# The header of the script names every unit of the specification
# document, and no other. The script and spec/spec-check.md must agree.
{
	my $doc    = "$RealBin/../../spec/spec-check.md";
	my $header = ( split /\nuse v5/, slurp($script), 2 )[0];
	my %anchor =
	    map { uc $_ => 1 } slurp($doc) =~ /<a id="(spc-[a-z0-9-]+)"><\/a>/g;
	my %named = map { $_ => 1 } $header =~ /\b(SPC-[A-Z]+)\b/g;
	ok( scalar keys %named, 'the header names a unit of the document' );
	is_deeply( [ sort grep { !$anchor{$_} } keys %named ],
		[], 'and every named unit exists' );
	is_deeply( [ sort grep { !$named{$_} } keys %anchor ],
		[], 'and the header names every unit' );
}

done_testing();
