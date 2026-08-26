#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for org/sync/scripts/ste-lint against a fixture tree
#
# The tests drive the real script as a subprocess against a temporary
# directory, exactly as a consumer runs it.

use v5.36;
use Test::More;
use FindBin    qw($RealBin);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $script = "$RealBin/../../org/sync/scripts/ste-lint";
ok( -x $script, 'ste-lint script is executable' );

# write_file($path, $content):
#	Write $content to $path.
sub write_file ( $path, $content )
{
	open my $fh, '>:encoding(UTF-8)', $path or die "write $path: $!";
	print $fh $content;
	close $fh;

	return;
}

# run_lint($root):
#	Run ste-lint against $root. Return the exit status and output.
sub run_lint ($root)
{
	my $output = `$script --root \Q$root\E 2>&1`;

	return ( $? >> 8, $output );
}

# Clean prose passes.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe tool reads one file.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'clean prose passes' ) or diag($output);
}

# A banned word fails, with its file, line, and word.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md", "# Fixture\n\nWe leverage the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a banned word fails' );
	like(
		$output,
		qr/README\.md:3: banned word "leverage"/,
		'and is located and named'
	);
}

# A banned phrase fails, with the phrase, across a tab.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nIn order\tto start, run the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a banned phrase fails' );
	like( $output, qr/banned phrase "in order to"/, 'and is named' );
}

# Each banned word on one line gets one finding, and the lint
# reports the count.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nWe utilize and leverage the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'two banned words fail' );
	like( $output, qr/banned word "utilize"/,    'the first is named' );
	like( $output, qr/banned word "leverage"/,   'the second is named' );
	like( $output, qr/ste-lint: 2 finding\(s\)/, 'and the count is 2' );
}

# The correlative patterns fail.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nIt is not just fast but small.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the correlative patterns fail' );
	like( $output, qr/not just \.\.\. but/, 'not just ... but is found' );
	like( $output, qr/is not just/,         'is not just is found' );
}

# docs/ and a spec/ subdirectory are exempt, and spec/ at the first
# level stays in scope.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md", "# Fixture\n\nOne file.\n" );
	make_path( "$root/docs", "$root/spec/archive" );
	write_file( "$root/docs/notes.md",       "We leverage the tool.\n" );
	write_file( "$root/spec/archive/old.md", "We leverage the tool.\n" );
	write_file( "$root/spec/design.md",      "We leverage the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the spec first level stays in scope' );
	like( $output, qr{spec/design\.md:1},        'and is located' );
	like( $output, qr/ste-lint: 1 finding\(s\)/, 'and only that one' );
}

# The passive voice fails, with the verb group.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe file is parsed by the tool.\n\n"
		    . "The file is quickly parsed by the tool.\n\n"
		    . "The panel is led by the chair.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the passive voice fails' );
	like( $output, qr/passive voice "is parsed by"/, 'and is named' );
	like(
		$output,
		qr/passive voice "is quickly parsed by"/,
		'an adverb does not hide it'
	);
	like(
		$output,
		qr/passive voice "is led by"/,
		'a short participle does not hide it'
	);
}

# A word that ends in -ed after "was" is not a passive.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nIt was indeed by design.\n\n"
		    . "The light is red by design.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'indeed and red pass' ) or diag($output);
}

# Typographic punctuation fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe \x{201C}main\x{201D} tool reads one file.\n"
	);
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'typographic punctuation fails' );
	like( $output, qr/typographic punctuation/, 'and is labeled' );
}

# An emoji fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe check passes \x{2705} on push.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'an emoji fails' );
	like( $output, qr/emoji/, 'and is labeled' );
}

# A bold lead with a colon fails, in each variant.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- **Speed:** the tool is fast.\n\n"
		    . "1. **Size**: the tool is small.\n\n"
		    . "**Note:** the tool is one file.\n\n"
		    . "> **Note:** the tool reads one file.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a bold lead with a colon fails' );
	my $count = () = $output =~ /bold lead/g;
	is( $count, 4, 'and each variant is found' );
}

# A trailing participle fails, with the participle.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe daemon rotates the logs, reflecting the "
		    . "retention rule.\n\n"
		    . "The index is one page, enabling a fast scan.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a trailing participle fails' );
	like( $output, qr/trailing participle "reflecting"/, 'and is named' );
	like(
		$output,
		qr/trailing participle "enabling"/,
		'and enabling is named'
	);

	my $nouns = tempdir( CLEANUP => 1 );
	write_file( "$nouns/README.md",
		      "# Fixture\n\nThe engine does search, highlighting, and "
		    . "folding.\n" );
	( $exit, $output ) = run_lint($nouns);
	is( $exit, 0, 'a noun enumeration passes' ) or diag($output);
}

