#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for the canonical dist script against fixture repositories
#
# Each fixture is a temporary directory with a .toolingrc and a
# minimal source tree. The script runs as a subprocess from the
# fixture root, exactly as `make dist` runs it in a consumer.

use v5.36;
use Test::More;
use Cwd        qw(getcwd);
use FindBin    qw($RealBin);
use File::Find ();
use File::Path qw(make_path);
use File::Spec ();
use File::Temp qw(tempdir);

my $script = "$RealBin/../sync/scripts/dist";
ok( -x $script, 'dist script is executable' );

sub write_file ( $path, $content )
{
	my ($dir) = $path =~ m{^(.*)/[^/]+\z};
	make_path($dir) if defined $dir && !-d $dir;
	open my $fh, '>', $path or die "Cannot write $path: $!";
	print $fh $content;
	close $fh;
}

# fixture($toolingrc):
#	A directory with a .toolingrc and a minimal source tree: two
#	modules with sidecars, a share file, an executable, tests in
#	two directories, and the doc files.
sub fixture ($toolingrc)
{
	my $dir = tempdir( CLEANUP => 1 );

	write_file( "$dir/.toolingrc",  $toolingrc );
	write_file( "$dir/lib/Fix.pm",  "package Fix;\n1;\n" );
	write_file( "$dir/lib/Fix.pod", "=pod\n\n=cut\n" );
	write_file( "$dir/lib/Fix/Part.pm",
		"package Fix::Part;\n1;\npackage Fix::Part::Inner;\n1;\n" );
	write_file( "$dir/share/fix/data", "shared\n" );
	write_file( "$dir/scripts/ftp",    "#!/bin/sh\n" );
	write_file( "$dir/bin/fix",        "#!/usr/bin/env perl\n" );
	write_file( "$dir/t/fix/basic.t",
		"use Test::More;\nok(1);\ndone_testing();\n" );
	write_file( "$dir/t/other/extra.t",
		"use Test::More;\nok(1);\ndone_testing();\n" );
	write_file( "$dir/README.md", "# Fix\n" );
	write_file( "$dir/LICENSE",   "ISC\n" );
	write_file( "$dir/cpanfile",  "\n" );

	return $dir;
}

# run_in($dir, @args):
#	Run dist with $dir as the working directory.
sub run_in ( $dir, @args )
{
	my $cwd = getcwd();
	chdir $dir or die "chdir $dir: $!";
	my $output = `$script @args 2>&1`;
	my $exit   = $? >> 8;
	chdir $cwd or die "chdir $cwd: $!";

	return ( $exit, $output );
}

# unpack_dist($dir, $dist, $version):
#	Extract the built tarball and return the extracted tree path.
sub unpack_dist ( $dir, $dist, $version )
{
	my $tarball = "$dir/build/$dist-$version.tar.gz";
	return unless -f $tarball;
	system( 'tar', '-xzf', $tarball, '-C', "$dir/build" ) == 0
	    or return;

	return "$dir/build/$dist-$version";
}

