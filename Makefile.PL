use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
	      'NAME'		=> 'Blast-GraphicView',
	      'VERSION_FROM'	=> 'VERSION', 
	      ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
	       (ABSTRACT        => 'A collection of modules for creating BLAST search Graphic',
		AUTHOR          => 'Shuai Weng <shuai@genome.stanford.edu>') : ()),
	      );


