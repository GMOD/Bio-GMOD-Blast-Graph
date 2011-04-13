use strict;
use warnings;

use Test::More;

use File::Temp;

use Capture::Tiny qw/ capture /;
use File::Spec::Functions 'catfile';

use Bio::GMOD::Blast::Graph;

my $tempdir = File::Temp->newdir;

my $report = catfile(qw( t data blast_report.blast ));
my $image_name = 'foo.png';
my $graph = Bio::GMOD::Blast::Graph->new(
    -outputfile => $report,
    -dstDir     => "$tempdir",
    -dstURL     => '/fake/url/',
    -imgName    => $image_name,
    );

isa_ok( $graph, 'Bio::GMOD::Blast::Graph' );

my ( $stdout, $stderr ) = capture {
    $graph->showGraph;
};

like( $stdout, qr/$_/, "graph output has $_" )
    for (
        $image_name,
        qw(
              SGN-U578206
              SL2.40ch06
              SGN-U580132
              SGN-U578259
              SL2.40ch12
          ),
        );

done_testing;
