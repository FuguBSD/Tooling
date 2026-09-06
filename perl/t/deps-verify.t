#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The download check of the canonical deps script (SYNC-DOWNLOAD, SYNC-SUMS,
# SYNC-KEYS, SYNC-ALIAS)
#
# A dry run cannot cover a tier that verifies bytes, so these tests
# run the real install path with no network. scripts/deps finds ftp
# as an executable sibling (SYNC-BOOTSTRAP-2), so each test copies
# the script into a temporary directory and writes a stub ftp beside
# it. The stub copies a fixture file, and it fails as wget fails when
# the fixture is absent.
#
# HOME points into the temporary tree, so no test writes to the real
# ~/.local/bin.

use v5.36;
use Test::More;
use Cwd            qw(getcwd);
use Digest::SHA    qw(sha256_hex);
use File::Basename qw(basename);
use File::Copy     qw(copy);
use File::Path     qw(make_path);
use File::Spec     ();
use File::Temp     qw(tempdir);
use FindBin        qw($RealBin);

my $script = "$RealBin/../../org/sync/scripts/deps";
ok( -x $script, 'the deps script is executable' );

# _signify():
#	The signify command of this machine, or undef.
sub _signify ()
{
	for my $name (qw(signify signify-openbsd)) {
		for my $dir ( split /:/, ( $ENV{PATH} // q{} ) ) {
			return $name if -x "$dir/$name";
		}
	}

	return;
}

# _write($path, $text):
#	Write one file, and make its directory first.
sub _write ( $path, $text )
{
	open my $fh, '>', $path or die "write $path: $!";
	print {$fh} $text;
	close $fh;

	return;
}

# _sandbox():
#	A directory that holds scripts/deps and a stub scripts/ftp.
#	The stub copies $FUGU_FIXTURE/<dir>/<name> when that file
#	exists, and $FUGU_FIXTURE/<name> after it. It exits 8 when
#	both are absent, as wget exits 8 on a server error.
#
#	The directory form matters for the signed-manifest probe. A
#	name-only stub answers every directory alike, so it would hide
#	a probe that still holds a placeholder.
sub _sandbox ()
{
	my $dir = tempdir( CLEANUP => 1 );
	make_path("$dir/scripts");
	copy( $script, "$dir/scripts/deps" ) or die "copy deps: $!";
	chmod 0755, "$dir/scripts/deps";

	_write( "$dir/scripts/ftp", <<'STUB' );
#!/bin/sh
name=${2##*/}
rest=${2%/*}
dir=${rest##*/}
if [ -f "$FUGU_FIXTURE/$dir/$name" ]; then
	cp "$FUGU_FIXTURE/$dir/$name" "$1"
	exit 0
fi
test -f "$FUGU_FIXTURE/$name" || exit 8
cp "$FUGU_FIXTURE/$name" "$1"
STUB
	chmod 0755, "$dir/scripts/ftp";

	return $dir;
}

# _run($sandbox, $repo, $fixture, $home, @args):
#	Run the sandboxed deps against $repo. The exit code and the
#	output.
sub _run ( $sandbox, $repo, $fixture, $home, @args )
{
	my $cwd = getcwd();
	chdir $repo or die "chdir $repo: $!";
	local $ENV{FUGU_FIXTURE} = $fixture;
	local $ENV{HOME}         = $home;
	my $out  = `$sandbox/scripts/deps @args 2>&1`;
	my $exit = $? >> 8;
	chdir $cwd or die "chdir $cwd: $!";

	return ( $exit, $out );
}

# _bsd($name, $text):
#	One BSD-format sha256 line for a body.
sub _bsd ( $name, $text )
{
	return "SHA256 ($name) = " . sha256_hex($text) . "\n";
}

# _case(%arg):
#	One prepared case: a fixture directory of served files, a repo
#	directory with deps/, a HOME, and a sandbox. Returns the four
#	paths.
sub _case (%arg)
{
	my $root = tempdir( CLEANUP => 1 );
	make_path( "$root/fixture", "$root/repo/deps", "$root/home" );

	for my $name ( keys %{ $arg{served} // {} } ) {
		make_path("$root/fixture/$1") if $name =~ m{\A(.+)/[^/]+\z};
		_write( "$root/fixture/$name", $arg{served}{$name} );
	}
	_write( "$root/repo/deps/Linux.txt",  $arg{manifest} );
	_write( "$root/repo/deps/SHA256.txt", $arg{digests} )
	    if defined $arg{digests};
	_write( "$root/repo/deps/KEYS.txt", $arg{keys} )
	    if defined $arg{keys};

	return ( _sandbox(), "$root/repo", "$root/fixture", "$root/home" );
}

my $TOOL = "#!/bin/sh\necho tool\n";
my $URL  = 'https://example.org/dl/tool_1.0_{os}_{arch}';

# A versioned URL with no placeholder. The signify tier serves an
# entry without a placeholder only (SYNC-ALIAS-5), so every signed
# case uses this one.
my $VURL = 'https://example.org/dl/tool_1.0';

# The consumer digest file keys on the URL, so a fixture names the
# resolved candidate. A signed manifest keeps its file name key.
my $URL_X64   = 'https://example.org/dl/tool_1.0_linux_x64';
my $URL_AMD64 = 'https://example.org/dl/tool_1.0_linux_amd64';
my $URL_TGZ   = 'https://example.org/dl/tool_1.0_linux_x64.tar.gz';

# The digest tier installs a file that matches its recorded digest.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_X64, $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'the digest tier installs a matching file' )
	    or diag($out);
	ok( -x "$case[3]/.local/bin/mytool", 'and the binary lands' );
}

# The alias table takes the recorded spelling. The machine word
# x86_64 gives amd64, x64 and x86_64, and only one is recorded.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_X64, $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( undef, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	like( $out, qr/tool_1\.0_linux_x64/, 'the recorded x64 name resolves' );
	unlike( $out, qr/tool_1\.0_linux_amd64/, 'and amd64 never downloads' );
}

# A file that does not match its digest stops the install, and the
# binary that is already there stays (SYNC-DOWNLOAD-2).
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_X64, $TOOL ),
		served => { 'tool_1.0_linux_x64' => "#!/bin/sh\necho evil\n" },
	);
	make_path("$case[3]/.local/bin");
	_write( "$case[3]/.local/bin/mytool", $TOOL );

	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a changed file stops the install' );
	like( $out, qr/does not match its recorded digest/, 'and says why' );

	open my $fh, '<', "$case[3]/.local/bin/mytool" or die $!;
	local $/ = undef;
	is( <$fh>, $TOOL, 'and the installed binary stays as it was' );
	close $fh;
}

