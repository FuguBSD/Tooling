#!/usr/bin/env perl
# ex:ts=8 sw=4:
# This test guards the environment exports of each workflow and each
# action, per WFL-ACTIONS-4.
#
# make imports the environment, and a fragment can leave a name open
# to that value. A step that exports an open name reaches into every
# make of the job. The specification states the rule and the cause.
#
# Two forms export a name. An env block sets it for one step, or for
# every step of a job. A write to $GITHUB_ENV sets it for each step
# that follows.
#
# Nothing under .github/ runs outside a runner, so this test reads
# each file as text. The reader is not a YAML parser. It knows the
# forms that GitHub documents.
#
# A shell can hide an assignment from the text. A brace group across
# lines, and a name that the script computes, both stay outside this
# reader. WFL-ACTIONS-4 holds for them, and no gate reads them.

use v5.36;
use Test::More;
use FindBin    qw($RealBin);
use File::Glob qw(bsd_glob);

my $root = "$RealBin/../..";

# The canonical fragment of each pack, and the fragments that this
# repository runs. A consumer takes the first set, and the make of
# this checkout reads the second.
my @FRAGMENTS = (
	bsd_glob("$root/*/sync/mk/*.mk"),     bsd_glob("$root/mk/*.mk"),
	bsd_glob("$root/*/sync/GNUmakefile"), bsd_glob("$root/GNUmakefile"),
);

# Each shared workflow and each composite action. An action runs make
# in the caller's tree, as a workflow does, so both need the guard.
# GitHub reads .yaml beside .yml, and a glob star takes no leading
# dot, so .github holds a pattern of its own.
my @TARGETS = sort( map { bsd_glob($_) } "$root/.github/workflows/*.yml",
	"$root/.github/workflows/*.yaml",
	"$root/.github/actions/*/action.yml",
	"$root/.github/actions/*/action.yaml",
	"$root/actions/*/action.yml",
	"$root/actions/*/action.yaml",
	"$root/*/actions/*/action.yml",
	"$root/*/actions/*/action.yaml",
);

# make holds these itself, and no fragment assigns one. A workflow
# that exported one would carry a variable override into every make
# of the job.
my @CONTROL = qw(MAKEFLAGS GNUMAKEFLAGS MAKEFILES MAKELEVEL VPATH GPATH);

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

# _make_variables($text):
#	Three sets of names from the text of a make fragment: the
#	names that a plain = assigns, the names that ?= or +=
#	assigns, and the names that the text reads.
#
#	MK-SUBSET-1 holds a fragment to =, ?= and += . A plain =
#	replaces an imported value, so the fragment controls the
#	name. ?= keeps the imported value, and += appends to it.
#
#	The reader fails closed. Only a plain = outside a define body
#	reaches the controlled set. A define body, a target-specific
#	assignment and every other form stay open, because
#	MK-SUBSET-1 gives a fragment none of them.
sub _make_variables ($text)
{
	my ( %hard, %soft, %read, $define );
	for my $raw ( split /\n/, $text ) {
		my $line = $raw =~ s/\r\z//r;

		# A name inside a define body is text, and make assigns
		# it at no point. An unclosed define must not silence
		# the reader, so the state guards the controlled set
		# alone.
		if ( $line =~ /^\s*define\b/ ) { $define = 1; next }
		if ( $line =~ /^\s*endef\b/ )  { $define = 0; next }

		# A comment holds no reference. An escaped hash is a
		# literal, and mk/perl.mk holds one.
		my $code = $line =~ s/(?<!\\)\#.*\z//r;
		$read{$1} = 1
		    while $code =~ /\$[({]([A-Za-z_][A-Za-z0-9_]*)[)}]/g;

		# A target-specific assignment holds for one target
		# alone, so it controls no name of the fragment.
		if (
			$code =~ m{
			^[^:=\s]+ \s* : \s*
			(?: (?: export | override ) \s+ )*
			( [A-Za-z_][A-Za-z0-9_]* ) \s* [:+?]? =
		}x
		    )
		{
			$soft{$1} = 1;
			next;
		}

		# A line that starts with a tab is a recipe line, and
		# the pattern below takes spaces alone.
		my ( $name, $op ) = $code =~ m{
			^[ ]* (?: (?: export | override ) \s+ )*
			( [A-Za-z_][A-Za-z0-9_]* ) \s* ( [:+?]? = )
		}x;
		next unless defined $name;

		if   ( $op eq '=' && !$define ) { $hard{$name} = 1 }
		else                            { $soft{$name} = 1 }
	}

	return ( \%hard, \%soft, \%read );
}

