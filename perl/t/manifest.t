#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The dependency manifests of this repository parse (MK-DEPS)
#
# A typo in deps/<OS>.txt must fail here, and not on the machine of an
# operator halfway through an install. CI runs Linux only, so nothing
# else reads deps/Darwin.txt. The test drives the FuguBench program
# over every manifest and every environment under --dry-run: it reads
# the exit code and the output, it parses no manifest itself, and it
# asks no network. FuguBench owns each rule of the manifest format.
#
# The program exits zero and reports "no dependencies for <os>" when it
# finds no manifest at the start directory. The exit code alone thus
# proves nothing, and the test reads the output for that report too.
#
# The test needs a program that the operator already has. It takes
# FUGUBENCH, or the release that the shim caches under the version it
# pins. It downloads none, and it skips when it finds none.

use v5.36;
use Test::More;
use Cwd     qw(getcwd);
use FindBin qw($RealBin);

my $root = "$RealBin/../..";

# _slurp($path):
#	Whole file as text, or undef.
sub _slurp ($path)
{
	open my $fh, '<', $path or return;
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

# _cached():
#	The release that the shim caches under the version it pins, or
#	undef.
sub _cached ()
{
	my $text = _slurp("$root/org/sync/scripts/fugubench") // q{};
	my ($version) = $text =~ /^version=(\S+)$/m;
	return unless defined $version;

	my $home   = $ENV{HOME} // q{};
	my $cached = "$home/.cache/fugubench/$version/fugubench";
	return $cached if -x $cached;

	return;
}

# A set FUGUBENCH is the choice of the operator. A value that names no
# executable is an error, and the test must not run a different
# program. It fails here instead.
my $set    = $ENV{FUGUBENCH};
my $chosen = defined $set && length $set;

if ( $chosen && !-x $set ) {
	plan tests => 1;
	fail("FUGUBENCH names no executable: $set");
	exit;
}

my $program = $chosen ? $set : _cached();

plan skip_all =>
    'no fugubench program: this run parses no manifest; run make deps'
    unless defined $program;

# _manifests():
#	The OS name of each manifest under deps/. KEYS.txt, the local
#	key file and SHA256.txt carry the keys and the digests, so
#	they are no manifest.
sub _manifests ()
{
	my %reserved =
	    map { $_ => 1 } qw(KEYS.txt KEYS.local.txt SHA256.txt);

	opendir my $dh, "$root/deps" or die "opendir $root/deps: $!";
	my @names = sort grep { /\.txt\z/ && !$reserved{$_} } readdir $dh;
	closedir $dh;

	return map { s/\.txt\z//r } @names;
}

# _run($os, $env):
#	Run the deps verb from the repository root, and return the
#	exit status with the output.
sub _run ( $os, $env )
{
	my $cwd = getcwd();
	chdir $root or die "chdir $root: $!";
	my $output = `"$program" deps --os $os --dry-run $env 2>&1`;
	my $exit   = $? >> 8;
	chdir $cwd or die "chdir $cwd: $!";

	return ( $exit, $output );
}

my @os = _manifests();
ok( scalar @os, 'deps/ holds a manifest' );

for my $os (@os) {
	for my $env (qw(tool runtime test develop)) {
		my ( $exit, $output ) = _run( $os, $env );
		is( $exit, 0, "deps/$os.txt parses for $env" )
		    or diag($output);
		unlike(
			$output,
			qr/no dependencies for \Q$os\E/,
			"deps/$os.txt reaches the program for $env"
		) or diag($output);
	}
}

done_testing();
