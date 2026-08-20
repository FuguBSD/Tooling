#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for the canonical deps script against fixture manifests
#
# Everything runs under --dry-run. Thus the tests never invoke a
# package manager. --os drives all three platform branches from one
# runner.

use v5.36;
use Test::More;
use Cwd        qw(getcwd);
use FindBin    qw($RealBin);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $script = "$RealBin/../sync/scripts/deps";
my $root   = "$RealBin/../..";
ok( -x $script, 'deps script is executable' );

sub write_file ( $path, $content )
{
	open my $fh, '>', $path or die "Cannot write $path: $!";
	print $fh $content;
	close $fh;
}

# fixture($os, $manifest):
#	A directory that holds deps/<os>.txt. deps reads the manifest
#	relative to the current directory. Thus tests chdir into this
#	directory.
sub fixture ( $os, $manifest )
{
	my $dir = tempdir( CLEANUP => 1 );
	make_path("$dir/deps");
	write_file( "$dir/deps/$os.txt", $manifest );

	return $dir;
}

# run_in($dir, @args):
#	Run deps with $dir as the working directory.
sub run_in ( $dir, @args )
{
	my $cwd = getcwd();
	chdir $dir or die "chdir $dir: $!";
	my $output = `$script @args 2>&1`;
	my $exit   = $? >> 8;
	chdir $cwd or die "chdir $cwd: $!";

	return ( $exit, $output );
}

my $MANIFEST = <<'EOF';
# a comment
runtime pkg alpha
runtime cpan Foo::Bar

	# an indented comment
test pkg beta
develop pkg gamma
develop cpan Baz
EOF

# Environment filtering
{
	my $dir = fixture( 'OpenBSD', $MANIFEST );

	my ( $exit, $output ) =
	    run_in( $dir, '--os OpenBSD --dry-run runtime' );
	is( $exit, 0, 'runtime exits 0' );
	like( $output, qr/^\+ pkg_add alpha$/m, 'runtime selects its package' );
	like( $output, qr/cpanm .*Foo::Bar/,
		'runtime selects its CPAN module' );
	unlike( $output, qr/beta|gamma|Baz/,
		'other environments are not selected' );

	( $exit, $output ) = run_in( $dir, '--os OpenBSD --dry-run test' );
	is( $exit, 0, 'test exits 0' );
	like( $output, qr/^\+ pkg_add beta$/m,
		'test selects only its package' );
	unlike( $output, qr/alpha|gamma/, 'and nothing else' );
	unlike( $output, qr/cpanm/, 'no cpanm run when a tier has no modules' );
}

# deps skips comments and blank lines, including an indented comment
{
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', $MANIFEST ),
		'--os OpenBSD --dry-run develop'
	);
	is( $exit, 0, 'a manifest with comments and blanks parses' );
	like( $output, qr/^\+ pkg_add gamma$/m, 'develop package selected' );
	unlike( $output, qr/comment/, 'comment text never reaches a command' );
}

# Per-OS command shapes
{
	my $manifest = "runtime pkg alpha\nruntime pkg beta\n";

	my ( undef, $openbsd ) = run_in(
		fixture( 'OpenBSD', $manifest ),
		'--os OpenBSD --dry-run runtime'
	);
	like( $openbsd, qr/^\+ pkg_add alpha beta$/m, 'OpenBSD uses pkg_add' );

	my ( undef, $linux ) = run_in(
		fixture( 'Linux', $manifest ),
		'--os Linux --dry-run runtime'
	);
	like(
		$linux,
		qr/^\+ sudo apt-get update$/m,
		'Linux refreshes apt first'
	);
	like(
		$linux,
		qr/^\+ sudo apt-get install -y alpha beta$/m,
		'Linux uses apt-get install'
	);

	my ( undef, $darwin ) = run_in(
		fixture( 'Darwin', $manifest ),
		'--os Darwin --dry-run runtime'
	);
	like( $darwin, qr/^\+ brew install alpha beta$/m, 'Darwin uses brew' );
}

