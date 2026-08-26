#!/usr/bin/env perl
# ex:ts=8 sw=4:
# The make interface against the canon files and a fixture consumer
#
# The org pack owns the GNU dispatcher and the org fragment, and the
# perl pack owns the perl fragment. The static checks hold the canon
# files to the portable subset of MK-SUBSET and to the fixed include
# list of MK-DISPATCH-2. The fixture consumer is a temporary
# directory with a .toolingrc, a mk/local.mk, and a minimal
# specification. The tests sync both packs into it and drive the real
# dispatcher, exactly as a consumer runs it.

use v5.36;
use Test::More;
use Cwd         qw(getcwd);
use Digest::MD5 ();
use FindBin     qw($RealBin);
use File::Find  ();
use File::Path  qw(make_path);
use File::Spec  ();
use File::Temp  qw(tempdir);

# A parent make would pass its flags into every child run below.
delete @ENV{qw(MAKEFLAGS MFLAGS MAKELEVEL GNUMAKEFLAGS MAKEFILES)};

my $root = "$RealBin/../..";
my $sync = "$root/scripts/sync";

my $DISPATCHER = "$root/org/sync/GNUmakefile";
my @FRAGMENTS  = (
	"$root/org/sync/mk/org.mk", "$root/perl/sync/mk/perl.mk",
	"$root/python/sync/mk/python.mk"
);

