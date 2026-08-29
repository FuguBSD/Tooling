#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Unit tests for scripts/sync against a fixture consumer
#
# sync copies the selected packs of this repository into a consumer. The
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

sub consumer (@packs)
{
	@packs = qw(org perl) unless @packs;
	my $dir = tempdir( CLEANUP => 1 );
	open my $fh, '>', "$dir/.toolingrc" or die "write: $!";
	print $fh "dist.name Fix\n";
	print $fh "sync.pack $_\n" for @packs;
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
	ok( -f "$dir/t/ci/local.t",     'the consumer hook test arrives' );
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

# A consumer that selects the org pack only gets no Perl files.
{
	my $org = consumer('org');
	my ( $exit, $output ) = run_in($org);
	is( $exit, 0, 'sync into an org-only consumer works' )
	    or diag($output);

	ok( -f "$org/scripts/deps",       'the installer arrives' );
	ok( -f "$org/scripts/spec-check", 'the spec check arrives' );
	ok( -f "$org/scripts/ste-lint",   'the prose lint arrives' );
	ok( -f "$org/.gitleaks.toml", 'the gitleaks configuration arrives' );

	# MK-GITLEAKS-3: the shipped configuration extends the default
	# rules. A copy without the extend block disables every rule in
	# every consumer, in silence.
	if ( open my $toml_fh, '<', "$org/.gitleaks.toml" ) {
		my $toml = do { local $/; <$toml_fh> };
		close $toml_fh;
		like( $toml, qr/^\[extend\]$/m,
			'the configuration holds the extend block' );
		like(
			$toml,
			qr/^useDefault = true$/m,
			'and extends the default rules'
		);
	}
	else {
		fail('the gitleaks configuration is readable');
	}
	ok( -f "$org/CLAUDE.md",       'the root instructions arrive' );
	ok( -f "$org/spec/CLAUDE.md",  'the spec instructions arrive' );
	ok( -f "$org/plans/CLAUDE.md", 'the plan instructions arrive' );
	ok( !-f "$org/scripts/dist",   'no dist script arrives' );
	ok( !-f "$org/.perlcriticrc",  'no lint configuration arrives' );

	( $exit, $output ) = run_in( $org, '--check' );
	is( $exit, 0, 'a fresh org-only sync passes --check' )
	    or diag($output);
}

# A consumer that adds the infra pack gets the infrastructure
# instructions on top of the org pack.
{
	my $infra = consumer( 'org', 'infra' );
	my ( $exit, $output ) = run_in($infra);
	is( $exit, 0, 'sync into an infra consumer works' ) or diag($output);

	ok( -f "$infra/infra/CLAUDE.md", 'the infra instructions arrive' );
	ok( -f "$infra/scripts/deps",    'the org pack arrives too' );
	ok( !-f "$infra/scripts/dist",   'and no Perl files arrive' );

	( $exit, $output ) = run_in( $infra, '--check' );
	is( $exit, 0, 'a fresh infra sync passes --check' ) or diag($output);
}

# A consumer that adds the web pack gets the website instructions and
# the shared footer on top of the org pack.
{
	my $web = consumer( 'org', 'web' );
	my ( $exit, $output ) = run_in($web);
	is( $exit, 0, 'sync into a web consumer works' ) or diag($output);

	ok( -f "$web/web/CLAUDE.md",        'the web instructions arrive' );
	ok( -f "$web/web/footer.body.html", 'the shared footer arrives' );
	ok( -f "$web/scripts/deps",         'the org pack arrives too' );
	ok( !-f "$web/scripts/dist",        'and no Perl files arrive' );

	( $exit, $output ) = run_in( $web, '--check' );
	is( $exit, 0, 'a fresh web sync passes --check' ) or diag($output);
}

# A consumer that adds the python pack gets the uv toolchain files on
# top of the org pack.
{
	my $python = consumer( 'org', 'python' );
	my ( $exit, $output ) = run_in($python);
	is( $exit, 0, 'sync into a python consumer works' ) or diag($output);

	ok( -f "$python/ruff.toml",          'the Ruff configuration arrives' );
	ok( -f "$python/mk/python.mk",       'the python fragment arrives' );
	ok( -f "$python/packages/CLAUDE.md", 'the style rules arrive' );
	ok( -f "$python/t/ci/python.t", 'the consumer python test arrives' );
	ok( -f "$python/scripts/deps",  'the org pack arrives too' );
	ok( !-f "$python/scripts/dist", 'and no Perl files arrive' );

	# MK-PYTHON-2: the consumer owns the project files, and the pack
	# must not ship them.
	ok( !-f "$python/pyproject.toml",  'no project manifest arrives' );
	ok( !-f "$python/.python-version", 'no interpreter pin arrives' );
	ok( !-f "$python/uv.lock",         'no lockfile arrives' );

	( $exit, $output ) = run_in( $python, '--check' );
	is( $exit, 0, 'a fresh python sync passes --check' ) or diag($output);
}

# A consumer with no sync.pack line gets the org pack.
{
	my $bare = tempdir( CLEANUP => 1 );
	open my $fh, '>', "$bare/.toolingrc" or die "write: $!";
	print $fh "dist.name Fix\n";
	close $fh;

	my ( $exit, $output ) = run_in($bare);
	is( $exit, 0, 'sync with no pack line works' ) or diag($output);
	ok( -f "$bare/scripts/deps",  'and delivers the org pack' );
	ok( !-f "$bare/scripts/dist", 'and only the org pack' );
}

# An unknown pack is refused.
{
	my $bad = consumer('cobol');
	my ( $exit, $output ) = run_in($bad);
	isnt( $exit, 0, 'an unknown pack is refused' );
	like( $output, qr/unknown pack/, 'and the error names the cause' );
}

done_testing();