sub slurp ($path)
{
	open my $fh, '<', $path or die "Cannot read $path: $!";
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

# The full shape: exe, share-extra, prereqs, one test directory.
{
	my $dir = fixture(<<'EOF');
# A fixture in the shape of FuguVM.
dist.name        App-Fix
dist.module      App::Fix
dist.abstract    fix things with one tool
dist.exe         bin/fix
dist.testdir     t/fix
dist.share-extra scripts/ftp

# Other tools own other prefixes. This line must pass through.
other.key        ignored

dist.prereq      Net::SSH2
dist.prereq      URI
EOF
	my ( $exit, $output ) = run_in( $dir, '--version 1.2.3' );
	is( $exit, 0, 'the full shape builds' ) or diag($output);

	my $tree = unpack_dist( $dir, 'App-Fix', '1.2.3' );
	ok( defined $tree, 'the tarball unpacks' ) or last;

	my $mfpl = slurp("$tree/Makefile.PL");
	like( $mfpl, qr/NAME\s+=> 'App::Fix'/,   'the module names the dist' );
	like( $mfpl, qr/VERSION\s+=> '1\.2\.3'/, 'the version is the input' );
	like(
		$mfpl,
		qr/ABSTRACT\s+=> 'fix things with one tool'/,
		'the abstract carries its spaces'
	);
	like( $mfpl, qr{'bin/fix'},        'the executable ships' );
	like( $mfpl, qr/'Net::SSH2' => 0/, 'the first prereq ships' );
	like( $mfpl, qr/'URI' => 0/,       'the second prereq ships' );
	like(
		$mfpl,
qr{'scripts/ftp' => '\$\(INST_LIB\)/auto/share/dist/App-Fix/scripts/ftp'},
		'share-extra maps into the share tree under its own path'
	);
	like(
		$mfpl,
qr{'share/fix/data' => '\$\(INST_LIB\)/auto/share/dist/App-Fix/fix/data'},
		'share files map into the share tree'
	);
	like(
		$mfpl,
		qr{TESTS => 't/fix/\*\.t'},
		'the staged tests run from their directory'
	);
	unlike( $mfpl, qr{t/other}, 'an unlisted test directory stays out' );

	# The version stamp: every package of every staged module gets
	# our $VERSION, the source modules keep none, and the sidecars
	# stay untouched.
	like(
		slurp("$tree/lib/Fix.pm"),
		qr/^package Fix;\nour \$VERSION = '1\.2\.3';$/m,
		'the staged module carries the version'
	);
	my @stamps =
	    slurp("$tree/lib/Fix/Part.pm") =~ /^our \$VERSION = '1\.2\.3';$/mg;
	is( scalar @stamps, 2, 'every package of one file gets a stamp' );
	unlike( slurp("$tree/lib/Fix.pod"),
		qr/\$VERSION/, 'a sidecar gets no stamp' );
	unlike( slurp("$dir/lib/Fix.pm"),
		qr/\$VERSION/, 'the source module stays clean' );

	# The MANIFEST lists every file of the tree, itself included.
	my @manifest = split /\n/, slurp("$tree/MANIFEST");
	my @files;
	File::Find::find( {
			wanted => sub {
				push @files,
				    File::Spec->abs2rel( $File::Find::name,
					$tree )
				    if -f $_;
			},
			no_chdir => 1,
		},
		$tree
	);
	is_deeply(
		[ sort @manifest ],
		[ sort @files ],
		'the MANIFEST matches the tree exactly'
	);
}

# The lean shape: no exe, no share-extra, no prereqs, two test
# directories. This is the shape of Fugu.
{
	my $dir = fixture(<<'EOF');
dist.name     Fix
dist.module   Fix
dist.abstract a lean fixture
dist.testdir  t/fix
dist.testdir  t/other
EOF
	my ( $exit, $output ) = run_in( $dir, '--version 0.1.0' );
	is( $exit, 0, 'the lean shape builds' ) or diag($output);

	my $tree = unpack_dist( $dir, 'Fix', '0.1.0' );
	ok( defined $tree, 'the tarball unpacks' ) or last;

	my $mfpl = slurp("$tree/Makefile.PL");
	like(
		$mfpl,
		qr{TESTS => 't/fix/\*\.t t/other/\*\.t'},
		'every test directory joins the glob'
	);
	unlike( $mfpl, qr{'bin/},        'no executable ships' );
	unlike( $mfpl, qr{'scripts/ftp}, 'no share-extra ships' );
	ok( !-f "$tree/bin/fix", 'the unlisted executable stays out' );
}

# An untagged tree defaults to 0.0.0.
{
	my $dir = fixture(<<'EOF');
dist.name     Fix
dist.module   Fix
dist.abstract a lean fixture
dist.testdir  t/fix
EOF
	my ( $exit, $output ) = run_in($dir);
	is( $exit, 0, 'no version builds' ) or diag($output);
	like( $output, qr/Fix-0\.0\.0\.tar\.gz/, 'and defaults to 0.0.0' );
}

# Configuration errors fail closed, before anything is staged.
my %BAD = (
	'a missing .toolingrc' => undef,
	'an unknown dist key'  => "dist.name X\ndist.module X\n"
	    . "dist.abstract x\ndist.typo y\n",
	'a missing dist.name'    => "dist.module X\ndist.abstract x\n",
	'a duplicate single key' => "dist.name X\ndist.name Y\n"
	    . "dist.module X\ndist.abstract x\n",
	'a key without a value' => "dist.name\n",
);
for my $case ( sort keys %BAD ) {
	my $dir = tempdir( CLEANUP => 1 );
	write_file( "$dir/.toolingrc", $BAD{$case} ) if defined $BAD{$case};
	write_file( "$dir/lib/Fix.pm", "package Fix;\n1;\n" );

	my ( $exit, $output ) = run_in( $dir, '--version 1.0.0' );
	isnt( $exit, 0, "$case exits non-zero" );
	ok( !-d "$dir/build", "$case stages nothing" );
}

# A bad version dies before anything is staged.
{
	my $dir = fixture(<<'EOF');
dist.name     Fix
dist.module   Fix
dist.abstract a lean fixture
dist.testdir  t/fix
EOF
	my ( $exit, $output ) = run_in( $dir, '--version nonsense' );
	isnt( $exit, 0, 'a bad version exits non-zero' );
	like( $output, qr/not dotted-decimal/, 'and says why' );
}

done_testing();