# An OS with a manifest but no package manager branch
{
	my ( $exit, $output ) =
	    run_in( fixture( 'Plan9', "runtime pkg alpha\n" ),
		'--os Plan9 --dry-run runtime' );
	isnt( $exit, 0, 'an unsupported OS exits non-zero' );
	like( $output, qr/Unknown OS: Plan9/, 'and says which OS' );
}

# List-form exec: a name that contains a space stays one argument.
# The shell version built a string and let word splitting have it.
# Thus it installed two wrong packages.
{
	my ( $exit, $output ) =
	    run_in( fixture( 'OpenBSD', "runtime pkg foo bar\n" ),
		'--os OpenBSD --dry-run runtime' );
	is( $exit, 0, 'a package name with a space parses' );
	like(
		$output,
		qr/^\+ pkg_add 'foo bar'$/m,
		'and is passed as a single argument'
	);
}

# CPAN options. Both cases pin PERL_LOCAL_LIB_ROOT rather than
# inherit it. CI sets it: .github/actions/setup-perl exports it for
# local::lib. A developer shell usually does not set it. Thus an
# inherited value makes the same test assert opposite things in the
# two places.
{
	my $dir = fixture( 'OpenBSD', "runtime cpan Foo::Bar\n" );

	{
		delete local $ENV{PERL_LOCAL_LIB_ROOT};
		my ( undef, $output ) =
		    run_in( $dir, '--os OpenBSD --dry-run runtime' );
		like(
			$output,
			qr/^\+ cpanm --notest Foo::Bar$/m,
			'cpanm runs --notest'
		);
		unlike( $output, qr/--local-lib/,
			'no --local-lib without PERL_LOCAL_LIB_ROOT' );
	}

	local $ENV{PERL_LOCAL_LIB_ROOT} = '/tmp/fugu-locallib';
	my ( undef, $output ) =
	    run_in( $dir, '--os OpenBSD --dry-run runtime' );
	like(
		$output,
		qr/^\+ cpanm --notest --local-lib=\S+ Foo::Bar$/m,
		'PERL_LOCAL_LIB_ROOT becomes --local-lib'
	);
	like(
		$output,
		qr{--local-lib=/tmp/fugu-locallib},
		'and carries its value'
	);
}

# Usage and manifest errors
{
	my ( $exit, $output ) = run_in( fixture( 'OpenBSD', '' ), '' );
	isnt( $exit, 0, 'no environment argument exits non-zero' );
	like( $output, qr/usage: deps/, 'and prints usage' );
}

# An environment that is not one of the three selects nothing. The
# shell version reported this as a successful install.
{
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', $MANIFEST ),
		'--os OpenBSD --dry-run bogus'
	);
	isnt( $exit, 0, 'an unknown environment exits non-zero' );
	like( $output, qr/unknown environment 'bogus'/, 'and names it' );
	unlike(
		$output,
		qr/installed successfully/,
		'and does not claim success'
	);
}

{
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', "runtime pkg\n" ),
		'--os OpenBSD --dry-run runtime'
	);
	isnt( $exit, 0, 'a line missing its name exits non-zero' );
	like( $output, qr/Invalid format/, 'and reports the bad line' );
	like(
		$output,
		qr/<environment> <pkg\|dist\|cpan>/,
		'and the expected shape'
	);
}

{
	my ( $exit, $output ) =
	    run_in( fixture( 'OpenBSD', "runtime deb alpha\n" ),
		'--os OpenBSD --dry-run runtime' );
	isnt( $exit, 0, 'an unknown type exits non-zero' );
	like( $output, qr/Unknown type 'deb'/, 'and names the type' );
}