# No recorded digest and no key: nothing installs without a check.
{
	my @case = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		served   => { tool => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'an entry with no check stops the install' );
	like( $out, qr/no key is\s+declared/, 'and names the empty key set' );
}

# A placeholder entry needs a recorded digest, because the digest
# file resolves the platform word (SYNC-ALIAS-5).
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a placeholder with no digest stops the install' );
	like( $out, qr/records no digest for/, 'and says why' );
}

# Two recorded candidates for one entry are ambiguous.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_X64, $TOOL ) . _bsd( $URL_AMD64, $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'two candidates stop the install' );
	like( $out, qr/records more than one candidate/, 'and names both' );
}

# An unknown environment word in a manifest line is an error. The
# line used to disappear, and the run then claimed success.
{
	my @case = _case( manifest => "toool pkg alpha\n" );
	my ( $exit, $out ) = _run( @case, '--os Linux --dry-run tool' );
	isnt( $exit, 0, 'an unknown environment word stops the run' );
	like( $out, qr/Unknown environment 'toool'/, 'and names the word' );
}

# --update-sums records the digest of the candidate that answers.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0' ) or diag($out);
	like( $out, qr{recorded \S*tool_1\.0_linux_x64}, 'and names the file' );

	open my $fh, '<', "$case[1]/deps/SHA256.txt" or die $!;
	local $/ = undef;
	is( <$fh>, _bsd( $URL_X64, $TOOL ), 'and writes the BSD line' );
	close $fh;
}

# The signify tier. Each test below needs signify(1).
SKIP: {
	my $signify = _signify();
	skip 'signify(1) is absent', 8 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";

	open my $fh, '<', "$keydir/k.pub" or die $!;
	my @line = <$fh>;
	close $fh;
	chomp( my $body = $line[1] );

	# _sign($dir, $text): a SHA256 manifest for one file, signed.
	my $sign = sub ( $dir, $name, $text ) {
		_write( "$dir/SHA256", _bsd( $name, $text ) );
		system $signify, '-S', '-s', "$keydir/k.sec", '-m',
		    "$dir/SHA256", '-x', "$dir/SHA256.sig";

		open my $in, '<', "$dir/SHA256.sig" or die $!;
		local $/ = undef;
		my $sig = <$in>;
		close $in;

		open $in, '<', "$dir/SHA256" or die $!;
		my $sums = <$in>;
		close $in;

		return ( $sums, $sig );
	};

	my $work = tempdir( CLEANUP => 1 );
	my ( $sums, $sig ) = $sign->( $work, 'tool', $TOOL );

	# The body form of a key verifies a signed manifest.
	{
		my @case = _case(
			manifest =>
			    "runtime bin mytool https://example.org/dl/tool\n",
			keys   => "testkey $body\n",
			served => {
				tool         => $TOOL,
				'SHA256'     => $sums,
				'SHA256.sig' => $sig,
			},
		);
		my ( $exit, $out ) =
		    _run( @case, '--os Linux --arch x86_64 runtime' );
		is( $exit, 0, 'the signify tier installs a signed file' )
		    or diag($out);
		like(
			$out,
			qr/Verified the manifest with the key testkey/,
			'and names the key that verified'
		);
		ok( -x "$case[3]/.local/bin/mytool", 'and the binary lands' );
	}

	# The URL form fetches the key and holds it to its digest.
	{
		open my $in, '<', "$keydir/k.pub" or die $!;
		local $/ = undef;
		my $pub = <$in>;
		close $in;

		my @case = _case(
			manifest =>
			    "runtime bin mytool https://example.org/dl/tool\n",
			keys => 'testkey https://example.org/k.pub '
			    . sha256_hex($pub) . "\n",
			served => {
				tool         => $TOOL,
				'k.pub'      => $pub,
				'SHA256'     => $sums,
				'SHA256.sig' => $sig,
			},
		);
		my ( $exit, $out ) =
		    _run( @case, '--os Linux --arch x86_64 runtime' );
		is( $exit, 0, 'the URL form of a key verifies' ) or diag($out);

		# The same key file, with a digest that does not match.
		my @bad = _case(
			manifest =>
			    "runtime bin mytool https://example.org/dl/tool\n",
			keys => 'testkey https://example.org/k.pub '
			    . ( '0' x 64 ) . "\n",
			served => {
				tool         => $TOOL,
				'k.pub'      => $pub,
				'SHA256'     => $sums,
				'SHA256.sig' => $sig,
			},
		);
		( $exit, $out ) =
		    _run( @bad, '--os Linux --arch x86_64 runtime' );
		isnt( $exit, 0, 'a key that fails its digest stops the run' );
		like( $out, qr/does not match its digest/, 'and says why' );
	}

	# A signature over another manifest does not verify.
	{
		my $other = tempdir( CLEANUP => 1 );
		my ( $other_sums, undef ) =
		    $sign->( $other, 'tool', "#!/bin/sh\necho other\n" );

		my @case = _case(
			manifest =>
			    "runtime bin mytool https://example.org/dl/tool\n",
			keys   => "testkey $body\n",
			served => {
				tool         => $TOOL,
				'SHA256'     => $other_sums,
				'SHA256.sig' => $sig,
			},
		);
		my ( $exit, $out ) =
		    _run( @case, '--os Linux --arch x86_64 runtime' );
		isnt( $exit, 0, 'a signature over other bytes stops the run' );
		like( $out, qr/no declared key verifies/, 'and says why' );
	}
}