# An exclamation mark fails, bare and inside brackets.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe tool is fast!\n\n"
		    . "The tool reads one file (and it is fast!).\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'an exclamation mark fails' );
	my $count = () = $output =~ /exclamation mark/g;
	is( $count, 2, 'and both marks are found' );
}

# An AI citation artifact fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nSee https://example.com/?utm_source=chatgpt.com"
		    . " for the source.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'an AI citation artifact fails' );
	like( $output, qr/AI citation artifact/, 'and is labeled' );
}

# Negative parallelism with "about" fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe tool is not about speed. It is about "
		    . "safety.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'not about ... about fails' );
	like( $output, qr/not about \.\.\. about/, 'and is labeled' );
}

# A bare "in the past" fails, and a noun after it passes.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe tool failed in the past.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'in the past fails' );
	like( $output, qr/in the past/, 'and is labeled' );

	my $noun = tempdir( CLEANUP => 1 );
	write_file( "$noun/README.md",
		"# Fixture\n\nDo not write the verb in the past tense.\n\n"
		    . "The count grew in the past hour.\n" );
	( $exit, $output ) = run_lint($noun);
	is( $exit, 0, 'a noun after in the past passes' ) or diag($output);
}

# "Plays a role" fails, with modifiers and in the past tense.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe cache plays a very central role.\n\n"
		    . "The cache played the main role in the outage.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'plays a role fails' );
	my $count = () = $output =~ /plays a role/g;
	is( $count, 2, 'and both forms are found' );
}

# The passive voice with an irregular participle fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe list is built by the scanner.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'an irregular passive fails' );
	like( $output, qr/passive voice "is built by"/, 'and is named' );
}

# The future tense fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nThe tool will read one file.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the future tense fails' );
	like( $output, qr/banned word "will"/, 'and is named' );
}

# A banned pattern fails.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\nIt is not only fast but also small.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a banned pattern fails' );
}

# A code fence and inline code are exempt.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n```\nleverage the tool\n```\n\n"
		    . "Run `leverage` now.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'code is exempt' ) or diag($output);
}

# A scratch file is exempt.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",       "# Fixture\n\nOne file.\n" );
	write_file( "$root/SCRATCHPAD-1.md", "We leverage everything.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a scratch file is exempt' ) or diag($output);
}

# A worktree under .claude/worktrees is exempt, and the rest of
# .claude stays in scope.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md", "# Fixture\n\nOne file.\n" );
	make_path("$root/.claude/worktrees/wt");
	write_file( "$root/.claude/worktrees/wt/README.md",
		"We leverage everything.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a worktree is exempt' ) or diag($output);

	write_file( "$root/.claude/notes.md", "We utilize the tool.\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the rest of .claude stays in scope' );
	like( $output, qr{\.claude/notes\.md:1}, 'and is located' );
	unlike( $output, qr{worktrees}, 'and the worktree stays exempt' );
}

# The scan descends into .github/, lib/, plans/, and t/.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md", "# Fixture\n\nOne file.\n" );
	make_path(
		"$root/.github/ISSUE_TEMPLATE", "$root/lib",
		"$root/plans/001-fixture",      "$root/t"
	);
	write_file( "$root/.github/ISSUE_TEMPLATE/bug.md",
		"We leverage the tool.\n" );
	write_file( "$root/lib/CLAUDE.md", "We leverage the tool.\n" );
	write_file( "$root/plans/001-fixture/plan.md",
		"We leverage the tool.\n" );
	write_file( "$root/t/CLAUDE.md", "We leverage the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the recursive directories are in scope' );
	like( $output, qr/ste-lint: 4 finding\(s\)/, 'and all four are found' );
}

# Without --root, the root is the parent of the script directory.
{
	my $root = tempdir( CLEANUP => 1 );
	make_path("$root/scripts");
	copy( $script, "$root/scripts/ste-lint" );
	chmod 0755, "$root/scripts/ste-lint";
	write_file( "$root/README.md", "# Fixture\n\nWe leverage the tool.\n" );
	my $output = `\Q$root\E/scripts/ste-lint 2>&1`;
	isnt( $? >> 8, 0, 'the default root is the script parent' );
	like(
		$output,
		qr/README\.md:3: banned word "leverage"/,
		'and the root file is found'
	);
}

done_testing();
