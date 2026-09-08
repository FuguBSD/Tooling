#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Every agent file of the org pack holds its front matter (REV-AGENTS)
#
# The panel dispatches an agent by name, so the name must equal the
# file stem. The reviewer must deny the edit tools, and the fixer and
# the implementer must accept an edit without a prompt. A colon and a
# space inside a plain multi-line value break the YAML parse of the
# harness, and the agent then loads with no metadata, so the test
# rejects that form too.

use v5.36;
use Test::More;
use FindBin qw($RealBin);

my $dir = "$RealBin/../../org/sync/.claude/agents";

# _slurp($path):
#	Whole file as text, or undef with a failed assertion.
sub _slurp ($path)
{
	open my $fh, '<', $path or do {
		fail("$path is readable");
		return;
	};
	local $/ = undef;
	my $text = <$fh>;
	close $fh;

	return $text;
}

# _front($text):
#	The front matter of one agent file, as a key-to-value hash. A
#	continuation line joins its key. The parser reads the subset
#	that an agent file uses: one scalar or one flow sequence for
#	each key.
sub _front ($text)
{
	return unless $text =~ /\A---\n(.*?)\n---\n/s;
	my %front;
	my $key;
	for my $line ( split /\n/, $1 ) {
		if ( $line =~ /^([A-Za-z][A-Za-z0-9]*):\s*(.*)$/ ) {
			$key = $1;
			$front{$key} = $2;
			next;
		}
		next unless defined $key && $line =~ /^\s+(\S.*)$/;
		$front{$key} = join ' ', grep { length } $front{$key}, $1;
	}

	return \%front;
}

# _list($value):
#	The entries of one flow sequence.
sub _list ($value)
{
	my $inner = $value =~ s/\A\[|\]\z//gr;

	return map { s/\A\s+|\s+\z//gr } split /,/, $inner;
}

opendir my $dh, $dir or die "opendir $dir: $!";
my @files = sort grep { /\.md\z/ } readdir $dh;
closedir $dh;

is(
	"@files",
	'fixer.md implementer.md reviewer.md',
	'the pack holds the three review agents'
);

my %front;
for my $file (@files) {
	my $stem  = $file =~ s/\.md\z//r;
	my $front = _front( _slurp("$dir/$file") // q{} );
	ok( $front, "$file holds front matter" ) or next;
	$front{$stem} = $front;

	is( $front->{name}, $stem, "$file names the agent $stem" );
	ok( length( $front->{description} // q{} ),
		"$file holds a description" );
	unlike( $front->{description} // q{},
		qr/:\s/, "$file keeps a colon out of the description" );
	like(
		$front->{effort} // q{},
		qr/\A(?:low|medium|high|xhigh|max)\z/,
		"$file sets an effort level"
	);
}

# REV-AGENTS-2: the reviewer reads, and it never writes.
my @denied = _list( $front{reviewer}{disallowedTools} // q{} );
is_deeply(
	[ sort @denied ],
	[ 'Edit', 'NotebookEdit', 'Write' ],
	'the reviewer denies the edit tools'
);
is( $front{reviewer}{effort}, 'high', 'the reviewer reads at high effort' );
ok(
	!exists $front{reviewer}{permissionMode},
	'the reviewer needs no permission mode'
);

# REV-AGENTS-5 and REV-AGENTS-7: the fixer and the implementer take
# the full tool set, and an edit runs without a prompt.
for my $stem (qw(fixer implementer)) {
	is( $front{$stem}{effort}, 'xhigh', "the $stem works at xhigh effort" );
	is( $front{$stem}{permissionMode},
		'acceptEdits', "the $stem accepts its own edits" );
	ok( !exists $front{$stem}{tools}, "the $stem takes the full tool set" );
	ok( !exists $front{$stem}{disallowedTools},
		"the $stem denies no tool" );
}

done_testing();