# A key line of the wrong shape is an error.
{
	my @case = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => "testkey not-a-key-body\n",
		served   => { tool => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'a bad key body stops the run' );
	like( $out, qr/not a signify key body/, 'and says why' );

	my @four = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => "a b c d\n",
		served   => { tool => $TOOL },
	);
	( $exit, $out ) = _run( @four, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'a key line of four fields stops the run' );
	like( $out, qr/two or three fields/, 'and says the shape' );
}

# A malformed digest line is an error, and so is a duplicate name.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => "not a digest line\n",
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a malformed digest line stops the run' );
	like( $out, qr/not a sha256 line/, 'and says why' );

	my @dup = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_X64, $TOOL ) . _bsd( $URL_X64, $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	( $exit, $out ) = _run( @dup, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a duplicate digest URL stops the run' );
	like( $out, qr/duplicate URL/, 'and says why' );
}

# A tool entry takes the digest tier only, because the signify tier
# needs signify(1), which the tool environment installs (MK-DEPS-4).
{
	my @case = _case(
		manifest => "tool bin mytool https://example.org/dl/tool\n",
		served   => { tool => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a tool entry with no digest stops the run' );
	like( $out, qr/must not use the\s+signify tier/, 'and names the rule' );
}

# The tool rule covers a dist entry too, not the bin entries only.
{
	my @case = _case(
		manifest =>
		    "tool dist https://example.org/dl/Some-1.0.tar.gz\n",
		keys => "testkey https://example.org/k.pub "
		    . ( '0' x 64 ) . "\n",
		served => { 'Some-1.0.tar.gz' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a tool dist entry with no digest stops the run' );
	like( $out, qr/must not use the\s+signify tier/, 'and names the rule' );
}

# A key name becomes a file name, so it must hold no path. A repeated
# name must not shadow the trust order.
{
	my @case = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => "../../escaped https://example.org/k.pub "
		    . ( '0' x 64 ) . "\n",
		served => { tool => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'a key name with a path stops the run' );
	like( $out, qr/a key name holds/, 'and says the shape' );

	my $line = 'dup https://example.org/k.pub ' . ( '0' x 64 ) . "\n";
	my @dup  = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => $line . $line,
		served   => { tool => $TOOL },
	);
	( $exit, $out ) = _run( @dup, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'a duplicate key name stops the run' );
	like( $out, qr/duplicate key name/, 'and says why' );
}

# An entry with a placeholder is never a stable name: the resolution
# reads the digest file, so --update-sums must record one for it.
{
	my @case = _case(
		manifest =>
		    "tool bin mytool https://example.org/dl/t-{os}-{arch}\n",
		served => { 't-linux-amd64' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums records a placeholder entry' ) or diag($out);
	like( $out, qr{recorded \S*t-linux-amd64}, 'and names the file' );
	unlike(
		$out,
		qr/skipped the stable name/,
		'and calls it no stable name'
	);
}

# A command name and an archive path become file names, so neither
# may hold a path.
{
	my @case = _case(
		manifest => "tool bin ../../victim $URL\n",
		digests  => _bsd( $URL_X64, $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a command name with a path stops the run' );
	like( $out, qr/the command name/, 'and says the shape' );

	my @member = _case(
		manifest => "tool bin mytool $URL.tar.gz ../../../escape\n",
		digests  => _bsd( $URL_TGZ, $TOOL ),
		served   => { 'tool_1.0_linux_x64.tar.gz' => $TOOL },
	);
	( $exit, $out ) = _run( @member, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'an archive path with a parent segment stops the run' );
	like( $out, qr/no empty and no parent segment/, 'and says why' );
}

# --update-sums writes the pinned file, so it takes no dry run, and it
# leaves the file as it was when a download answers nothing.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --dry-run --update-sums' );
	isnt( $exit, 0, 'update-sums takes no dry run' );
	like( $out, qr/takes no --dry-run/, 'and says so' );

	my @miss = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( "https://e.org/dl/keep_me", $TOOL ),
		served   => {},
	);
	( $exit, $out ) =
	    _run( @miss, '--os Linux --arch x86_64 --update-sums' );
	isnt( $exit, 0, 'update-sums fails when nothing answers' );

	open my $fh, '<', "$miss[1]/deps/SHA256.txt" or die $!;
	local $/ = undef;
	is(
		<$fh>,
		_bsd( "https://e.org/dl/keep_me", $TOOL ),
		'and the pinned file stays as it was'
	);
	close $fh;
}

SKIP: {
	my $signify = _signify();
	skip q{signify(1) is absent}, 8 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";
	open my $in, '<', "$keydir/k.pub" or die $!;
	my @line = <$in>;
	close $in;
	chomp( my $body = $line[1] );

	my $work = tempdir( CLEANUP => 1 );
	_write( "$work/SHA256", _bsd( 'tool', $TOOL ) );
	system $signify, '-S', '-s', "$keydir/k.sec", '-m', "$work/SHA256",
	    '-x', "$work/SHA256.sig";
	open $in, '<', "$work/SHA256.sig" or die $!;
	local $/ = undef;
	my $sig = <$in>;
	close $in;
	open $in, '<', "$work/SHA256" or die $!;
	my $sums = <$in>;
	close $in;

	# A recorded digest would outrank the signature, so
	# --update-sums must leave a signed entry alone. The name here
	# holds a version, so the stable-name test does not fire and
	# the signature probe is what skips the entry.
	_write( "$work/vSHA256", _bsd( 'tool_1.0', $TOOL ) );
	system $signify, '-S', '-s', "$keydir/k.sec", '-m', "$work/vSHA256",
	    '-x', "$work/vSHA256.sig";
	open $in, '<', "$work/vSHA256" or die $!;
	my $vsums = <$in>;
	close $in;
	open $in, '<', "$work/vSHA256.sig" or die $!;
	my $vsig = <$in>;
	close $in;

	my @case = _case(
		manifest => "runtime bin mytool $VURL\n",
		keys     => "testkey $body\n",
		served   => {
			'tool_1.0'   => $TOOL,
			'SHA256'     => $vsums,
			'SHA256.sig' => $vsig,
		},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0 with a signed entry' ) or diag($out);
	like( $out, qr/skipped the signed entry/, 'and records no digest' );
	ok( !-s "$case[1]/deps/SHA256.txt", 'and writes an empty digest file' );

	# The tier test must not need signify(1): an absent command
	# must not turn a signed entry into a recorded digest.
	my @nosig = _case(
		manifest => "runtime bin mytool $VURL\n",
		keys     => "testkey $body\n",
		served   => {
			'tool_1.0'   => $TOOL,
			'SHA256'     => $vsums,
			'SHA256.sig' => $vsig,
		},
	);
	{
		# A PATH that holds the shell tools of the stub, and no
		# signify. The tier test must still skip the entry.
		my $bin = tempdir( CLEANUP => 1 );
		for my $tool (qw(cp rm sh perl)) {
			my ($real) = grep { -x $_ }
			    map { "$_/$tool" } qw(/bin /usr/bin /usr/local/bin);
			symlink $real, "$bin/$tool" if defined $real;
		}
		local $ENV{PATH} = $bin;
		( $exit, $out ) =
		    _run( @nosig, '--os Linux --arch x86_64 --update-sums' );
	}
	like(
		$out,
		qr/skipped the signed entry/,
		'the tier test runs without signify'
	);

	# A stable name never reaches the probe: the manifest decides,
	# so a server that withholds its signature changes nothing.
	my @stable = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => "testkey $body\n",
		served   => { tool => $TOOL },
	);
	( $exit, $out ) =
	    _run( @stable, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0 with a stable name' ) or diag($out);
	like( $out, qr/skipped the stable name/, 'and records no digest' );
	ok( !-s "$stable[1]/deps/SHA256.txt", 'and pins nothing' );

	# A pinned key that fails its digest must be reported, even
	# when a later key verifies.
	my @mask = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => 'pinned https://example.org/k.pub '
		    . ( '0' x 64 )
		    . "\ngood $body\n",
		served => {
			tool         => $TOOL,
			'k.pub'      => "untrusted comment: x\n$body\n",
			'SHA256'     => $sums,
			'SHA256.sig' => $sig,
		},
	);
	( $exit, $out ) = _run( @mask, '--os Linux --arch x86_64 runtime' );
	like(
		$out,
		qr/the key pinned did not load/,
		'a key that fails its digest is reported'
	);
}

# --force repairs a digest that no longer matches the release, and it
# pins a stable name that the operator chooses to pin.
{
	my @stale = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => "SHA256 ($URL_X64) = " . ( '0' x 64 ) . "\n",
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @stale, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a stale digest stops the install' );

	( $exit, $out ) =
	    _run( @stale, '--os Linux --arch x86_64 --update-sums' );
	like( $out, qr/^kept /m, 'update-sums keeps it without --force' );

	( $exit, $out ) =
	    _run( @stale, '--os Linux --arch x86_64 --update-sums --force' );
	is( $exit, 0, 'update-sums --force exits 0' ) or diag($out);
	like(
		$out,
		qr{recorded \S*tool_1\.0_linux_x64},
		'and rewrites the line'
	);

	( $exit, $out ) = _run( @stale, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'and the install then passes' ) or diag($out);

	my @stable = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		served   => { tool => $TOOL },
	);
	( $exit, $out ) =
	    _run( @stable, '--os Linux --arch x86_64 --update-sums --force' );
	is( $exit, 0, 'update-sums --force exits 0 for a stable name' )
	    or diag($out);
	like( $out, qr{recorded \S*/tool}, 'and pins it' );
}

# An archive path must not read as a command option: tar and unzip
# take one that runs a command.
{
	my @case = _case(
		manifest => "tool bin mytool $URL.tar.gz --to-command=id\n",
		digests  => _bsd( $URL_TGZ, $TOOL ),
		served   => { 'tool_1.0_linux_x64.tar.gz' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0,
		'an archive path that starts with a dash stops the run' );
	like( $out, qr/must not start with a dash/, 'and says why' );
	unlike( $out, qr/uid=/, 'and runs no command' );
}

# The digest file keys on the URL, so each candidate of an entry
# carries its own line. A placeholder that only moves the directory
# therefore resolves like any other.
{
	my @case = _case(
		manifest =>
		    "tool bin mytool https://example.org/dl/{arch}/t_1.0\n",
		served => { 't_1.0' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'a placeholder in the directory records a digest' )
	    or diag($out);
	like( $out, qr{recorded \S*/amd64/t_1\.0}, 'and names the URL' );

	( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'and the install resolves it' ) or diag($out);
}

# A digest file of an older key stops the install, and the message
# names the command that rewrites it (SYNC-DOWNLOAD-18). An entry
# without a placeholder must stop as well, so no entry loses its pin
# without a word.
{
	for my $entry ( "tool bin mytool $URL", "runtime bin mytool $VURL" ) {
		my @case = _case(
			manifest => "$entry\n",
			digests  => _bsd( 'tool_1.0_linux_x64', $TOOL )
			    . _bsd( 'tool_1.0', $TOOL ),
			served => {
				'tool_1.0_linux_x64' => $TOOL,
				'tool_1.0'           => $TOOL,
			},
		);
		my ($env) = $entry =~ /\A(\w+)/;
		my ( $exit, $out ) =
		    _run( @case, "--os Linux --arch x86_64 $env" );
		isnt( $exit, 0, "a file-name key stops the $env install" );
		like(
			$out,
			qr/keys on the file name/,
			'and the message names the key'
		);
		like( $out, qr/--update-sums/, 'and names the repair' );
	}

	# The repair drops each file-name line and records the URL, so
	# the file holds no stale key afterwards.
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( 'tool_1.0_linux_x64', $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums repairs a file-name key' ) or diag($out);
	like(
		$out,
		qr/dropped the file-name key tool_1\.0_linux_x64/,
		'and says which line went'
	);

	open my $fh, '<', "$case[1]/deps/SHA256.txt" or die $!;
	local $/ = undef;
	my $written = <$fh>;
	close $fh;
	is( $written, _bsd( $URL_X64, $TOOL ), 'and leaves the URL key only' );

	( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'and the install then runs' ) or diag($out);
}

# One run reads one manifest, so a file-name key that the run cannot
# replace must stay. A blanket drop would unpin every other platform
# (SYNC-DOWNLOAD-19).
{
	my $dar  = 'https://e.org/dl/t_1.0_darwin.tar.gz';
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( 'tool_1.0_linux_x64', $TOOL )
		    . _bsd( 't_1.0_darwin.tar.gz', $TOOL ),
		served => { 'tool_1.0_linux_x64' => $TOOL },
	);
	_write( "$case[1]/deps/Darwin.txt", "tool bin mytool $dar t\n" );

	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'a Linux run repairs the Linux key' ) or diag($out);
	like(
		$out,
		qr/dropped the file-name key tool_1\.0_linux_x64/,
		'and drops the key that it replaces'
	);
	unlike(
		$out,
		qr/dropped the file-name key t_1\.0_darwin/,
		'and keeps the key of the other manifest'
	);

	open my $fh, '<', "$case[1]/deps/SHA256.txt" or die $!;
	local $/ = undef;
	my $written = <$fh>;
	close $fh;
	like( $written, qr/\Q$URL_X64\E/, 'the file holds the new URL' );
	like(
		$written,
		qr/\(t_1\.0_darwin\.tar\.gz\)/,
		'and it still holds the Darwin pin'
	);
}

# An entry that no tier covers must stop the run before any binary
# reaches the install directory (SYNC-DOWNLOAD-2).
{
	my @case = _case(
		manifest => "tool bin one $VURL\n"
		    . "tool bin two https://e.org/dl/other_1.0\n",
		digests => _bsd( $VURL, $TOOL ),
		served  => { 'tool_1.0' => $TOOL, 'other_1.0' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'an entry with no tier stops the run' );
	like( $out, qr/must not use the signify tier/, 'and says why' );
	ok(
		!-e "$case[3]/.local/bin/one",
		'and the earlier binary never lands'
	);
}

# Each candidate downloads to its own directory, so one path never
# holds the bytes of the last download (SYNC-SUMS-10). A placeholder
# in the directory gives every candidate one file name, which is the
# case that a shared path would break.
{
	my $amd64 = "#!/bin/sh\necho amd64\n";
	my @case  = _case(
		manifest =>
		    "tool bin mytool https://example.org/dl/{arch}/t_1.0\n",
		served => {
			'amd64/t_1.0' => $amd64,
			'x64/t_1.0'   => $TOOL,
		},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0 for two answers' ) or diag($out);
	like(
		$out,
		qr/more than one candidate answers/,
		'and reports the second answer'
	);

	# amd64 comes first in the alias order, so the recorded digest
	# is of the amd64 bytes and not of the x64 bytes.
	open my $fh, '<', "$case[1]/deps/SHA256.txt" or die $!;
	local $/ = undef;
	my $written = <$fh>;
	close $fh;
	is(
		$written,
		_bsd( 'https://example.org/dl/amd64/t_1.0', $amd64 ),
		'and each candidate keeps its own bytes'
	);
}

# A recorded mismatch names the URL, because that is the line of
# deps/SHA256.txt to repair.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_X64, "other\n" ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a recorded mismatch stops the install' );
	like(
		$out,
		qr{\Qdeps: $URL_X64\E does not match},
		'and the message names the URL'
	);
}

# The archive path takes the alias words, so its shape gets a check
# after the expansion as well (SYNC-DOWNLOAD-11).
{
	my $url  = 'https://e.org/dl/t_1.0_{arch}.tar.gz';
	my @case = _case(
		manifest => "tool bin mytool $url {arch}/bin/t\n",
		digests  => _bsd( 'https://e.org/dl/t_1.0_-x.tar.gz', $TOOL ),
		served   => { 't_1.0_-x.tar.gz' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch -x tool' );
	isnt( $exit, 0,
		'an expanded archive path that starts with a dash stops the run'
	);
	like( $out, qr/must not start with a dash/, 'and says why' );
}

# The signed-manifest probe needs a resolved directory. A placeholder
# in the directory gives each candidate its own base. A probe that
# still held the placeholder would find no manifest, and the entry
# would then take a digest of its own download.
{
	my @case = _case(
		manifest =>
		    "runtime bin mytool https://example.org/dl/{arch}/t_1.0\n",
		served => {
			't_1.0'        => $TOOL,
			'amd64/SHA256' => _bsd( 't_1.0', $TOOL ),
		},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	isnt( $exit, 0, 'a placeholder entry with no digest fails the run' );
	like(
		$out,
		qr{nothing verifies the signed manifest beside},
		'and the probe reads the resolved directory'
	);
	ok( !-e "$case[1]/deps/SHA256.txt", 'and the entry pins nothing' );

	# The entry can never install without a digest, so the run
	# must not report success (SYNC-SUMS-16).
	( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'and the install cannot resolve it' );

	# --force overrides the signed-manifest test (SYNC-SUMS-9).
	( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums --force' );
	is( $exit, 0, 'and --force pins the bytes that the server serves' )
	    or diag($out);
	like( $out, qr{recorded \S*/amd64/t_1\.0}, 'and names the URL' );

	( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	is( $exit, 0, 'and the install then resolves it' ) or diag($out);
}

# An alias word expands into the URL, and a candidate becomes a key of
# the digest file. A word with a parenthesis would write a line that no
# later run can read.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		served   => {},
	);
	my ( $exit, $out ) =
	    _run( @case, q{--os Linux --arch 'a)b' --update-sums} );
	isnt( $exit, 0, 'a parenthesis in an alias word stops the run' );
	like( $out, qr/no parenthesis/, 'and says why' );

	# The install path never writes the digest file, so a bad alias
	# word simply matches no recorded line.
	( $exit, $out ) = _run( @case, q{--os Linux --arch 'a)b' tool} );
	isnt( $exit, 0, 'and the install stops as well' );
	like( $out, qr/records no digest/, 'because no line names it' );
}

# A file name with a parenthesis would break the digest file format.
{
	my @case = _case(
		manifest =>
		    "tool bin mytool https://example.org/dl/app(1).run\n",
		served => {},
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'a parenthesis in the file name stops the run' );
	like( $out, qr/no parenthesis/, 'and says why' );
}

# A pkg name and a cpan name reach a package manager, so neither may
# read as an option, and neither may name a download.
{
	my @case = _case(
		manifest =>
		    "runtime cpan https://evil.example/Evil-1.0.tar.gz\n",
		served => {},
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --dry-run runtime' );
	isnt( $exit, 0, 'a cpan name that is a URL stops the run' );
	like( $out, qr/must not be a URL/, 'and says why' );

	my @opt = _case(
		manifest => "runtime pkg --unsigned\n",
		served   => {},
	);
	( $exit, $out ) = _run( @opt, '--os Linux --dry-run runtime' );
	isnt( $exit, 0, 'a pkg name that reads as an option stops the run' );
	like( $out, qr/must not start with a dash/, 'and says why' );
}

# Two entries of two manifests can take one file name, and the URL
# key keeps each on its own line. Neither entry hides the other.
{
	my @case = _case(
		manifest => "tool bin appl https://good.org/rel/app-1.run\n",
		digests  => _bsd( 'https://good.org/rel/app-1.run', $TOOL ),
		served   => { 'app-1.run' => $TOOL },
	);
	_write( "$case[1]/deps/Darwin.txt",
		"tool bin appd https://mirror.org/x/app-1.run\n" );
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'two manifests with one file name install' )
	    or diag($out);
	ok( -x "$case[3]/.local/bin/appl", 'and the binary lands' );
}

# A run that records nothing leaves no digest file behind.
{
	my @case = _case(
		manifest =>
"runtime dist https://example.org/releases/latest/download/F.tar.gz\n",
		served => {},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0 when every entry is skipped' );
	like( $out, qr/recorded nothing/, 'and says it recorded nothing' );
	ok( !-e "$case[1]/deps/SHA256.txt", 'and writes no digest file' );
}

# The real scripts/ftp must exit non-zero and leave no file after a
# failed fetch (SYNC-DOWNLOAD-9). A refused connection on the loopback
# needs no network.
{
	my $dir = tempdir( CLEANUP => 1 );
	my $out = "$dir/out";
	my $ftp = "$RealBin/../../org/sync/scripts/ftp";

	# The fetcher reports its own failure, and that report reads
	# as a failure of the suite. Keep it out of the run.
	my $exit;
	{
		open my $keep_out, '>&', \*STDOUT            or die $!;
		open my $keep_err, '>&', \*STDERR            or die $!;
		open STDOUT,       '>',  File::Spec->devnull or die $!;
		open STDERR,       '>&', \*STDOUT            or die $!;
		$exit = system( $ftp, $out, 'http://127.0.0.1:1/nothing' ) >> 8;
		open STDOUT, '>&', $keep_out or die $!;
		open STDERR, '>&', $keep_err or die $!;
	}
	isnt( $exit, 0, 'ftp exits non-zero on a failed fetch' );
	ok( !-e $out, 'and leaves no file' );
}

SKIP: {
	my $signify = _signify();
	skip q{signify(1) is absent}, 4 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";
	open my $in, '<', "$keydir/k.pub" or die $!;
	my @line = <$in>;
	close $in;
	chomp( my $body = $line[1] );

	my $work = tempdir( CLEANUP => 1 );
	_write( "$work/SHA256", _bsd( 'other-file', $TOOL ) );
	system $signify, '-S', '-s', "$keydir/k.sec", '-m', "$work/SHA256",
	    '-x', "$work/SHA256.sig";
	open $in, '<', "$work/SHA256" or die $!;
	local $/ = undef;
	my $sums = <$in>;
	close $in;
	open $in, '<', "$work/SHA256.sig" or die $!;
	my $sig = <$in>;
	close $in;

	# The signature verifies, and the manifest names another file.
	my @case = _case(
		manifest => "runtime bin mytool https://example.org/dl/tool\n",
		keys     => "testkey $body\n",
		served   => {
			tool         => $TOOL,
			'SHA256'     => $sums,
			'SHA256.sig' => $sig,
		},
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'a signed manifest without the file stops the run' );
	like( $out, qr/does not name/, 'and says why' );

	# The server answers the manifest and withholds the signature.
	# --update-sums must not turn that into a recorded digest.
	my @withheld = _case(
		manifest => "runtime bin mytool $VURL\n",
		keys     => "testkey $body\n",
		served   => {
			'tool_1.0' => $TOOL,
			'SHA256'   => $sums,
		},
	);
	( $exit, $out ) =
	    _run( @withheld, '--os Linux --arch x86_64 --update-sums' );
	like(
		$out,
		qr/skipped the signed entry/,
		'a withheld signature keeps the entry on the signify tier'
	);
	ok( !-e "$withheld[1]/deps/SHA256.txt", 'and pins nothing' );
}

# The digest file keys on the URL, so a digest that one entry records
# never serves its neighbour. Two entries that end in one file name
# keep their own tier. The recorded entry takes the digest tier, and
# the other one still asks for a signature.
{
	my @case = _case(
		manifest => "runtime bin one https://a.example/stable/tool-2\n"
		    . "runtime bin two https://b.example/rel/tool-2\n",
		digests => _bsd( 'https://b.example/rel/tool-2', $TOOL ),
		served  => { 'tool-2' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'the neighbour digest does not serve the entry' );
	like(
		$out,
		qr{https://a\.example/stable/tool-2 has no recorded digest},
		'and the run names the entry that no tier covers'
	);
}

# --force replaces the line of one entry, so a sibling candidate name
# of the same entry goes with it.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n",
		digests  => _bsd( $URL_AMD64, $TOOL ),
		served   => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums --force' );
	is( $exit, 0, 'update-sums --force exits 0' ) or diag($out);
	like(
		$out,
		qr{removed \S*tool_1\.0_linux_amd64},
		'and drops the sibling'
	);

	( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'and the install is not ambiguous' ) or diag($out);
}

SKIP: {
	my $signify = _signify();
	skip q{signify(1) is absent}, 2 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";
	open my $in, '<', "$keydir/k.pub" or die $!;
	my @line = <$in>;
	close $in;
	chomp( my $body = $line[1] );

	my $work = tempdir( CLEANUP => 1 );
	_write( "$work/SHA256", _bsd( 'tool_1.0', $TOOL ) );
	system $signify, '-S', '-s', "$keydir/k.sec", '-m', "$work/SHA256",
	    '-x', "$work/SHA256.sig";
	open $in, '<', "$work/SHA256" or die $!;
	local $/ = undef;
	my $sums = <$in>;
	close $in;
	open $in, '<', "$work/SHA256.sig" or die $!;
	my $sig = <$in>;
	close $in;

	# An upstream that publishes a manifest the operator cannot
	# verify would otherwise leave the entry unpinnable.
	my @case = _case(
		manifest => "runtime bin mytool $VURL\n",
		keys     => "testkey $body\n",
		served   => {
			'tool_1.0'   => $TOOL,
			'SHA256'     => $sums,
			'SHA256.sig' => $sig,
		},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums --force' );
	like(
		$out,
		qr/--force pins a URL that a signed/,
		'--force warns before it pins a signed URL'
	);
	like( $out, qr{recorded \S*tool_1\.0}, 'and records the digest' );
}

SKIP: {
	my $signify = _signify();
	skip q{signify(1) is absent}, 6 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";
	open my $in, '<', "$keydir/k.pub" or die $!;
	my @line = <$in>;
	close $in;
	chomp( my $body = $line[1] );

	# _sign($text): the manifest and its signature, as two strings.
	my $work = tempdir( CLEANUP => 1 );
	my $nth  = 0;
	my $sign = sub ($text) {
		my $base = "$work/m" . $nth++;
		_write( $base, $text );
		system $signify, '-S', '-s', "$keydir/k.sec", '-m', $base,
		    '-x', "$base.sig";
		local $/ = undef;
		open my $fh, '<', $base or die $!;
		my $sums = <$fh>;
		close $fh;
		open $fh, '<', "$base.sig" or die $!;
		my $sig = <$fh>;
		close $fh;

		return ( $sums, $sig );
	};

	my ( $sums, $sig ) = $sign->( _bsd( 'tool', $TOOL ) );

	# The candidate must sit under the directory that answered.
	# amd64 comes first in the alias order, and only the x64
	# directory holds a manifest, so the run must take the x64
	# candidate and not the amd64 one.
	my @case = _case(
		manifest =>
		    "runtime bin mytool https://example.org/dl/{arch}/tool\n",
		keys   => "testkey $body\n",
		served => {
			'x64/SHA256'     => $sums,
			'x64/SHA256.sig' => $sig,
		},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'a signed manifest of one directory records a digest' )
	    or diag($out);
	like(
		$out,
		qr{recorded \S*/x64/tool from the signed manifest},
		'and the candidate sits under the directory that answered'
	);
	unlike( $out, qr{/amd64/tool}, 'and no other directory takes it' );

	# A verified manifest that names no candidate must not hide a
	# later directory that holds the release. amd64 comes first in
	# the alias order, and it answers with a manifest of another
	# file. The x64 directory holds the release.
	my ( $other, $other_sig ) = $sign->( _bsd( 'other-file', $TOOL ) );
	my @later = _case(
		manifest =>
		    "runtime bin mytool https://example.org/dl/{arch}/tool\n",
		keys   => "testkey $body\n",
		served => {
			'amd64/SHA256'     => $other,
			'amd64/SHA256.sig' => $other_sig,
			'x64/SHA256'       => $sums,
			'x64/SHA256.sig'   => $sig,
		},
	);
	( $exit, $out ) =
	    _run( @later, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'a manifest that names no candidate stops no later one' )
	    or diag($out);
	like(
		$out,
		qr{recorded \S*/x64/tool from the signed manifest},
		'and the probe reaches the directory of the release'
	);
	unlike( $out, qr/names no candidate/, 'and reports no dead end' );
}

# A bad command name or archive path fails in every environment, not
# only in the one that the run selects.
{
	my @case = _case(
		manifest => "tool pkg alpha\n"
		    . "develop bin ../../evil https://e.org/dl/x_1.0\n",
		served => {},
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --dry-run tool' );
	isnt( $exit, 0, 'a bad name of another environment stops the run' );
	like( $out, qr/the command name/, 'and says the shape' );
}

# --force belongs to --update-sums.
{
	my @case = _case( manifest => "tool pkg alpha\n", served => {} );
	my ( $exit, $out ) = _run( @case, '--os Linux --dry-run --force tool' );
	isnt( $exit, 0, 'an install run rejects --force' );
	like( $out, qr/--force belongs to --update-sums/, 'and says why' );
}

# A run that records nothing usable must not print a recorded line.
{
	my @case = _case(
		manifest => "tool bin mytool $URL\n"
		    . "tool bin ghost https://e.org/dl/ghost_1.0\n",
		served => { 'tool_1.0_linux_x64' => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	isnt( $exit, 0, 'a missed download fails the run' );
	unlike( $out, qr/^recorded /m, 'and prints no recorded line' );
	like( $out, qr/check the URL of each entry/, 'and names a next step' );
	ok( !-e "$case[1]/deps/SHA256.txt", 'and writes no digest file' );
}

# The digest-mismatch message names the repair of its own tier.
SKIP: {
	my $signify = _signify();
	skip q{signify(1) is absent}, 2 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";
	open my $in, '<', "$keydir/k.pub" or die $!;
	my @line = <$in>;
	close $in;
	chomp( my $body = $line[1] );

	my $work = tempdir( CLEANUP => 1 );
	_write( "$work/SHA256", _bsd( 'tool_1.0', $TOOL ) );
	system $signify, '-S', '-s', "$keydir/k.sec", '-m', "$work/SHA256",
	    '-x', "$work/SHA256.sig";
	open $in, '<', "$work/SHA256" or die $!;
	local $/ = undef;
	my $sums = <$in>;
	close $in;
	open $in, '<', "$work/SHA256.sig" or die $!;
	my $sig = <$in>;
	close $in;

	# The signature verifies, and the served bytes disagree.
	my @case = _case(
		manifest => "runtime bin mytool $VURL\n",
		keys     => "testkey $body\n",
		served   => {
			'tool_1.0'   => "#!/bin/sh\necho other\n",
			'SHA256'     => $sums,
			'SHA256.sig' => $sig,
		},
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'a served file that disagrees stops the run' );
	like(
		$out,
		qr/report it upstream/,
		'and the message names the repair of the signify tier'
	);
}

# A version in the directory part makes the name a versioned one.
{
	my @case = _case(
		manifest =>
		    "tool bin mytool https://e.org/release/v1.31.0/bin/tool\n",
		served => { tool => $TOOL },
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0 for a versioned path' )
	    or diag($out);
	like( $out, qr{recorded \S*/tool}, 'and records it' );
	unlike(
		$out,
		qr/skipped the stable name/,
		'and calls it no stable name'
	);
}

# Two entries of one manifest can end in one file name, and the URL
# key gives each its own line. Both install.
{
	my @case = _case(
		manifest => "tool bin one https://a.example/x/app-1.run\n"
		    . "tool bin two https://b.example/y/app-1.run\n",
		digests => _bsd( 'https://a.example/x/app-1.run', $TOOL )
		    . _bsd( 'https://b.example/y/app-1.run', $TOOL ),
		served => { 'app-1.run' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	is( $exit, 0, 'two entries with one file name install' ) or diag($out);
	ok( -x "$case[3]/.local/bin/one", 'and the first command lands' );
	ok( -x "$case[3]/.local/bin/two", 'and the second lands' );
}

SKIP: {
	my $signify = _signify();
	skip q{signify(1) is absent}, 8 unless defined $signify;

	my $keydir = tempdir( CLEANUP => 1 );
	system $signify, '-G', '-n', '-c', 'test', '-p', "$keydir/k.pub",
	    '-s', "$keydir/k.sec";
	open my $in, '<', "$keydir/k.pub" or die $!;
	my @line = <$in>;
	close $in;
	chomp( my $body = $line[1] );

	my $work = tempdir( CLEANUP => 1 );
	_write( "$work/SHA256", _bsd( 'tool_1.0_linux_x64', $TOOL ) );
	system $signify, '-S', '-s', "$keydir/k.sec", '-m', "$work/SHA256",
	    '-x', "$work/SHA256.sig";
	open $in, '<', "$work/SHA256" or die $!;
	local $/ = undef;
	my $sums = <$in>;
	close $in;
	open $in, '<', "$work/SHA256.sig" or die $!;
	my $sig = <$in>;
	close $in;

	# A placeholder entry needs a recorded digest, and a signed
	# manifest is where that digest comes from. A digest that the
	# download supplies would ignore the signature.
	my $evil = "#!/bin/sh\necho PWNED\n";
	my @case = _case(
		manifest => "runtime bin mytool $URL\n",
		keys     => "testkey $body\n",
		served   => {
			'tool_1.0_linux_x64' => $evil,
			'SHA256'             => $sums,
			'SHA256.sig'         => $sig,
		},
	);
	my ( $exit, $out ) =
	    _run( @case, '--os Linux --arch x86_64 --update-sums' );
	is( $exit, 0, 'update-sums exits 0 for a signed placeholder entry' )
	    or diag($out);
	like(
		$out,
		qr/from the signed manifest/,
		'and takes the digest from the signature'
	);

	open my $fh, '<', "$case[1]/deps/SHA256.txt" or die $!;
	my $written = <$fh>;
	close $fh;
	is(
		$written,
		_bsd( $URL_X64, $TOOL ),
		'and records the signed digest, not the served bytes'
	);

	# --force replaces the line of one entry, so a sibling
	# candidate goes with it on this path as well (SYNC-SUMS-8).
	my @sibling = _case(
		manifest => "runtime bin mytool $URL\n",
		keys     => "testkey $body\n",
		digests  => _bsd( $URL_AMD64, $TOOL ),
		served   => {
			'tool_1.0_linux_x64' => $evil,
			'SHA256'             => $sums,
			'SHA256.sig'         => $sig,
		},
	);
	( $exit, $out ) =
	    _run( @sibling, '--os Linux --arch x86_64 --update-sums --force' );
	is( $exit, 0, 'update-sums --force exits 0 on the signed path' )
	    or diag($out);
	like(
		$out,
		qr{removed \S*tool_1\.0_linux_amd64},
		'and drops the sibling candidate'
	);

	( $exit, $out ) = _run( @sibling, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'and the served bytes still fail the signed digest' );
	unlike(
		$out,
		qr/more than one candidate/,
		'so the install is not ambiguous'
	);

	( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 runtime' );
	isnt( $exit, 0, 'so the tampered download then stops the install' );
}

# Each placeholder of the archive path must also sit in the URL
# (SYNC-ALIAS-6). The digest file names the URL, and not the path
# inside the archive. A word that only the archive path holds has
# nothing to select it.
{
	my @case = _case(
		manifest => "tool bin mytool https://e.org/dl/t_1.0.tar.gz "
		    . "t_1.0_{arch}/bin/t\n",
		digests => _bsd( "https://e.org/dl/t_1.0.tar.gz", $TOOL ),
		served  => { 't_1.0.tar.gz' => $TOOL },
	);
	my ( $exit, $out ) = _run( @case, '--os Linux --arch x86_64 tool' );
	isnt( $exit, 0, 'an archive path placeholder needs one in the URL' );
	like( $out, qr/the archive path holds \{arch\}/, 'and says why' );
}

done_testing();
