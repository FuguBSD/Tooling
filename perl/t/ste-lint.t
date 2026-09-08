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

# run_file(@paths):
#	Run ste-lint on the named paths. Return the exit status and
#	output.
sub run_file (@paths)
{
	my $named  = join ' ', map { "--file \Q$_\E" } @paths;
	my $output = `$script $named 2>&1`;

	return ( $? >> 8, $output );
}

# sentence($count, $lead):
#	One sentence of exactly $count words, headed by $lead.
sub sentence ( $count, $lead )
{
	return join( ' ', $lead, ('word') x ( $count - 1 ) ) . '.';
}

# wrapped($count, $lead):
#	The same sentence, wrapped across two lines.
sub wrapped ( $count, $lead )
{
	my $text = sentence( $count, $lead );
	my $half = int( $count / 2 );
	$text =~ s/^((?:\S+[ ]){$half})/$1\n/;

	return $text;
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

# A sentence over its limit fails, and one under it passes. The
# finding names the rule, the count, the limit, and the first line.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\n" . wrapped( 26, 'The' ) . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a wrapped 26-word sentence fails' );
	like(
		$output,
		qr/README\.md:3: sentence length: 26 words, max 24: The/,
		'and the first line of the sentence is named'
	);

	write_file( "$root/README.md",
		"# Fixture\n\n" . sentence( 25, 'The' ) . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a 25-word descriptive sentence fails' );
	like( $output, qr/25 words, max 24/, 'and the limit is 25' );

	write_file( "$root/README.md",
		"# Fixture\n\n" . sentence( 24, 'The' ) . "\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a 24-word descriptive sentence passes' )
	    or diag($output);
}

# An instruction sentence takes the 20-word limit.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		"# Fixture\n\n" . sentence( 20, 'Run' ) . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a 20-word instruction fails' );
	like( $output, qr/20 words, max 19/, 'and the limit is 20' );

	write_file( "$root/README.md",
		"# Fixture\n\n" . sentence( 19, 'Run' ) . "\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a 19-word instruction passes' ) or diag($output);
}

# A heading, a table row, an indented code block, YAML front matter
# and an HTML comment hold no sentence.
{
	my $root = tempdir( CLEANUP => 1 );
	my $long = join ' ', ('word') x 30;
	write_file( "$root/README.md",
		      "# Fixture\n\n## Head $long\n\n"
		    . "| Head |\n| --- |\n| $long |\n\n"
		    . "    code $long\n\n"
		    . "<!--\nA comment $long.\n-->\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'the prose-free blocks hold no sentence' )
	    or diag($output);

	write_file( "$root/notes.md",
		"---\ntitle: $long\n---\n\n# Fixture\n\nOne file.\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'front matter holds no sentence' ) or diag($output);
}

# A blockquote and a list item stay in scope.
{
	my $root  = tempdir( CLEANUP => 1 );
	my $quote = wrapped( 26, 'The' ) =~ s/^/> /mgr;
	write_file( "$root/README.md", "# Fixture\n\n$quote\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a 26-word sentence in a blockquote fails' );
	like(
		$output,
		qr/README\.md:3: sentence length: 26 words/,
		'and is located'
	);

	write_file( "$root/README.md",
		"# Fixture\n\n- " . sentence( 20, 'Run' ) . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a list marker does not hide an instruction' );
	like( $output, qr/20 words, max 19/, 'and the limit is 20' );
}

# A code span, a link target and a closing mark do not split a
# sentence in the wrong place.
{
	my $root = tempdir( CLEANUP => 1 );
	my $body = join ' ', ('word') x 22;
	write_file( "$root/README.md",
		"# Fixture\n\nThe version `5.34.1` holds $body.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a period inside a span does not split' );
	like( $output, qr/26 words, max 24/, 'so the sentence is one' );

	write_file( "$root/README.md",
		      "# Fixture\n\nThe path [the spec](../spec/index.md) "
		    . "holds "
		    . join( ' ', ('word') x 21 )
		    . ".\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a period inside a link target does not split' );
	like( $output, qr/26 words, max 24/, 'so the sentence is one' );

	write_file( "$root/README.md",
		      "# Fixture\n\nHe said \"$body.\" "
		    . sentence( 26, 'The' )
		    . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a quoted sentence splits at its period' );
	like( $output, qr/26 words, max 24/, 'so the second one is named' );
	my $count = () = $output =~ /sentence length/g;
	is( $count, 1, 'and the first one passes' );

	write_file( "$root/README.md",
		      "# Fixture\n\nHe said ($body.) "
		    . sentence( 26, 'The' )
		    . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a sentence in parentheses splits at its period' );
	like( $output, qr/26 words, max 24/, 'so the second one is named' );
}

# One line can carry more than one sentence finding.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n"
		    . sentence( 26, 'The' ) . ' '
		    . sentence( 27, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'two long sentences on one line fail' );
	my $count = () = $output =~ /README\.md:3: sentence length/g;
	is( $count, 2, 'and each one gets a finding' );
}

# --file scans the named files only, and the scope walk does not
# govern them.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md", "# Fixture\n\nOne file.\n" );
	make_path("$root/docs");
	write_file( "$root/docs/notes.md", "We leverage the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'the scope walk skips docs/' ) or diag($output);

	( $exit, $output ) = run_file("$root/docs/notes.md");
	isnt( $exit, 0, 'but --file reads the same file' );
	like(
		$output,
		qr{docs/notes\.md:1: banned word "leverage"},
		'and reports the finding'
	);

	write_file( "$root/inside.md", "We leverage the tool.\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the same prose inside the scope fails' );
	like(
		$output,
		qr/inside\.md:1: banned word "leverage"/,
		'with the same finding'
	);

	( $exit, $output ) =
	    run_file( "$root/docs/notes.md", "$root/inside.md" );
	isnt( $exit, 0, 'a repeated --file fails' );
	like( $output, qr/ste-lint: 2 finding\(s\)/, 'and scans both files' );
}

# --file runs every rule, and it keeps the fence and span
# exemptions.
{
	my $root = tempdir( CLEANUP => 1 );
	make_path("$root/docs");
	write_file( "$root/docs/notes.md",
		      "# Fixture\n\n```\nleverage the tool\n```\n\n"
		    . "Run `leverage` now.\n\n"
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_file("$root/docs/notes.md");
	isnt( $exit, 0, '--file runs the sentence rules' );
	like( $output, qr/25 words, max 24/, 'and names the count' );
	like( $output, qr/1 finding\(s\)/,   'and code stays exempt' );
}

# A run of two periods ends no sentence, and a question mark does.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe tool reads "
		    . join( ' ', ('word') x 11 ) . ' ... '
		    . join( ' ', ('word') x 12 )
		    . ".\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'an ellipsis holds one sentence' );
	like( $output, qr/26 words, max 24/, 'so the count runs on' );

	write_file( "$root/README.md",
		      "# Fixture\n\nDoes the tool read "
		    . join( ' ', ('word') x 12 ) . "? "
		    . sentence( 25, 'The' )
		    . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a question mark ends a sentence' );
	like( $output, qr/25 words, max 24/, 'so the second one is named' );
	my $count = () = $output =~ /sentence length/g;
	is( $count, 1, 'and the question passes' );
}

# A run of closing marks after the period ends the sentence.
{
	for my $mark (
		'**Do not edit this.**',
		'_The tool is fast._',
		'He said ("the tool is fast.")'
	    )
	{
		my $root = tempdir( CLEANUP => 1 );
		write_file( "$root/README.md",
			"# Fixture\n\n$mark " . sentence( 25, 'The' ) . "\n" );
		my ( $exit, $output ) = run_lint($root);
		isnt( $exit, 0, "a period before $mark ends a sentence" );
		like( $output, qr/25 words, max 24/, 'so the count is right' );
	}
}

# An inline code span holds no comment mark.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nRun `<!--` now.\n\n"
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a span does not open a comment' );
	like(
		$output,
		qr/README\.md:5: sentence length: 25 words/,
		'and the later sentence is found'
	);
}

# An indented line inside a list is a continuation, and an indented
# block outside one is code.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- item one\n  - nested item\n\n" . '    '
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a nested list continuation stays in scope' );
	like( $output, qr/25 words, max 24/, 'and gets a finding' );

	write_file( "$root/README.md",
		      "# Fixture\n\n## Commands\n\n" . '    '
		    . sentence( 25, 'The' )
		    . "\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'an indented code block holds no sentence' )
	    or diag($output);
}

# A table row without a leading pipe, and a setext heading, hold no
# sentence.
{
	my $root = tempdir( CLEANUP => 1 );
	my $long = join ' ', ('word') x 30;
	write_file( "$root/README.md",
		"# Fixture\n\nName | Note\n---- | ----\nrow | $long\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a pipe-less table row holds no sentence' )
	    or diag($output);

	write_file( "$root/README.md",
		"# Fixture\n\nThe $long\n===============\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a setext heading holds no sentence' ) or diag($output);
}

# A new list marker ends a block, so two items do not join.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- "
		    . sentence( 15, 'The' ) . "\n- "
		    . sentence( 15, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'two short list items do not join' ) or diag($output);
}

# A token with no letter and no digit counts as no word.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe tool \x{2014} "
		    . join( ' ', ('word') x 20 )
		    . " \x{2014} holds it.\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a dash counts as no word' ) or diag($output);
}

# A noun that spells an imperative verb takes the longer maximum.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nUse of the tool "
		    . join( ' ', ('word') x 16 )
		    . ".\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a noun subject takes the 24-word maximum' )
	    or diag($output);

	write_file( "$root/README.md",
		      "# Fixture\n\nUse the tool "
		    . join( ' ', ('word') x 17 )
		    . ".\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'but the instruction takes the 19-word maximum' );
	like( $output, qr/20 words, max 19/, 'and is named' );
}

# --file rejects a path that names no readable file.
{
	my $root = tempdir( CLEANUP => 1 );
	make_path("$root/holder.md");
	my ( $exit, $output ) = run_file("$root/holder.md");
	isnt( $exit, 0, '--file on a directory fails' );
	like( $output, qr/ste-lint: not a readable file/, 'and says why' );

	( $exit, $output ) = run_file("$root/absent.md");
	isnt( $exit, 0, '--file on an absent path fails' );
	like( $output, qr/ste-lint: not a readable file/, 'and says why' );
}

# A fence line inside an HTML comment toggles nothing.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n<!--\nAn example:\n```\n-->\n\n"
		    . "We leverage it. "
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a fence inside a comment hides nothing' );
	like( $output, qr/banned word "leverage"/, 'the word rule runs' );
	like( $output, qr/25 words, max 24/,       'the sentence rule runs' );
}

# A CRLF line reads as an LF line.
{
	my $root = tempdir( CLEANUP => 1 );
	my $long = join ' ', ('word') x 30;
	write_file( "$root/notes.md",
		      "---\r\ntitle: The $long\r\n\r\nname: x\r\n---\r\n\r\n"
		    . "# Fixture\r\n\r\nThe tool reads one file.\r\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'CRLF front matter holds no sentence' ) or diag($output);

	write_file( "$root/notes.md",
		"# Fixture\r\n\r\n" . sentence( 25, 'The' ) . "\r\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'but CRLF prose still reports' );
	like( $output, qr/25 words, max 24/, 'and the count holds' );
}

# An indented code block inside a list item starts four columns
# further right, and a line above that column is a continuation.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- Run the build steps:\n\n"
		    . '      make bootstrap '
		    . join( ' ', ('word') x 25 )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a code block inside a list holds no sentence' )
	    or diag($output);

	write_file( "$root/README.md",
		      "# Fixture\n\n- item\n  - nested\n\n" . '    '
		    . sentence( 25, 'The' )
		    . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a nested continuation stays in scope' );
	like( $output, qr/25 words, max 24/, 'and gets a finding' );
}

# A fence and a comment both end a list, so the list state holds
# no stale value.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- item one\n\n```\ncode\n```\n\n" . '    '
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a fence ends the list, so the indent is code' )
	    or diag($output);
}

# A thematic break under a list item is no setext underline.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- "
		    . sentence( 25, 'The' )
		    . "\n\n---\n\nThe tool reads one file.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a thematic break keeps the item above it' );
	like(
		$output,
		qr/README\.md:3: sentence length: 25 words/,
		'and the item reports'
	);
}

# Each word of the subject guard gives the longer maximum.
{
	my $root = tempdir( CLEANUP => 1 );
	for my $word (
		qw(of is are am was were can cannot may might must should))
	{
		write_file( "$root/README.md",
			      "# Fixture\n\nUse $word the tool "
			    . join( ' ', ('word') x 16 )
			    . ".\n" );
		my ( $exit, $output ) = run_lint($root);
		is( $exit, 0, "a table word before \"$word\" is a subject" )
		    or diag($output);
	}

	write_file( "$root/README.md",
		      "# Fixture\n\nNever be the tool "
		    . join( ' ', ('word') x 16 )
		    . ".\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'but "Never be" stays an instruction' );
	like( $output, qr/20 words, max 19/, 'at the 19-word maximum' );
}

# A bad --file path fails before the first finding prints.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/good.md", "# Fixture\n\nWe leverage the tool.\n" );
	my ( $exit, $output ) = run_file( "$root/good.md", "$root/absent.md" );
	isnt( $exit, 0, 'a bad path beside a good one fails' );
	like( $output, qr/ste-lint: not a readable file/, 'and says why' );
	unlike( $output, qr/banned word/, 'and prints no partial finding' );
}

# An abbreviation ends no sentence.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nSee the note, e.g. read the file and "
		    . join( ' ', ('word') x 16 )
		    . ".\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'an abbreviation joins its sentence' ) or diag($output);

	write_file( "$root/README.md",
		      "# Fixture\n\nSee the note, e.g. read the file and "
		    . join( ' ', ('word') x 18 )
		    . ".\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'and the joined sentence still counts' );
	like( $output, qr/26 words, max 24/, 'across the whole of it' );
}

# A finite verb after a table word marks a noun subject.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nCheck runs on every push and "
		    . join( ' ', ('word') x 16 )
		    . ".\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a table word with an s is a verb' ) or diag($output);

	write_file( "$root/README.md",
		      "# Fixture\n\nCheck every push and "
		    . join( ' ', ('word') x 16 )
		    . ".\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'but the instruction keeps its maximum' );
	like( $output, qr/20 words, max 19/, 'at 19 words' );
}

# A reference link drops its label and keeps its text.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe path [the spec][ref] holds "
		    . join( ' ', ('word') x 21 ) . ".\n\n"
		    . "[ref]: ../spec/index.md\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a reference link keeps its text' );
	like( $output, qr/26 words, max 24/, 'and drops its label' );
}

# A sentence that starts on a later line of a block reports that
# line, not the first line of the block.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe tool reads one file.\n"
		    . "The tool writes one report.\n"
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'the third sentence of the block fails' );
	like(
		$output,
		qr/README\.md:5: sentence length: 25 words/,
		'and the finding names its own line'
	);
}

# A comment mark inside a code fence opens no comment, so the rest
# of the file keeps its rules.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n```\n<!-- an unclosed opener\n```\n\n"
		    . "We leverage the tool. "
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a fenced comment mark hides nothing' );
	like( $output, qr/banned word "leverage"/, 'the word rule runs' );
	like( $output, qr/25 words, max 24/,       'the sentence rule runs' );
}

# A blockquote holds a code fence and an indented code block, and
# each one keeps its exemption.
{
	my $root = tempdir( CLEANUP => 1 );
	my $long = join ' ', ('word') x 30;
	write_file( "$root/README.md",
		"# Fixture\n\n> ```\n> We leverage $long\n> ```\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a quoted fence is exempt' ) or diag($output);

	write_file( "$root/README.md",
		      "# Fixture\n\n> Run the steps:\n>\n"
		    . ">     make bootstrap $long\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a quoted code block is exempt' ) or diag($output);

	write_file( "$root/README.md",
		"# Fixture\n\n> " . sentence( 25, 'The' ) . "\n" );
	( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'but quoted prose stays in scope' );
	like( $output, qr/25 words, max 24/, 'and reports' );
}

# Every modal after a table word marks a noun subject.
{
	my $root = tempdir( CLEANUP => 1 );
	for my $modal (qw(can cannot could may might must shall should would)) {
		write_file( "$root/README.md",
			      "# Fixture\n\nReport $modal hold the tool and "
			    . join( ' ', ('word') x 15 )
			    . ".\n" );
		my ( $exit, $output ) = run_lint($root);
		is( $exit, 0, "a table word before \"$modal\" is a subject" )
		    or diag($output);
	}
}

# --file rejects a file that no one can read.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/good.md",   "# Fixture\n\nWe leverage the tool.\n" );
	write_file( "$root/locked.md", "We utilize the tool.\n" );
	chmod 0000, "$root/locked.md";

	# The superuser reads every file, so the test needs a mode
	# that the runner cannot read.
    SKIP: {
		skip( 'the runner reads every file', 3 )
		    if -r "$root/locked.md";
		my ( $exit, $output ) =
		    run_file( "$root/good.md", "$root/locked.md" );
		isnt( $exit, 0, 'an unreadable file fails' );
		like( $output, qr/ste-lint: not a readable file/,
			'and says why' );
		unlike(
			$output,
			qr/banned word/,
			'and prints no partial finding'
		);
	}
	chmod 0644, "$root/locked.md";
}

# Inside a fence no blockquote marker carries meaning, so a quoted
# fence in a Markdown example toggles nothing.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n```markdown\n> ```\n```\n\n"
		    . "We leverage the tool. "
		    . sentence( 25, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a quoted fence inside a fence toggles nothing' );
	like( $output, qr/banned word "leverage"/, 'the word rule runs' );
	like( $output, qr/25 words, max 24/,       'the sentence rule runs' );
}

# A blockquote marker takes at most three columns, so a deeper
# indent is a code block.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n## Head\n\n"
		    . '    > redirect the output and hold '
		    . join( ' ', ('word') x 24 )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'an indented line that starts with > is code' )
	    or diag($output);
}

# A thematic break under a list item is no setext underline, with
# no blank line between them.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\n- "
		    . sentence( 25, 'The' )
		    . "\n---\n\nThe tool reads one file.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a bare thematic break keeps the item' );
	like(
		$output,
		qr/README\.md:3: sentence length: 25 words/,
		'and the item reports'
	);

	write_file( "$root/README.md",
		      "# Fixture\n\n"
		    . sentence( 25, 'The' )
		    . "\n---\n\nThe tool reads one file.\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'but a paragraph above one is a setext heading' )
	    or diag($output);
}

# A table word without an "s" is the object of an instruction, and
# a second word with no letter names no verb.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nRead state from the file and "
		    . join( ' ', ('word') x 15 )
		    . ".\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a bare table word keeps the instruction' );
	like( $output, qr/21 words, max 19/, 'at the 19-word maximum' );

	write_file( "$root/README.md",
		      "# Fixture\n\nCheck 1, the agreement of the passes, "
		    . "rejected "
		    . join( ' ', ('word') x 16 )
		    . ".\n" );
	( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a numeric second word names no verb' )
	    or diag($output);
}

# An abbreviation that can end a sentence stays out of the table.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md",
		      "# Fixture\n\nThe tool reads a file, a directory, etc. "
		    . sentence( 20, 'The' )
		    . "\n" );
	my ( $exit, $output ) = run_lint($root);
	is( $exit, 0, 'a sentence-final etc. ends its sentence' )
	    or diag($output);
}

# --file takes a Markdown path only.
{
	my ( $exit, $output ) = run_file($script);
	isnt( $exit, 0, '--file on a Perl script fails' );
	like( $output, qr/ste-lint: not a Markdown file/, 'and says why' );
}

done_testing();