# A dist line names a release-asset URL. The script fetches it with
# scripts/ftp and installs the tarball with cpanm, after the packages
# and before the cpan modules.
{
	# CI sets PERL_LOCAL_LIB_ROOT, which adds a --local-lib option
	# to every cpanm command. Unset it so the asserted command
	# lines are the same in every environment.
	delete local $ENV{PERL_LOCAL_LIB_ROOT};

	my $manifest =
	      "runtime pkg alpha\n"
	    . "runtime dist https://example.org/dl/Fugu.tar.gz\n"
	    . "runtime cpan Foo::Bar\n";
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', $manifest ),
		'--os OpenBSD --dry-run runtime'
	);
	is( $exit, 0, 'a dist line parses' );
	like(
		$output,
qr{^\+ \S+/ftp \S+/Fugu\.tar\.gz https://example\.org/dl/Fugu\.tar\.gz$}m,
		'the tarball downloads through scripts/ftp'
	);
	like(
		$output,
		qr{^\+ cpanm --notest \S+/Fugu\.tar\.gz$}m,
		'and installs with cpanm'
	);
	like(
		$output,
		qr{pkg_add alpha.*Fugu\.tar\.gz.*cpanm --notest Foo::Bar}s,
		'dists install after packages and before cpan modules'
	);
}

# A dist URL must end in a file name.
{
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', "runtime dist https://example.org/dl/\n" ),
		'--os OpenBSD --dry-run runtime'
	);
	isnt( $exit, 0, 'a dist URL with no file name exits non-zero' );
	like( $output, qr/cannot name the file/, 'and says why' );
}

