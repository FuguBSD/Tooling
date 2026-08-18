#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for scripts/sync against a fixture consumer
#
# sync copies perl/sync/** of this repository into a consumer. The
# fixture consumer is a temporary directory with a .toolingrc. The
# tests drive the real script as a subprocess, exactly as a consumer
# and the CI drift gate run it.

use v5.36;
use Test::More;
use Cwd        qw(getcwd);
use FindBin    qw($RealBin);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $script = "$RealBin/../../scripts/sync";
my $root   = "$RealBin/../..";
ok( -x $script, 'sync script is executable' );

# run_in($dir):
#	Run sync with $dir as the working directory.
sub run_in ( $dir, @args )
{
	my $cwd = getcwd();
	chdir $dir or die "chdir $dir: $!";
	my $output = `$script @args 2>&1`;
	my $exit   = $? >> 8;
	chdir $cwd or die "chdir $cwd: $!";

	return ( $exit, $output );
}

sub consumer ()
{
	my $dir = tempdir( CLEANUP => 1 );
	open my $fh, '>', "$dir/.toolingrc" or die "write: $!";
	print $fh "dist.name Fix\n";
	close $fh;

	return $dir;
}

# Without a .toolingrc the target is not a consumer.
{
	my $dir = tempdir( CLEANUP => 1 );
	my ( $exit, $output ) = run_in($dir);
	isnt( $exit, 0, 'a directory without .toolingrc is refused' );
	like( $output, qr/\.toolingrc/, 'and the error names the marker' );
}

# The Tooling root itself is not a consumer.
{
	my ( $exit, $output ) = run_in($root);
	isnt( $exit, 0, 'the Tooling root is refused' );
}

# A fresh consumer receives every file, with the exec bit.
my $dir = consumer();
{
	my ( $exit, $output ) = run_in($dir);
	is( $exit, 0, 'sync into a fresh consumer works' ) or diag($output);

	ok( -f "$dir/scripts/dist",     'dist arrives' );
	ok( -f "$dir/scripts/deps",     'deps arrives' );
	ok( -f "$dir/scripts/ftp",      'ftp arrives' );
	ok( -f "$dir/t/ci/workflows.t", 'the consumer CI test arrives' );
	ok( -x "$dir/scripts/deps",     'the exec bit survives' );

	( $exit, $output ) = run_in( $dir, '--check' );
	is( $exit, 0, 'a fresh sync passes --check' ) or diag($output);
	like( $output, qr/no drift/, 'and reports no drift' );
}

# --check fails on a content change, a lost exec bit, and a missing
# file - and changes nothing itself.
{
	open my $fh, '>>', "$dir/scripts/ftp" or die "append: $!";
	print $fh "# drift\n";
	close $fh;

	my ( $exit, $output ) = run_in( $dir, '--check' );
	isnt( $exit, 0, 'a content change fails --check' );
	like( $output, qr{scripts/ftp: content differs}, 'and is named' );

	( $exit, $output ) = run_in($dir);
	is( $exit, 0, 'sync repairs the drift' );
	( $exit, $output ) = run_in( $dir, '--check' );
	is( $exit, 0, 'and --check passes again' );

	chmod 0644, "$dir/scripts/deps" or die "chmod: $!";
	( $exit, $output ) = run_in( $dir, '--check' );
	isnt( $exit, 0, 'a lost exec bit fails --check' );
	like( $output, qr{scripts/deps: exec bit differs}, 'and is named' );
	chmod 0755, "$dir/scripts/deps" or die "chmod: $!";

	unlink "$dir/t/ci/workflows.t" or die "unlink: $!";
	( $exit, $output ) = run_in( $dir, '--check' );
	isnt( $exit, 0, 'a missing file fails --check' );
	like( $output, qr{t/ci/workflows\.t: missing}, 'and is named' );
}

# A consumer file that Tooling does not own stays untouched.
{
	open my $fh, '>', "$dir/scripts/spec-coverage" or die "write: $!";
	print $fh "#!/usr/bin/env perl\n";
	close $fh;

	my ( $exit, $output ) = run_in($dir);
	is( $exit, 0, 'sync over extra files works' );
	ok( -f "$dir/scripts/spec-coverage", 'the extra file survives' );

	( $exit, $output ) = run_in( $dir, '--check' );
	is( $exit, 0, 'and --check ignores it' );
}

done_testing();