sub _slurp ($path)
{
	open my $fh, '<:raw', $path or do {
		fail("$path is readable");
		return q{};
	};
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

sub write_file ( $path, $content )
{
	my ($dir) = $path =~ m{^(.*)/[^/]+\z};
	make_path($dir) if defined $dir && !-d $dir;
	open my $fh, '>', $path or die "Cannot write $path: $!";
	print $fh $content;
	close $fh;
}

# run_in($dir, $command):
#	Run one shell command with $dir as the working directory.
sub run_in ( $dir, $command )
{
	my $cwd = getcwd();
	chdir $dir or die "chdir $dir: $!";
	my $output = `$command 2>&1`;
	my $exit   = $? >> 8;
	chdir $cwd or die "chdir $cwd: $!";

	return ( $exit, $output );
}

# _tree_digest($dir):
#	A digest per file of the tree, to prove a target writes nothing.
sub _tree_digest ($dir)
{
	my %digest;
	File::Find::find( {
			no_chdir => 1,
			wanted   => sub {
				return unless -f $File::Find::name;
				my $rel =
				    File::Spec->abs2rel( $File::Find::name,
					$dir );
				open my $fh, '<:raw', $File::Find::name
				    or die "read $rel: $!";
				$digest{$rel} =
				    Digest::MD5->new->addfile($fh)->hexdigest;
				close $fh;
			},
		},
		$dir
	);

	return \%digest;
}

# The dispatcher: the default goal and the fixed include list.
{
	my @active = grep { !/^#/ && /\S/ } split /\n/, _slurp($DISPATCHER);
	is( $active[0], 'all: check', 'the first rule is all: check' );
	is_deeply(
		[ grep { /^-?include/ } @active ],
		[
			'-include mk/local.mk',
			'include mk/org.mk',
			'-include mk/perl.mk',
			'-include mk/python.mk'
		],
		'the include list is fixed'
	);
	is( scalar( grep { /^-?include[^\n]*[*?\[]/ } @active ),
		0, 'no include uses a glob' );
}

# The portable subset of MK-SUBSET. A continuation joins into one
# logical line first. A recipe line is shell text, but make still
# expands a GNU function inside it, so the banned scan covers every
# line.
my @BANNED = (
	[ qr/^-?include\b/, 'an include directive' ],
	[
		qr/^\.(?:if|elif|else|endif|for|endfor|include|sinclude)\b/,
		'a BSD directive'
	],
	[ qr/^(?:ifeq|ifneq|ifdef|ifndef|else|endif)\b/, 'a GNU conditional' ],
	[ qr/[:!]=/,                       'a non-portable assignment' ],
	[ qr/\$[({][a-z][A-Za-z0-9_-]*\s/, 'a GNU function call' ],
	[ qr/\$[({][^)}]*:/,               'a BSD variable modifier' ],
);

# _subset_violations($path):
#	Every logical line of one make file that falls outside the
#	portable subset.
sub _subset_violations ($path)
{
	my $name = File::Spec->abs2rel( $path, $root );
	my $text = _slurp($path);
	$text =~ s/\\\n[ \t]*/ /g;

	my @bad;
	my $number = 0;
	for my $line ( split /\n/, $text ) {
		$number++;
		for my $ban (@BANNED) {
			my ( $pattern, $what ) = @$ban;
			push @bad, "$name:$number holds $what: $line"
			    if $line =~ $pattern;
		}
		next if $line =~ /^\s*$/ || $line =~ /^#/ || $line =~ /^\t/;
		next if $line =~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]*(?:\?=|\+=|=)/;
		next if $line =~ /^\.PHONY[ \t]*:/;
		next if $line =~ /^[A-Za-z0-9._\/-]+[ \t]*:[^=]*$/;
		push @bad, "$name:$number is outside the subset: $line";
	}

	return @bad;
}

# The fragments: the portable subset and the .PHONY register of
# MK-COMPOSE-6.
for my $fragment (@FRAGMENTS) {
	my $name = File::Spec->abs2rel( $fragment, $root );
	is( join( "\n", _subset_violations($fragment) ),
		q{}, "$name satisfies the portable subset" );

	my $text = _slurp($fragment);
	$text =~ s/\\\n[ \t]*/ /g;
	my %phony = map { $_ => 1 }
	    map { split q{ }, ( split /:/, $_, 2 )[1] }
	    grep { /^\.PHONY[ \t]*:/ } split /\n/, $text;
	my @unregistered =
	    grep { !$phony{$_} }
	    map  { ( split /[ \t]*:/, $_, 2 )[0] }
	    grep { /^[A-Za-z0-9._\/-]+[ \t]*:/ && !/^\.PHONY/ }
	    split /\n/, $text;
	is( "@unregistered", q{}, "$name declares each target in .PHONY" );
}

# MK-VERBS-5: only the org fragment defines the formatting pair, and
# it appends each target to the aggregate of its verb.
{
	my $org = _slurp( $FRAGMENTS[0] );
	like(
		$org,
		qr/^FORMAT_TARGETS[ \t]*\+=[ \t]*format-md[ \t]*$/m,
		'org.mk appends format-md to FORMAT_TARGETS'
	);
	like(
		$org,
		qr/^FORMAT_FIX_TARGETS[ \t]*\+=[ \t]*format-md-fix[ \t]*$/m,
		'org.mk appends format-md-fix to FORMAT_FIX_TARGETS'
	);
	for my $fragment ( @FRAGMENTS[ 1 .. $#FRAGMENTS ] ) {
		my $name = File::Spec->abs2rel( $fragment, $root );
		unlike( _slurp($fragment), qr/format-md/,
			"$name leaves the formatting pair to org.mk" );
	}
}

# The consumer hook of this repository satisfies the portable subset
# (MK-LOCAL-3): every dispatcher includes it.
is( join( "\n", _subset_violations("$root/mk/local.mk") ),
	q{}, 'mk/local.mk satisfies the portable subset' );

# _rule_targets($path):
#	The names of the targets that one make file defines. A rule
#	line can name several targets before the colon, and an inline
#	recipe can follow it.
sub _rule_targets ($path)
{
	my $text = _slurp($path);
	$text =~ s/\\\n[ \t]*/ /g;

	my @names;
	for my $line ( split /\n/, $text ) {
		next if $line =~ /^\.PHONY/ || $line =~ /^\t/;
		next unless $line =~ /^([^:=#\t][^:=]*):(?:[^=]|$)/;
		push @names, split q{ }, $1;
	}

	return @names;
}

# MK-LOCAL-4 on the hook of this repository: sync refuses to run
# here, so the synced t/ci/local.t never covers it. The same overlap
# check runs statically, and each fragment pair stays disjoint too.
{
	my %local = map { $_ => 1 } _rule_targets("$root/mk/local.mk");
	my %seen;
	my @twice;
	for my $fragment (@FRAGMENTS) {
		my $name  = File::Spec->abs2rel( $fragment, $root );
		my @names = _rule_targets($fragment);
		my @clash = grep { $local{$_} } @names;
		is( "@clash", q{}, "mk/local.mk redefines no target of $name" );
		push @twice, grep { $seen{$_}++ } @names;
	}
	is( "@twice", q{}, 'no target lives in two fragments' );
}

# No pack holds the path Makefile or the consumer hook mk/local.mk.
for my $pack ( "$root/org/sync", "$root/perl/sync", "$root/python/sync" ) {
	ok( !-e "$pack/Makefile",    "$pack holds no Makefile" );
	ok( !-e "$pack/mk/local.mk", "$pack holds no mk/local.mk" );
}

# MK-PYTHON-3: ruff.toml is the one Ruff configuration. The one
# pyproject.toml of this repository holds no [tool.ruff] section, and
# no subtable such as [tool.ruff.lint]. The synced t/ci/python.t
# holds every consumer to the same rule.
unlike( _slurp("$root/pyproject.toml"),
	qr/^\[tool\.ruff[\].]/m,
	'pyproject.toml holds no [tool.ruff] section' );

# The fixture consumer. The local hook exists before the first sync,
# and holds one override, one stub, and one repo-only gate.
my $dir = tempdir( CLEANUP => 1 );
write_file( "$dir/.toolingrc", "sync.pack org\nsync.pack perl\n" );

my $local = <<'EOF';
# The consumer hook of the fixture (MK-LOCAL).
TEST_GLOBS	= t/fix/*.t
PRETTIER	= echo prettier
CHECK_TARGETS	+= local-gate

local-gate:
	@echo local gate ran
.PHONY: local-gate
EOF
write_file( "$dir/mk/local.mk", $local );

write_file( "$dir/README.md", "# Fixture\n\nA fixture consumer.\n" );
write_file( "$dir/t/fix/basic.t",
	"use Test::More;\nok(1);\ndone_testing();\n" );
write_file( "$dir/spec/index.md", <<'EOF' );
# The fixture specification

| Code | Document         | Area        |
| ---- | ---------------- | ----------- |
| FIX  | [fix.md](fix.md) | The fixture |

Governance: [DECISIONS.md](DECISIONS.md), [ROADMAP.md](ROADMAP.md), and
[STATUS.md](STATUS.md).
EOF
write_file( "$dir/spec/fix.md", <<'EOF' );
# The fixture

<a id="fix-core"></a>

## Core

- **FIX-CORE-1** — The fixture must exist.
EOF
write_file( "$dir/spec/STATUS.md", <<'EOF' );
# Implementation register

## Units

| Unit                        | State | Done by | Note |
| --------------------------- | ----- | ------- | ---- |
| [FIX-CORE](fix.md#fix-core) | open  | —       | —    |
EOF
write_file( "$dir/spec/ROADMAP.md",   "# Roadmap\n\nNo phases exist.\n" );
write_file( "$dir/spec/DECISIONS.md", "# Decisions\n\nNone yet.\n" );

# Sync both packs in, twice: the dispatcher and the fragments arrive,
# and the consumer hook survives both runs (MK-LOCAL-1).
for my $round ( 1, 2 ) {
	my ( $exit, $output ) = run_in( $dir, $sync );
	is( $exit, 0, "sync round $round works" ) or diag($output);
	is( _slurp("$dir/mk/local.mk"),
		$local, "sync round $round leaves mk/local.mk alone" );
}
ok( -f "$dir/GNUmakefile", 'the dispatcher arrives' );
ok( -f "$dir/mk/org.mk",   'the org fragment arrives' );
ok( -f "$dir/mk/perl.mk",  'the perl fragment arrives' );
ok( !-e "$dir/Makefile",   'the path Makefile stays free' );

# The composition, through the dry run: every verb runs the
# namespaced targets of its fragments, and check runs every gate.
my %MARKER = (
	'lint-perl'       => qr/Perl::Critic::Command/,
	'format-perl'     => qr/Perl::Tidy/,
	'format-perl-fix' => qr/Perl::Tidy/,
	'test-prove'      => qr/prove/,
	'spec-check'      => qr{scripts/spec-check},
	'ste-lint'        => qr{scripts/ste-lint},
	'format-md'       => qr/--check.*no-error-on-unmatched-pattern/,
	'format-md-fix'   => qr/--write.*no-error-on-unmatched-pattern/,
	'local-gate'      => qr/local gate ran/,
);
my %DRY = (
	'lint'       => ['lint-perl'],
	'format'     => [ 'format-md',     'format-perl' ],
	'format-fix' => [ 'format-md-fix', 'format-perl-fix' ],
	'test'       => ['test-prove'],
	'check'      => [
		'lint-perl',  'format-md', 'format-perl', 'test-prove',
		'spec-check', 'ste-lint',  'local-gate'
	],
	q{} => [
		'lint-perl',  'format-md', 'format-perl', 'test-prove',
		'spec-check', 'ste-lint',  'local-gate'
	],
);
for my $verb ( sort keys %DRY ) {
	my $label = $verb eq q{} ? 'bare make' : "make $verb";
	my ( $exit, $output ) = run_in( $dir, "make -n $verb" );
	is( $exit, 0, "$label resolves" ) or diag($output);
	for my $target ( @{ $DRY{$verb} } ) {
		like( $output, $MARKER{$target}, "$label runs $target" );
	}
	unlike(
		$output,
		qr/no-error-on-unmatched-pattern/,
		"$label leaves the formatting pair out"
	) unless grep { /^format-md/ } @{ $DRY{$verb} };

	# A read verb must not write (MK-VERBS-1): only format-fix may
	# run the prettier write.
	unlike(
		$output,
		qr/--write.*no-error-on-unmatched-pattern/,
		"$label runs no Markdown write"
	) if $verb ne 'format-fix';
}

# The formatting pair and the frozen deps names of MK-VERBS-4 also
# resolve as direct targets.
for my $target (qw(format-md format-md-fix deps deps-test deps-develop)) {
	my ( $exit, $output ) = run_in( $dir, "make -n $target" );
	is( $exit, 0, "make $target resolves" ) or diag($output);
}

# Bare make runs check for real: every gate passes, the local hook
# wins (TEST_GLOBS points at t/fix), the repo-only gate runs, and no
# file changes.
{
	my $before = _tree_digest($dir);
	my ( $exit, $output ) = run_in( $dir, 'make' );
	is( $exit, 0, 'bare make passes in the fixture' ) or diag($output);
	like( $output, qr{t/fix/basic\.t}, 'the local TEST_GLOBS wins' );
	like( $output, qr/local gate ran/, 'the local gate runs in check' );
	is_deeply( _tree_digest($dir), $before, 'check changes no file' );

	( $exit, $output ) = run_in( $dir, 'make format-md' );
	is( $exit, 0, 'make format-md passes with the local stub' )
	    or diag($output);
	is_deeply( _tree_digest($dir), $before, 'format-md changes no file' );
}

# The dist target passes the flag with the empty default, and
# scripts/dist treats the empty value as absent.
{
	my ( $exit, $output ) = run_in( $dir, 'make -n dist' );
	is( $exit, 0, 'make dist resolves' ) or diag($output);
	like( $output, qr/--version ''/, 'and passes the empty default' );
}

# An org-only consumer serves every verb (MK-VERBS-2): the org
# fragment alone fills the aggregates, and every verb resolves.
{
	my $org = tempdir( CLEANUP => 1 );
	write_file( "$org/.toolingrc", "sync.pack org\n" );

	my ( $exit, $output ) = run_in( $org, $sync );
	is( $exit, 0, 'sync into an org-only consumer works' )
	    or diag($output);
	ok( !-f "$org/mk/perl.mk", 'no perl fragment arrives' );

	for my $verb (qw(check lint format format-fix test)) {
		( $exit, $output ) = run_in( $org, "make -n $verb" );
		is( $exit, 0, "make $verb resolves without the perl pack" )
		    or diag($output);
	}

	# The org fragment owns the deps targets (MK-VERBS-4): the
	# frozen names resolve without any language pack, and each
	# recipe runs scripts/deps with its environment name.
	my %ENV_OF = (
		'deps'         => 'runtime',
		'deps-test'    => 'test',
		'deps-develop' => 'develop',
	);
	for my $target ( sort keys %ENV_OF ) {
		( $exit, $output ) = run_in( $org, "make -n $target" );
		is( $exit, 0, "make $target resolves without the perl pack" )
		    or diag($output);
		like(
			$output,
			qr{scripts/deps $ENV_OF{$target}},
			"and $target runs scripts/deps $ENV_OF{$target}"
		);
	}
}

# A python consumer serves the uv targets: the fragment appends them
# to the aggregates, and check runs the lockfile gate. The dry run
# proves the wiring without uv.
{
	my $py = tempdir( CLEANUP => 1 );
	write_file( "$py/.toolingrc", "sync.pack org\nsync.pack python\n" );

	my ( $exit, $output ) = run_in( $py, $sync );
	is( $exit, 0, 'sync into a python consumer works' ) or diag($output);
	ok( -f "$py/mk/python.mk", 'the python fragment arrives' );

	( $exit, $output ) = run_in( $py, 'make -n check' );
	is( $exit, 0, 'make check resolves with the python pack' )
	    or diag($output);
	like( $output, qr/uv lock --check/, 'check runs lock-py' );
	like( $output, qr/uv run --locked ruff check \./,
		'check runs lint-py' );
	like(
		$output,
		qr/uv run --locked ruff format --check \./,
		'check runs format-py'
	);

	( $exit, $output ) = run_in( $py, 'make -n setup' );
	is( $exit, 0, 'make setup resolves' ) or diag($output);
	like( $output, qr/uv sync/, 'and runs uv sync' );

	# Every uv run passes --locked: a bare uv run rewrites a stale
	# uv.lock, so a read target would write (MK-VERBS-1). The fix
	# target writes only what format-py reports, so no lint autofix
	# runs here.
	( $exit, $output ) = run_in( $py, 'make -n format-fix' );
	is( $exit, 0, 'make format-fix resolves' ) or diag($output);
	like( $output, qr/uv run --locked ruff format \./, 'it formats' );
	unlike( $output, qr/ruff check --fix/, 'and writes no lint fix' );
	unlike(
		$output,
		qr/uv run ruff/,
		'and no uv run goes without --locked'
	);
}

# format reads and format-fix writes (MK-VERBS-1).
{
	my $messy = "#!/usr/bin/env perl\nuse v5.36;\nmy    \$x   =  1;\n";
	write_file( "$dir/scripts/messy", $messy );
	chmod 0755, "$dir/scripts/messy" or die "chmod: $!";

	my $before = _tree_digest($dir);
	my ( $exit, $output ) = run_in( $dir, 'make format' );
	isnt( $exit, 0, 'make format reports the messy file' );
	like( $output, qr{scripts/messy}, 'and names it' );
	is_deeply( _tree_digest($dir), $before,
		'and changes no file on a messy tree' );

	( $exit, $output ) = run_in( $dir, 'make format-fix' );
	is( $exit, 0, 'make format-fix works' ) or diag($output);
	isnt( _slurp("$dir/scripts/messy"), $messy, 'and writes the fix' );

	( $exit, $output ) = run_in( $dir, 'make format' );
	is( $exit, 0, 'make format passes after the fix' ) or diag($output);
}

# lint reads and fails on a violation: the recipe propagates the
# Perl::Critic exit status.
{
	write_file( "$dir/scripts/violate",
		"#!/usr/bin/env perl\nprint \"x\";\n" );
	chmod 0755, "$dir/scripts/violate" or die "chmod: $!";

	my ( $exit, $output ) = run_in( $dir, 'make lint' );
	isnt( $exit, 0, 'make lint fails on a violation' );
	like( $output, qr/strict/, 'and the output names the finding' );
}

# The synced local.t enforces MK-LOCAL-4: it accepts the compliant
# hook, and it rejects a hook that redefines a fragment target.
{
	my ( $exit, $output ) = run_in( $dir, 'perl t/ci/local.t' );
	is( $exit, 0, 'local.t passes on a compliant hook' )
	    or diag($output);

	write_file( "$dir/mk/local.mk", $local . <<'EOF' );

deps:
	@echo local deps
.PHONY: deps
EOF
	( $exit, $output ) = run_in( $dir, 'perl t/ci/local.t' );
	isnt( $exit, 0, 'local.t fails on a redefined fragment target' );
	like( $output, qr/deps/, 'and the output names the target' );

	# A rule line can hide the clash in a target list or behind an
	# inline recipe. The parser catches both forms.
	write_file( "$dir/mk/local.mk",
		$local . "\ndeps extra: ; \@echo local\n" );
	( $exit, $output ) = run_in( $dir, 'perl t/ci/local.t' );
	isnt( $exit, 0, 'local.t catches a multi-target inline rule' );
	write_file( "$dir/mk/local.mk", $local );
}

done_testing();