# _open_names($hard, $soft, $read):
#	Each name of one fragment that make can take from the
#	environment. A name that ?= or += assigns stays open. A name
#	that the fragment reads and assigns at no point is open too.
#
#	A plain = in the same fragment closes the name, whatever the
#	order of the lines. A later = replaces an imported value, and
#	a later ?= leaves an earlier assignment alone.
sub _open_names ( $hard, $soft, $read )
{
	my %open = ( %{$soft}, %{$read} );
	delete $open{$_} for keys %{$hard};

	return \%open;
}

# _mapping_key($line):
#	The key of a mapping entry, quoted or bare, or undef.
sub _mapping_key ($line)
{
	my @name = $line =~ m{
		^\s* (?: "([^"]*)" | '([^']*)' | ([A-Za-z_][A-Za-z0-9_]*) ) \s* :
	}x;

	return ( grep { defined } @name )[0];
}

# _opens_scalar($line):
#	True when the line opens a block scalar. The body of one
#	holds text, so no mapping key lives in it. YAML takes the
#	chomping mark and the indent mark in either order.
sub _opens_scalar ($line)
{
	return $line =~ /:[ ]*[|>][-+0-9]*[ ]*(?:\#.*)?$/ ? 1 : 0;
}

# _key_indent($line):
#	The column of the first key of the line. A sequence item
#	holds a dash before its first key, and the key then stands to
#	the right of the dash.
sub _key_indent ($line)
{
	my ( $space, $dash ) = $line =~ /^([ ]*)(-[ ]+)?/;

	return length($space) + ( defined $dash ? length($dash) : 0 );
}

# _exports($text):
#	Each [ name, line ] pair that the file exports into the
#	environment of a later command.
#
#	A write to $GITHUB_ENV takes three forms. One line can hold
#	`NAME=value`. The multiline form of GitHub holds
#	`NAME<<DELIM`, and the body follows on later lines. A script
#	can also redirect a shell heredoc, and each line of that body
#	holds one assignment.
#
#	A heredoc never outlives the script that holds it, so the
#	block scalar bounds it. Every read below runs on every line,
#	so a heredoc that the reader opens in error costs a name and
#	never loses one.
sub _exports ($text)
{
	my ( @found, $env, $scalar, $heredoc );
	my $lineno = 0;

	for my $raw ( split /\n/, $text, -1 ) {
		$lineno++;
		my $line   = $raw  =~ s/\r\z//r;
		my $blank  = $line =~ /^\s*$/;
		my $indent = length( ( $line =~ /^([ ]*)/ )[0] );

		# The body of a block scalar ends at the first line
		# that is no deeper than the key that opened it, and
		# the body of a heredoc ends with it.
		if ( defined $scalar && !$blank && $indent <= $scalar ) {
			$scalar  = undef;
			$heredoc = undef;
		}

		# Each line of a heredoc body holds one assignment.
		if ( defined $heredoc ) {
			if ( $line =~ /^\s*\Q$heredoc\E\s*$/ ) {
				$heredoc = undef;
			}
			elsif ( $line =~ /^\s*([A-Za-z_][A-Za-z0-9_]*)=/ ) {
				push @found, [ $1, $lineno ];
			}
		}

		# A comment holds no export. The read below runs on a
		# script line as well, and a hash starts a comment in
		# both languages.
		my $comment = $line =~ /^\s*\#/;

		# A write to $GITHUB_ENV names the variable before an =
		# or a << . The redirection takes more than one form,
		# so the name alone decides.
		if ( !$comment && $line =~ /GITHUB_ENV/ ) {
			push @found, [ $1, $lineno ]
			    if $line =~ m{
				(?: ^ | [\s"'\{(] )
				( [A-Za-z_][A-Za-z0-9_]* ) (?: = | << )
			    }x;

			# A shell heredoc stands on its own, so a
			# space runs before its << . The multiline
			# form of GitHub joins the << to the name, and
			# it opens no heredoc.
			my $code = $line =~ s/\s\#.*\z//r;
			$heredoc = $2
			    if $code =~
			    /(?:^|\s)<<-?\s*(["']?)([A-Za-z_][A-Za-z0-9_]*)\1/;
		}

		if ( defined $scalar ) {
			next if $blank || $indent > $scalar;
		}
		next if $blank || $comment;

		if ( defined $env ) {
			if ( $indent > $env ) {
				my $name = _mapping_key($line);
				push @found, [ $name, $lineno ]
				    if defined $name;
				$scalar = _key_indent($line)
				    if _opens_scalar($line);
				next;
			}
			$env = undef;
		}

		# The block form opens a mapping. A sequence item can
		# hold env as its first key, and the dash then stands
		# for the indent of the key.
		if ( my @open =
			$line =~ /^([ ]*)(-[ ]+)?["']?env["']?:[ ]*(?:\#.*)?$/ )
		{
			$env = length( $open[0] ) +
			    ( defined $open[1] ? length( $open[1] ) : 0 );
			next;
		}

		# The flow form holds every name on the one line.
		if ( my ($flow) =
			$line =~
m{^[ ]*(?:-[ ]+)?["']?env["']?:[ ]*\{(.*)\}[ ]*(?:\#.*)?$}
		    )
		{
			while ( $flow =~
/(?:^|,)\s*["']?([A-Za-z_][A-Za-z0-9_]*)["']?\s*:/g
			    )
			{
				push @found, [ $1, $lineno ];
			}
			next;
		}

		$scalar = _key_indent($line) if _opens_scalar($line);
	}

	return \@found;
}

# _collisions($open, $pairs):
#	Each "NAME at line N" that both sides hold.
sub _collisions ( $open, $pairs )
{
	return map { "$_->[0] at line $_->[1]" }
	    grep { $open->{ $_->[0] } } @{$pairs};
}

subtest 'the reader of a fragment sorts the assignments' => sub {

	# A reader that matched nothing would pass every guard below,
	# and it would prove nothing.
	my $fixture = <<'MK';
# A comment names $(COMMENTED) and nothing else.
DIST		?= scripts/dist
VERSION		?=
LINT_TARGETS	+= lint-perl
  INDENTED	?= yes
export EXPORTED	?= yes
override RULED	?= yes
PERL_SRC	= find $(PERL_SRC_DIRS) -type f -name "^\#!" -print
IMMEDIATE	:= now
define BODY
IN_DEFINE	= no assignment
endef
target: PER_TARGET = one target only
recipe:
	@echo RECIPE=1
MK
	my ( $hard, $soft, $read ) = _make_variables($fixture);
	my $open = _open_names( $hard, $soft, $read );

	ok( $open->{DIST},         'a ?= assignment leaves the name open' );
	ok( $open->{VERSION},      'an empty ?= assignment too' );
	ok( $open->{LINT_TARGETS}, 'and a += assignment' );
	ok( $open->{INDENTED},     'and an assignment behind spaces' );
	ok( $open->{EXPORTED},     'and one behind export' );
	ok( $open->{RULED},        'and one behind override' );

	# make never takes this one from the environment, so the
	# guard must give it no ground to fail a workflow.
	ok( $hard->{PERL_SRC},  'a plain = holds the name' );
	ok( !$open->{PERL_SRC}, 'so a plain = never reaches the open set' );

	# The reader fails closed on each form that MK-SUBSET-1 gives
	# a fragment no room for.
	ok( $open->{IMMEDIATE},  'a := assignment stays open' );
	ok( !$hard->{IN_DEFINE}, 'a define body controls no name' );
	ok( $open->{PER_TARGET}, 'a target-specific assignment stays open' );

	# A name that the fragment reads and never controls comes
	# from the environment whole.
	ok( $read->{PERL_SRC_DIRS}, 'the reader sees a reference' );
	ok( $open->{PERL_SRC_DIRS}, 'and a read-only name stays open' );

	# A comment holds no reference, and an escaped hash is a
	# literal that no comment starts.
	ok( !$open->{COMMENTED}, 'a comment names no open variable' );
	ok( $hard->{PERL_SRC},   'and an escaped hash keeps the line' );

	ok(
		!$hard->{RECIPE} && !$open->{RECIPE},
		'and a recipe line is no name'
	);
};

subtest 'an unclosed define leaves the names open' => sub {

	# A reader that dropped the rest of the file would report an
	# empty set, and every workflow would then pass.
	my ( $hard, $soft, $read ) = _make_variables(<<'MK');
define BODY
some text
DIST		?= scripts/dist
VERSION		?=
MK
	my $open = _open_names( $hard, $soft, $read );

	ok( $open->{DIST},    'DIST stays open after an unclosed define' );
	ok( $open->{VERSION}, 'and VERSION with it' );
};

subtest 'the reader of a file finds each export' => sub {
	my $fixture = <<'YML';
jobs:
  release:
    steps:
      - name: Block form
        env:
          # A comment never closes the block.
          DIST: ${{ inputs.dist }}

          "QUOTED": yes
          NOTE: |
            DIST: this line is text
          VERSION: ${{ steps.version.outputs.version }}
        run: |
          make dist
      - env: { FLOW: 1, 'SECOND': 2 }
        run: make dist
      - name: A quoted key opens the block
        "env":
          QUOTEDBLOCK: 1
        run: make dist
      - name: A script is not a mapping
        run: |
          env:
            HIDDEN: 1
      - name: A write to the job environment
        run: |
          echo "WRITTEN=yes" >> "$GITHUB_ENV"
          echo "PERL_MM_OPT=INSTALL_BASE=/x" >> $GITHUB_ENV
          echo "/x/bin" >> $GITHUB_PATH
          { echo "GROUPED=yes"; } >> "$GITHUB_ENV"
          cat >> "$GITHUB_ENV" <<'EOF'
          HEREDOC=yes
          EOF
          echo "MULTILINE<<BLOCK" >> "$GITHUB_ENV"
          echo "a value" >> "$GITHUB_ENV"
          echo "BLOCK" >> "$GITHUB_ENV"
      - name: After every script
        env:
          LAST: 1
YML
	my @pairs = @{ _exports($fixture) };
	my %line  = map { $_->[0] => $_->[1] } @pairs;

	is( $line{DIST},        7,  'the block form gives a name' );
	is( $line{QUOTED},      9,  'a quoted key too' );
	is( $line{VERSION},     12, 'and a key after a block scalar value' );
	is( $line{FLOW},        15, 'the flow form gives each name' );
	is( $line{SECOND},      15, 'the quoted one with it' );
	is( $line{QUOTEDBLOCK}, 19, 'a quoted env key opens the block' );
	is( $line{WRITTEN},     27, 'a write to $GITHUB_ENV gives a name' );
	is( $line{GROUPED},     30, 'a brace group gives one too' );
	is( $line{HEREDOC},     32, 'a heredoc body gives a name' );
	is( $line{MULTILINE},   34, 'and the multiline form of GitHub' );

	# The value of NOTE is text. A key inside it sets nothing.
	is( $line{DIST}, 7, 'a key inside a block scalar value sets nothing' );

	# A script holds the word env, and a script is not a block.
	ok( !exists $line{HIDDEN}, 'a script sets no name' );

	# The redirection ends the name, and the first assignment wins.
	ok( exists $line{PERL_MM_OPT},   'the write takes the first name' );
	ok( !exists $line{INSTALL_BASE}, 'and never a later one' );
	ok( !exists $line{PATH},         'and $GITHUB_PATH sets no name' );

	# The multiline form opens no heredoc, so the reader must not
	# lose the lines that follow it.
	is( $line{LAST}, 39, 'the reader reaches the last step' );
};

subtest 'the detector reports the release fault' => sub {

	# The text of the build step before the fix. Every reader
	# above must meet here, or the guard proves nothing.
	my $fixture = <<'YML';
      - name: Build the distribution tarball
        env:
          DIST: ${{ inputs.dist }}
          VERSION: ${{ steps.version.outputs.version }}
        run: |
          make dist VERSION="$VERSION"
YML
	my @hit =
	    _collisions( { DIST => 1, VERSION => 1 }, _exports($fixture) );
	is( scalar @hit, 2, 'both names of the release fault report' )
	    or diag("@hit");
};

my %OPEN;
subtest 'the fragments are there, and they leave names open' => sub {
	ok( @FRAGMENTS, 'the glob found a fragment' ) or return;

	# The reach of each glob. A pattern that matched nothing would
	# drop names from the set, and every workflow would then pass.
	my %seen = map { (m{\Q$root\E/(.*)\z})[0] => 1 } @FRAGMENTS;
	ok( $seen{'perl/sync/mk/perl.mk'}, 'the fragment of a pack is there' );
	ok( $seen{'mk/local.mk'},          'the fragment of this repository' );
	ok(
		$seen{'org/sync/GNUmakefile'},
		'and the dispatcher, which make reads'
	);

	# make resolves each fragment on its own, so the open set of
	# one never closes a name of another.
	%OPEN = map { $_ => 1 } @CONTROL;
	for my $path (@FRAGMENTS) {
		my ( $hard, $soft, $read ) = _make_variables( _slurp($path) );
		my $open = _open_names( $hard, $soft, $read );
		$OPEN{$_} = 1 for keys %{$open};
	}

	# The two names of the release fault. A rename in a fragment
	# must not retire this guard in silence.
	ok( $OPEN{DIST},      'DIST stays open to the environment' );
	ok( $OPEN{VERSION},   'and VERSION with it' );
	ok( $OPEN{MAKEFLAGS}, 'and make holds MAKEFLAGS itself' );

	# A consumer holds its own mk/local.mk, and a shared workflow
	# runs in the tree of the consumer, so a name that one
	# fragment leaves open stays open here.
	ok( $OPEN{DEPS}, 'a name that one fragment pins stays open' );

	# make takes this one from the fragment, whatever the
	# environment holds.
	ok( !$OPEN{PERL_SRC}, 'and a plain = closes a name' );
};

subtest 'no workflow and no action exports an open name' => sub {
	ok( @TARGETS, 'the glob found a target' )          or return;
	ok( %OPEN,    'and the fragments gave the names' ) or return;

	# The reach of the glob. setup-perl runs make in the caller's
	# tree, and it lives under a pack directory, so a pattern that
	# lost the pack directories would drop it.
	my %seen = map { (m{\Q$root\E/(.*)\z})[0] => 1 } @TARGETS;
	ok(
		$seen{'perl/actions/setup-perl/action.yml'},
		'the actions of a pack are in it'
	);
	ok(
		$seen{'actions/gh-release/action.yml'},
		'and the actions of the root'
	);
	ok( $seen{'.github/workflows/perl-release.yml'},
		'and the shared workflows' );

	for my $path (@TARGETS) {
		my ($file) = $path =~ m{([^/]+/[^/]+)\z};
		my @hit = _collisions( \%OPEN, _exports( _slurp($path) ) );
		is( scalar @hit, 0, "$file exports no open name" )
		    or diag( "$file: " . join ', ', @hit );
	}
};

done_testing();
