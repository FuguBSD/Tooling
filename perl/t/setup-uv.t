#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for python/actions/setup-uv, per the workflows specification
#
# The cache key decides when CI rebuilds the virtual environment. A
# key that stops covering an input restores a stale environment, and
# a key that composes wrong rebuilds and re-caches on every run. The
# test reads the action as text, and runs the key shell with stand-in
# values, exactly as setup-perl.t does for the CPAN tree.

use v5.36;
use Test::More;
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);

my $root   = "$RealBin/../..";
my $action = "$root/python/actions/setup-uv/action.yml";

# The paths the cache key hashes (WFL-UV-2): the lockfile, the
# interpreter pin, and the project manifest. The uv release goes into
# the prefix, not into the hash.
my @HASHED = ( 'uv.lock', '.python-version', 'pyproject.toml' );

# _slurp($path):
#	Whole file as text, or undef with a failed assertion.
sub _slurp ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return;
	};
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

# _run_block($yml, $step_name):
#	The `run: |` script of the named step, dedented to column zero
#	so that a shell can run it. Undef when the step or its block is
#	not there.
sub _run_block ( $yml, $name )
{
	my @lines = split /\n/, $yml;
	my ( $seen, $indent, @block );

	for my $i ( 0 .. $#lines ) {
		$seen = 1 if $lines[$i] =~ /^\s+-\s+name:\s*\Q$name\E\s*$/;
		next unless $seen;

		# A later step begins. The block is over.
		last if @block && $lines[$i] =~ /^\s+-\s+name:/;

		if ( !defined $indent ) {
			next unless $lines[$i] =~ /^(\s+)run:\s*\|\s*$/;
			$indent = length($1) + 2;
			next;
		}

		last if length $lines[$i] && $lines[$i] !~ /^ {$indent}/;

		# A blank line inside the block is shorter than the indent
		# and carries nothing to dedent
		push @block,
		    length( $lines[$i] ) > $indent
		    ? substr( $lines[$i], $indent )
		    : '';
	}

	return if !@block;
	return join( "\n", @block ) . "\n";
}

my $yml = _slurp($action);
plan skip_all => 'no setup-uv action' unless defined $yml;

subtest 'the action takes one version input' => sub {
	like( $yml, qr/^\s+version:$/m, 'declares a version input' );
	like(
		$yml,
		qr/^\s+default:\s*"?\d+\.\d+\.\d+"?\s*$/m,
		'defaults to a pinned release'
	);
	like( $yml, qr/is not a release number/,
		'rejects a malformed version' );

	# A pinned release tarball, not an action (WFL-UV-1). The
	# third-party sweep of setup-perl.t covers the uses: lines.
	like(
		$yml,
		qr{releases/download/\$\{UV_VERSION\}},
		'installs the pinned release tarball'
	);
};

subtest 'the environment is synced on a hit and on a miss' => sub {

	# --locked, per WFL-UV-1: a bare sync would rewrite a stale
	# uv.lock in the workspace, and every lockfile gate after the
	# action would then pass on drift it can no longer see.
	like(
		$yml,
		qr/^\s+run:\s*uv sync --locked\s*$/m,
		'the action runs uv sync --locked'
	);

	# The one conditional step is the save. The sync itself carries
	# no condition, so a restored environment is always reconciled.
	my @ifs = $yml =~ /^\s+if:\s*(.*)$/mg;
	is( scalar @ifs, 1, 'one conditional step' );
	like(
		$ifs[0],
		qr/steps\.restore\.outputs\.cache-hit\s*!=\s*'true'/,
		'and it guards the save'
	);
};