# A bin line holds a command name and a URL. The script fetches the
# file through scripts/ftp into ~/.local/bin and sets the execute
# bit. {os} and {arch} in the URL become the platform words.
{
	my $manifest =
	    "runtime bin scw https://example.org/dl/cli_2.0_{os}_{arch}\n";
	my ( $exit, $output ) = run_in( fixture( 'Linux', $manifest ),
		'--os Linux --arch x86_64 --dry-run runtime' );
	is( $exit, 0, 'a bin line parses' );
	like(
		$output,
		qr{^\+ mkdir -p \S+/\.local/bin$}m,
		'the target directory is created'
	);
	like(
		$output,
qr{^\+ \S+/ftp \S+/\.local/bin/scw https://example\.org/dl/cli_2\.0_linux_amd64$}m,
		'the placeholders become the platform words'
	);
	like(
		$output,
		qr{^\+ chmod 755 \S+/\.local/bin/scw$}m,
		'the file gets the execute bit'
	);
}

# A bin line with an archive URL carries a third word: the file path
# in the archive. The script fetches the archive, unpacks only that
# file, and copies it into ~/.local/bin. The placeholders work in the
# path too.
{
	my $manifest =
	      "runtime bin gh "
	    . "https://example.org/dl/gh_2.0_{os}_{arch}.tar.gz "
	    . "gh_2.0_{os}_{arch}/bin/gh\n";
	my ( $exit, $output ) = run_in( fixture( 'Linux', $manifest ),
		'--os Linux --arch x86_64 --dry-run runtime' );
	is( $exit, 0, 'a bin line with an archive parses' );
	like(
		$output,
qr{^\+ \S+/ftp \S+/gh_2\.0_linux_amd64\.tar\.gz https://example\.org/dl/gh_2\.0_linux_amd64\.tar\.gz$}m,
		'the archive downloads through scripts/ftp'
	);
	like(
		$output,
qr{^\+ tar -xzf \S+/gh_2\.0_linux_amd64\.tar\.gz -C \S+ gh_2\.0_linux_amd64/bin/gh$}m,
		'tar unpacks only the named file'
	);
	like(
		$output,
		qr{^\+ cp \S+/gh_2\.0_linux_amd64/bin/gh \S+/\.local/bin/gh$}m,
		'the file is copied into ~/.local/bin'
	);
	like(
		$output,
		qr{^\+ chmod 755 \S+/\.local/bin/gh$}m,
		'the file gets the execute bit'
	);
}

# A .zip archive unpacks with unzip.
{
	my $manifest =
	      "runtime bin gh "
	    . "https://example.org/dl/gh_2.0_macOS_{arch}.zip "
	    . "gh_2.0_macOS_{arch}/bin/gh\n";
	my ( $exit, $output ) = run_in( fixture( 'Darwin', $manifest ),
		'--os Darwin --arch arm64 --dry-run runtime' );
	is( $exit, 0, 'a bin line with a zip archive parses' );
	like(
		$output,
qr{^\+ unzip -q \S+/gh_2\.0_macOS_arm64\.zip gh_2\.0_macOS_arm64/bin/gh -d \S+$}m,
		'unzip unpacks only the named file'
	);
}

# An archive URL without the file path is a format error, and so is
# a file path with a plain URL.
{
	my ( $exit, $output ) = run_in(
		fixture( 'Linux', "runtime bin gh https://e.org/gh.tar.gz\n" ),
		'--os Linux --dry-run runtime'
	);
	isnt( $exit, 0, 'an archive URL without a file path exits non-zero' );
	like( $output, qr/An archive URL needs the file path/, 'and says why' );

	( $exit, $output ) = run_in(
		fixture( 'Linux', "runtime bin gh https://e.org/gh bin/gh\n" ),
		'--os Linux --dry-run runtime'
	);
	isnt( $exit, 0, 'a file path with a plain URL exits non-zero' );
	like( $output, qr/A file path in the archive needs an archive URL/,
		'and says why' );
}

# The architecture aliases of Linux and Darwin map to the
# release-asset spelling. A name with no alias passes through.
{
	my $dir =
	    fixture( 'Darwin', "runtime bin x https://e.org/{os}_{arch}\n" );

	my ( undef, $output ) =
	    run_in( $dir, '--os Darwin --arch aarch64 --dry-run runtime' );
	like(
		$output,
		qr{https://e\.org/darwin_arm64},
		'aarch64 maps to arm64'
	);

	( undef, $output ) =
	    run_in( $dir, '--os Darwin --arch arm64 --dry-run runtime' );
	like( $output, qr{https://e\.org/darwin_arm64},
		'arm64 passes through' );
}

# Binaries install last: after the packages and the CPAN modules.
{
	delete local $ENV{PERL_LOCAL_LIB_ROOT};

	my $manifest =
	      "runtime pkg alpha\n"
	    . "runtime cpan Foo::Bar\n"
	    . "runtime bin scw https://example.org/dl/scw-cli\n";
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', $manifest ),
		'--os OpenBSD --dry-run runtime'
	);
	is( $exit, 0, 'a mixed manifest with a bin line parses' );
	like(
		$output,
		qr{pkg_add alpha.*cpanm --notest Foo::Bar.*\.local/bin/scw}s,
		'binaries install after packages and CPAN modules'
	);
}

# A bin line without a URL is a format error, in every environment.
{
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', "runtime bin scw\n" ),
		'--os OpenBSD --dry-run runtime'
	);
	isnt( $exit, 0, 'a bin line without a URL exits non-zero' );
	like( $output, qr/Invalid format/, 'and reports the bad line' );
	like(
		$output,
		qr/<environment> bin <name> <url> \[<file-in-archive>\]/,
		'and the expected shape'
	);

	( $exit, $output ) = run_in(
		fixture( 'OpenBSD', "runtime pkg alpha\ndevelop bin scw\n" ),
		'--os OpenBSD --dry-run runtime' );
	isnt( $exit, 0,
		'a bad bin line in an unselected environment still fails' );
}

# A malformed line in another environment still fails: the shell
# version filtered before it validated. Thus the bad line stayed
# hidden until someone ran that tier.
{
	my ( $exit, $output ) = run_in(
		fixture( 'OpenBSD', "runtime pkg alpha\ndevelop deb gamma\n" ),
		'--os OpenBSD --dry-run runtime'
	);
	isnt( $exit, 0, 'a bad line in an unselected environment still fails' );
}

# A missing manifest is not an error. Most platforms have none.
{
	my ( $exit, $output ) =
	    run_in( tempdir( CLEANUP => 1 ),
		'--os Nosuchos --dry-run runtime' );
	is( $exit, 0, 'a missing manifest exits 0' );
	like( $output, qr/No dependencies for Nosuchos/, 'and says so' );
}

# The real manifests parse. Thus a typo in one fails here, not on
# somebody's laptop halfway through an install.
for my $os (qw(OpenBSD Linux Darwin)) {
	for my $env (qw(runtime test develop)) {
		my ( $exit, $output ) =
		    run_in( $root, "--os $os --dry-run $env" );
		is( $exit, 0, "deps/$os.txt parses for $env" )
		    or diag($output);
	}
}

done_testing();
