#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The wrapper shim of the org pack (SYNC-BOOTSTRAP)
#
# FuguBench generates org/sync/scripts/fugubench, and this repository
# holds the pin. The static checks read the text: the parse, the line
# cap, the shebang, the exec bit, and the three pin values. The
# behavior checks drive the real file with FUGUBENCH set to a stub
# program, so no test here reaches the network. HOME points into a
# temporary tree, so no test writes the real ~/.cache/fugubench.

use v5.36;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);

my $shim = "$RealBin/../../org/sync/scripts/fugubench";

# _slurp($path):
#	Whole file as text, or the empty string with a failed
#	assertion.
sub _slurp ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return q{};
	};
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

my $text = _slurp($shim);

# The file is POSIX shell, and it stays under the cap of FuguBench
# DIST-SHIM-6.
{
	my $output = `sh -n "$shim" 2>&1`;
	is( $? >> 8, 0, 'sh -n parses the shim' ) or diag($output);

	my $lines = () = $text =~ /\n/g;
	cmp_ok( $lines, '<', 61, 'the shim holds fewer than 61 lines' );
}

# The file runs as a program of its own.
{
	like( $text, qr{\A\#!/bin/sh\n}, 'the shim starts with #!/bin/sh' );
	ok( -x $shim, 'the exec bit is set' );
}

# The pin: the version, the asset URL, and the digest.
{
	my ($version) = $text =~ /^version=(\S+)$/m;
	my ($url)     = $text =~ /^url=(\S+)$/m;
	my ($want)    = $text =~ /^want=(\S+)$/m;
	$version //= q{};
	$url     //= q{};
	$want    //= q{};

	like( $version, qr/\A[0-9]+(?:\.[0-9]+)+\z/,
		'the version is a dotted-decimal number' );
	like( $url, qr/\Q$version\E/, 'the url holds the version' );
	like( $url, qr{/fugubench\z}, 'and the url ends in /fugubench' );
	like( $want, qr/\A[0-9a-f]{64}\z/,
		'the want value is 64 hexadecimal characters' );
}

# _home():
#	A fresh empty HOME, so a download shows up as a new cache.
sub _home ()
{
	my $home = tempdir( CLEANUP => 1 );
	make_path($home);

	return $home;
}

# _run($home, $value, @args):
#	Run the shim with HOME, with FUGUBENCH, and with arguments.
#	Return the exit status and the output.
sub _run ( $home, $value, @args )
{
	local $ENV{HOME}      = $home;
	local $ENV{FUGUBENCH} = $value;
	my $output = `"$shim" @args 2>&1`;
	my $exit   = $? >> 8;

	return ( $exit, $output );
}

# A stub program serves FUGUBENCH, so the shim runs it in place of
# the release (FuguBench DIST-SHIM-2). The stub also proves the
# pass-through and the exit code (FuguBench DIST-SHIM-5).
{
	my $dir  = tempdir( CLEANUP => 1 );
	my $stub = "$dir/stub";
	open my $fh, '>', $stub or die "write $stub: $!";
	print $fh "#!/bin/sh\necho \"stub got: \$*\"\nexit 7\n";
	close $fh;
	chmod 0755, $stub or die "chmod $stub: $!";

	my ( $exit, $output ) = _run( _home(), $stub, 'deps', 'tool' );
	is( $exit, 7, 'the shim returns the exit code of the stub' );
	like(
		$output,
		qr/^stub got: deps tool$/m,
		'and it passes each argument through'
	);
}

# FUGUBENCH with no executable behind it is an error, and the message
# names the value (FuguBench DIST-SHIM-2).
{
	my $dir  = tempdir( CLEANUP => 1 );
	my $gone = "$dir/absent";

	my ( $exit, $output ) = _run( _home(), $gone );
	isnt( $exit, 0, 'a FUGUBENCH without an executable fails' );
	like( $output, qr/\Q$gone\E/, 'and the message names the value' );
}

# An empty FUGUBENCH is set, so the shim takes the same branch and
# downloads nothing.
{
	my $home = _home();

	my ( $exit, $output ) = _run( $home, q{} );
	isnt( $exit, 0, 'an empty FUGUBENCH fails' ) or diag($output);
	ok( !-e "$home/.cache/fugubench", 'and the shim downloads nothing' );
}

done_testing();
