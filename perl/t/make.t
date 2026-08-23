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
my @FRAGMENTS  = ( "$root/org/sync/mk/org.mk", "$root/perl/sync/mk/perl.mk" );

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
			'-include mk/perl.mk'
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

# The fragments: the portable subset, the .PHONY register of
# MK-COMPOSE-6, and no aggregate membership for the formatting pair.
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

	unlike(
		$text,
		qr/_TARGETS[ \t]*\+=[^\n]*format-md/,
		"$name appends format-md to no aggregate"
	);
}

# The consumer hook of this repository satisfies the portable subset
# (MK-LOCAL-3): every dispatcher includes it.
is( join( "\n", _subset_violations("$root/mk/local.mk") ),
	q{}, 'mk/local.mk satisfies the portable subset' );

# No pack holds the path Makefile or the consumer hook mk/local.mk.
for my $pack ( "$root/org/sync", "$root/perl/sync" ) {
	ok( !-e "$pack/Makefile",    "$pack holds no Makefile" );
	ok( !-e "$pack/mk/local.mk", "$pack holds no mk/local.mk" );
}

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
	'lint-perl'   => qr/Perl::Critic::Command/,
	'format-perl' => qr/Perl::Tidy/,
	'test-prove'  => qr/prove/,
	'spec-check'  => qr{scripts/spec-check},
	'ste-lint'    => qr{scripts/ste-lint},
	'local-gate'  => qr/local gate ran/,
);
my %DRY = (
	'lint'   => ['lint-perl'],
	'format' => ['format-perl'],
	'test'   => ['test-prove'],
	'check'  => [
		'lint-perl', 'format-perl', 'test-prove', 'spec-check',
		'ste-lint',  'local-gate'
	],
	q{} => [
		'lint-perl', 'format-perl', 'test-prove', 'spec-check',
		'ste-lint',  'local-gate'
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
		"$label leaves format-md out"
	);
}

# The plain targets resolve: the formatting pair and the frozen deps
# names of MK-VERBS-4.
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

# An org-only consumer serves every verb (MK-VERBS-2): the absent
# perl fragment leaves the aggregates empty, and every verb still
# resolves.
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

done_testing();
