#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for org/sync/scripts/ste-lint against a fixture tree
#
# The tests drive the real script as a subprocess against a temporary
# directory, exactly as a consumer runs it.

use v5.36;
use Test::More;
use FindBin    qw($RealBin);
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

# A banned word fails, with its file and line.
{
	my $root = tempdir( CLEANUP => 1 );
	write_file( "$root/README.md", "# Fixture\n\nWe leverage the tool.\n" );
	my ( $exit, $output ) = run_lint($root);
	isnt( $exit, 0, 'a banned word fails' );
	like( $output, qr/README\.md:3: banned word/, 'and is located' );
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

done_testing();
