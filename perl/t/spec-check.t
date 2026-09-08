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

done_testing();
