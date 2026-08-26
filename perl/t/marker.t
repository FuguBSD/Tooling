#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Every pack file starts with the marker comment (SYNC-MARKER)
#
# The marker names the pack that owns the file, forbids an edit of a
# synced copy, and points to the canonical copy. Only a shebang line,
# an editor hint, and YAML front matter can come before it. A file
# without comment syntax and an empty placeholder carry no marker.

use v5.36;
use Test::More;
use File::Find ();
use File::Spec ();
use FindBin    qw($RealBin);

my $root = "$RealBin/../..";

my %EXEMPT = (
	'org/sync/.prettierrc'    => 'JSON has no comment syntax',
	'org/sync/plans/.gitkeep' => 'an empty placeholder',
	'org/sync/.github/pull_request_template.md' =>
	    'each pull request body receives a copy',
);

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

# _marker($pack):
#	The marker text that SYNC-MARKER-1 requires for one pack.
sub _marker ($pack)
{
	return
	      "The $pack pack of FuguBSD/Tooling owns this file."
	    . ' Do not edit a synced copy.'
	    . ' Edit the canonical copy in FuguBSD/Tooling.';
}

# _head($text, $form):
#	The first comment of the file, as one plain line, read in the
#	comment form that SYNC-MARKER-2 requires for the file. The
#	shebang line, the ex: editor hint, YAML front matter, and
#	blank lines come off first (SYNC-MARKER-3).
sub _head ( $text, $form )
{
	$text =~ s/\A#![^\n]*\n//;
	$text =~ s/\A# ex:[^\n]*\n//;
	$text =~ s/\A---\n.*?\n---\n//s;
	$text =~ s/\A\s+//;

	my $comment = q{};
	if ( $form eq 'html' ) {
		$comment = $1 if $text =~ /\A<!--(.*?)-->/s;
	}
	else {
		for my $line ( split /\n/, $text ) {
			last unless $line =~ /^#(.*)$/;
			$comment .= " $1";
		}
	}
	$comment =~ s/\s+/ /g;
	$comment =~ s/\A //;

	return $comment;
}

# The pack list comes from the tree, so a future pack cannot escape
# the gate.
my @packs =
    sort map { m{/([^/]+)/sync\z} } grep { -d } glob "$root/*/sync";
ok( scalar @packs >= 5, 'the pack walk finds the packs' );

for my $pack (@packs) {
	my $tree = "$root/$pack/sync";
	my @files;
	File::Find::find( {
			no_chdir => 1,
			wanted   => sub {
				push @files, $File::Find::name
				    if -f $File::Find::name;
			},
		},
		$tree
	);
	ok( scalar @files, "the $pack pack holds files" );

	for my $path ( sort @files ) {
		my $rel = File::Spec->abs2rel( $path, $root );
		if ( my $why = $EXEMPT{$rel} ) {
			my $text = _slurp($path) // q{};
			unlike(
				$text,
				qr/owns this file/,
				"$rel carries no marker: $why"
			);
			is( length $text, 0, "$rel stays empty" )
			    if $rel =~ /\.gitkeep\z/;
			like( $text, qr/\A\{/, "$rel stays JSON" )
			    if $rel =~ /\.prettierrc\z/;
			next;
		}
		my $form = $rel =~ /\.(?:md|html)\z/ ? 'html' : 'hash';
		my $head = _head( _slurp($path) // q{}, $form );
		is( index( $head, _marker($pack) ),
			0, "$rel starts with the marker" );
	}
}

done_testing();