subtest 'the cache key covers what decides the environment' => sub {

	# One computed key, read twice. actions/cache/save rejects a
	# write to an existing key. Thus a restore and a save that
	# disagreed would miss on every run and then fail to store the
	# result.
	my @refs = $yml =~ /^\s+key:\s*(.*)$/mg;
	is( scalar @refs, 2, 'a restore key and a save key' );
	is_deeply(
		[ map { s/\s+//gr } @refs ],
		[ ('${{steps.cache.outputs.key}}') x 2 ],
		'both read the same computed key'
	);
	like(
		$yml,
		qr/^\s+restore-keys:\s*\$\{\{\s*steps\.cache\.outputs\./m,
		'the fallback prefix is computed with it'
	);

	my @paths = $yml =~ /^\s+path:\s*(.*)$/mg;
	is( scalar @paths, 2,         'a restore path and a save path' );
	is( $paths[0],     $paths[1], 'both name the same path' );
	like( $paths[0], qr/\.venv/, 'and it is the virtual environment' );

	like(
		$yml,
		qr/prefix=.*\$\{\{\s*inputs\.version\s*\}\}/,
		'the key names the uv release'
	);
	like(
		$yml,
		qr/prefix=.*\$\{\{\s*github\.event\.repository\.name\s*\}\}/,
		'the key names the repository'
	);

	# The environment holds platform wheels. Thus it is only valid
	# for the machine architecture that restored it.
	like( $yml, qr/prefix=.*\$machine/,
		'the key names the machine architecture' );

	# Fail closed: hashFiles over a path that matches nothing returns
	# an empty string rather than an error. Thus a renamed input
	# would quietly collapse the key, not rotate it. The hashed list
	# is fixed (WFL-UV-2).
	my ($hashed) = $yml =~ /hashFiles\(([^)]*)\)/;
	ok( defined $hashed, 'the key hashes files' ) or return;

	my @paths_hashed = $hashed =~ /'([^']+)'/g;
	is_deeply( \@paths_hashed, \@HASHED,
		'the key hashes exactly the inputs' );

	like(
		$yml,
		qr/if:\s*steps\.restore\.outputs\.cache-hit\s*!=\s*'true'/,
		'the environment is saved only on a cache miss'
	);
};

subtest 'the cache key shell actually composes a key' => sub {

	# The step is legal YAML and legal shell either way. Thus nothing
	# above can tell a working key from an empty one. Run it: the
	# runner interpolates the expressions before bash sees them. Do
	# the same with stand-in values. Then read the outputs back.
	my $shell = _run_block( $yml, 'Compute the cache key' );
	ok( defined $shell, 'the key-computing step has a shell block' )
	    or return;

	my $digest = 'd' x 64;    # what hashFiles() returns
	$shell =~ s/\$\{\{\s*inputs\.version\s*\}\}/0.8.17/g;
	$shell =~ s/\$\{\{\s*hashFiles\([^)]*\)\s*\}\}/$digest/g;
	$shell =~ s/\$\{\{\s*github\.event\.repository\.name\s*\}\}/Tooling/g;
	unlike( $shell, qr/\$\{\{/, 'every expression had a stand-in' );

	my $dir = tempdir( CLEANUP => 1 );
	my $out = "$dir/output";
	open my $fh, '>', "$dir/step.sh" or die "open: $!";
	print $fh $shell;
	close $fh;
	open my $touch, '>', $out or die "open: $!";
	close $touch;

	my $log = `GITHUB_OUTPUT='$out' sh '$dir/step.sh' 2>&1`;
	is( $? >> 8, 0, 'it runs clean' ) or diag($log);

	my %got = map { /\A([^=]+)=(.*)\z/ ? ( $1 => $2 ) : () }
	    split /\n/, ( _slurp($out) // '' );

	ok( length( $got{prefix} // '' ), 'it emits a non-empty prefix' );
	ok( length( $got{key}    // '' ), 'it emits a non-empty key' );

	# The bug this guards: $prefix followed by the digest reads as
	# one variable name. Thus key= comes out empty and restore-keys=
	# stays fine. Only the composition catches it.
	is(
		$got{key},
		( $got{prefix} // '' ) . $digest,
		'and the key is exactly the prefix plus the digest'
	);
	like( $got{prefix}, qr/^Tooling-venv-/,
		'the repository name leads the prefix' );
	like( $got{prefix}, qr/uv0\.8\.17/, 'the uv release is in the key' );
	like( $got{prefix}, qr/x86_64|aarch64|arm64/,
		'the machine architecture is in the key' );
};

done_testing();
