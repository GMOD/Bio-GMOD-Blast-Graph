package Bio::GMOD::Blast::Graph::Bucket;
#####################################################################
#
# Cared for by Shuai Weng <shuai@genome.stanford.edu>
#
# Originally created by John Slenk <jces@genome.stanford.edu>
#
# You may distribute this module under the same terms as perl itself
#-----------------------------------------------------------------
#
# our more useful version of an IntSpan.

# use Carp;

use Bio::GMOD::Blast::Graph::BaseObj;
use Bio::GMOD::Blast::Graph::IntSpan;
use Bio::GMOD::Blast::Graph::MyUtils;
use Bio::GMOD::Blast::Graph::MyDebug qw( dmsg assert );
use Bio::GMOD::Blast::Graph::List;

@ISA = qw( Bio::GMOD::Blast::Graph::BaseObj );

my( $kSpan ) = Bio::GMOD::Blast::Graph::MyUtils::makeVariableName( "span" );

##################################################################
sub init {
##################################################################
    my( $self, $arg ) = @_;

    $self->{ $kSpan } = new Bio::GMOD::Blast::Graph::IntSpan $arg;

}

##################################################################
sub toString {
##################################################################
    my( $self ) = shift;

    return( $self->getSpan()->run_list );
}

##################################################################
sub getSpan {
##################################################################
    my( $self ) = shift;

    return( $self->{ $kSpan } );
}

##################################################################
sub addRegion {
##################################################################
    my( $self, $region ) = @_;

    assert( $self->disjointP($region) == 1, "illegal overlap",
        $self->getSpan()->run_list(), $region->run_list() );

    $self->{ $kSpan } = $self->getSpan()->union( $region );
}

##################################################################
sub getRegions {
##################################################################
    my( $self ) = shift;
    my( $runStr );
    my( @runs );
    my( $run );
    my( $region );
    my( $regionList );

    $regionList = new Bio::GMOD::Blast::Graph::List();

    $runStr = $self->getSpan()->run_list();
    @runs = split( /,/, $runStr );
    foreach $run ( @runs )
    {
    $region = new Bio::GMOD::Blast::Graph::IntSpan $run;
    $regionList->addElement( $region );
    }

    return( $regionList );

}

##################################################################
sub getIntersection {
##################################################################
    my( $self ) = shift;
    my( $otherSpan ) = shift;
    my( $bucketSpan );
    my( $iset );

    $bucketSpan = $self->getSpan();
    $iset = intersect $bucketSpan $otherSpan;

    return( $iset );
}

##################################################################
sub disjointP {
##################################################################
    my( $self ) = shift;
    my( $otherSpan ) = shift;
    my( $bucketSpan );
    my( $iset );
    my( $empty );
    my( $emptyP );

    $bucketSpan = $self->getSpan();
    $iset = $self->getIntersection( $otherSpan );

    if( empty $iset )
    {
    $emptyP = 1;
    }
    else
    {
    $emptyP = 0;
    }
    #dmsg( "disjointP():", $emptyP, $iset->run_list );

    return( $emptyP );
}

##################################################################
1;
##################################################################
