#!/usr/bin/env perl
# ex:ts=8 sw=4:
# Guards for actions/brew-bump/bump, per WFL-BREW-3 and WFL-BREW-4
#
# The script runs once per release, on the formula of the caller in
# the tap. A wrong byte in the formula breaks brew install for every
# user of that formula, and a silent failure leaves the tap at the
# old release with no message for the operator.
#
# The test runs the script against a fixture formula in a temporary
# directory, with no network. The fixture holds a resource block,
# because a resource indents its own url and sha256 lines deeper,
# and the script must leave those alone.

use v5.36;
use Test::More;
use File::Temp qw(tempdir);
use FindBin    qw($RealBin);

my $root   = "$RealBin/../..";
my $script = "$root/actions/brew-bump/bump";

my $OLD_URL = 'https://github.com/FuguBSD/FuguSeed/releases/download/'
    . 'v0.1.0/App-FuguSeed-0.1.0.tar.gz';
my $OLD_DIGEST = '0' x 64;
my $URL        = 'https://github.com/FuguBSD/FuguSeed/releases/download/'
    . 'v0.1.1/App-FuguSeed-0.1.1.tar.gz';
my $DIGEST = 'a' x 64;

# The lines of the resource block. Each one sits four spaces in, and
# the script must leave each one as it is.
my $RESOURCE_URL = 'https://cpan.metacpan.org/authors/id/M/MI/MIK/'
    . 'Crypt-URandom-0.54.tar.gz';
my $RESOURCE_DIGEST = '1' x 64;

# _formula($url, $digest):
#	A formula with the two formula-level values, and one resource
#	block with its own url and sha256 lines.
sub _formula ( $url, $digest )
{
	return <<"END";
class Fuguseed < Formula
  desc "Seed phrase tools of the FuguBSD project"
  homepage "https://github.com/FuguBSD/FuguSeed"
  url "$url"
  sha256 "$digest"
  license "ISC"

  depends_on "fugubsd/tap/fugu"
  uses_from_macos "perl"

  resource "Crypt::URandom" do
    url "$RESOURCE_URL"
    sha256 "$RESOURCE_DIGEST"
  end

  def install
    ENV.prepend_create_path "PERL5LIB", libexec/"lib/perl5"
    resources.each do |r|
      r.stage do
        system "perl", "Makefile.PL", "INSTALL_BASE=#{libexec}"
        system "make", "install"
      end
    end
    system "perl", "Makefile.PL", "INSTALL_BASE=#{prefix}"
    system "make", "install"
    bin.env_script_all_files(libexec/"bin", PERL5LIB: ENV["PERL5LIB"])
  end

  test do
    system bin/"fuguseed", "--version"
  end
end
END
}

# _slurp($path):
#	Whole file as text, or undef when the file is absent.
sub _slurp ($path)
{
	open my $fh, '<', $path or return;
	local $/ = undef;
	my $content = <$fh>;
	close $fh;

	return $content;
}

# _write($path, $text):
#	The text as the whole file.
sub _write ( $path, $text )
{
	open my $fh, '>', $path or die "open: $!";
	print $fh $text;
	close $fh;

	return;
}

# _run(@args):
#	Run the script with the arguments under this perl. Return the
#	exit status, the standard output and the standard error.
sub _run (@args)
{
	my $dir = tempdir( CLEANUP => 1 );
	my $cmd = join ' ', map { "'$_'" } $^X, $script, @args;
	my $out = `$cmd 2>'$dir/err'`;

	return ( $? >> 8, $out, _slurp("$dir/err") // '' );
}

# _resource_lines($text):
#	The url and sha256 lines of the resource block.
sub _resource_lines ($text)
{
	return [ grep { /^ {4}(?:url|sha256) "/ } split /\n/, $text ];
}

subtest 'a bump changes the two lines and no other byte' => sub {
	my $dir     = tempdir( CLEANUP => 1 );
	my $formula = "$dir/fuguseed.rb";
	_write( $formula, _formula( $OLD_URL, $OLD_DIGEST ) );

	my ( $status, $out, $err ) = _run( $formula, $URL, $DIGEST );
	is( $status, 0,  'it exits 0' ) or diag($err);
	is( $out,    '', 'and prints nothing on standard output' );
	is( $err,    '', 'and nothing on standard error' );

	my $got = _slurp($formula);
	is(
		$got,
		_formula( $URL, $DIGEST ),
		'the file is the fixture with the two values changed'
	);
	is_deeply(
		_resource_lines($got),
		_resource_lines( _formula( $OLD_URL, $OLD_DIGEST ) ),
		'and the resource lines are unchanged'
	);
};

subtest 'a fault exits 1, names the arguments, and writes nothing' => sub {
	my $fixture = _formula( $OLD_URL, $OLD_DIGEST );

	# Each case is a fixture with one fault, and the text that the
	# message names for it.
	my %CASE = (
		'an absent url line' => [
			$fixture =~ s/^  url "\Q$OLD_URL\E"\n//mr,
			'no url line'
		],
		'an absent sha256 line' => [
			$fixture =~ s/^  sha256 "\Q$OLD_DIGEST\E"\n//mr,
			'no sha256 line'
		],
		'a doubled url line' => [
			$fixture =~ s/^(  url "\Q$OLD_URL\E"\n)/$1$1/mr,
			'2 url lines'
		],
	);

	for my $label ( sort keys %CASE ) {
		my ( $text, $fault ) = @{ $CASE{$label} };
		my $dir     = tempdir( CLEANUP => 1 );
		my $formula = "$dir/fuguseed.rb";
		_write( $formula, $text );

		my ( $status, $out, $err ) = _run( $formula, $URL, $DIGEST );
		is( $status, 1,  "$label exits 1" );
		is( $out,    '', 'and prints nothing on standard output' );

		# The operator writes the two lines by hand from the
		# message, so it names each value (WFL-BREW-4).
		like( $err, qr/\Q$formula\E/, 'the message names the formula' );
		like( $err, qr/\Q$URL\E/,     'and the URL' );
		like( $err, qr/\Q$DIGEST\E/,  'and the digest' );
		like( $err, qr/\Q$fault\E/,   "and the fault: $fault" );
		is( $err =~ tr/\n//, 1, 'and it is one line' );

		is( _slurp($formula), $text, 'and the file is untouched' );
	}
};

subtest 'an absent formula is a fault too' => sub {
	my $dir     = tempdir( CLEANUP => 1 );
	my $formula = "$dir/absent.rb";

	my ( $status, $out, $err ) = _run( $formula, $URL, $DIGEST );
	is( $status, 1,  'it exits 1' );
	is( $out,    '', 'and prints nothing on standard output' );
	like( $err, qr/\Q$formula\E/, 'the message names the formula' );
	like( $err, qr/\Q$URL\E/,     'and the URL' );
	like( $err, qr/\Q$DIGEST\E/,  'and the digest' );
	like( $err, qr/cannot read/,  'and the fault' );
	ok( !-e $formula, 'and it creates no file' );
};

subtest 'a wrong argument count is a usage fault' => sub {
	my ( $status, $out, $err ) = _run( 'formula.rb', $URL );
	is( $status, 2, 'two arguments exit 2' );
	like(
		$err,
		qr/^usage: bump <formula> <url> <digest>$/m,
		'and the usage line names the three arguments'
	);
};

done_testing();
