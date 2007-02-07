#!/usr/bin/perl
=head1 NAME nph-blast.pl

=head1 CREATED 

August 2003

=head1 AUTHOR 

Shuai Weng
shuai@genome.stanford.edu

=head1 DESCRIPTION

This script is a simple client interface for displaying the blast 
search form, running the blast search, and generating the search 
result. 

=cut

use strict;

use CGI qw/:all/;
use CGI qw/:html -nph/;
use CGI::Carp qw(fatalsToBrowser);
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;

use Bio::GMOD::Blast::Graph;
use Bio::GMOD::Blast::Util;

## Change this variable to point to your own location and the name 
## for the configuration file
my $CONF_FILE = '/share/dough/www-data_sgd/conf/Blast_gmod.conf';

########################################################################
select(stdout); 
$| = 1;  # to prevent buffering problems
########################################################################

my $title = 'BLAST Search';


########################################################################
my ($datasetDir, $seqtmp, $sequence, $program, $dataset, $options, 
    $filtering);

my (@program, %programLabel, %programType, @db, %dbLabel, %dbType, @matrix);

my ($blastBinDir, $blatBinDir, $blastOutputFile, %port, %host);

my ($imageDir, $imageUrl);

if (!param('sequence') && !param('filename')) {

    &printSearchForm;

}
else {

    &checkArgsAndDoSearch;

}

exit;

####################################################################
sub printSearchForm {
####################################################################

    &printStartPage;

    &setVariables;

    print &blastForm('#CCCCFF');
   
    print end_html;

}

####################################################################
sub checkArgsAndDoSearch {
####################################################################

    &printStartPage;

    #####################################################
    &setVariables;

    &checkParameters;

    #####################################################
    &createTmpSeqFile;

    &setOptions;

    #####################################################
    &runBlast;
    
    #####################################################
    &showGraph;

    #####################################################
    &showResult;
    
    #####################################################
 
    unlink($seqtmp);

    unlink($blastOutputFile);

    print end_html;

}

####################################################################
sub runBlast {
####################################################################

    unless ($program =~ /^blat/i) {

	if ($filtering) {

	    open(OUT, ">$blastOutputFile") ||
		die "Can't open '$blastOutputFile' for writing:$!";

	    print OUT "Filtering On\n";
	
	    close(OUT);

	}

    }

    my $cmd;

    if ($program =~ /^(blat|tblat)/i) {

	my $port = $port{$program}{$dataset};

	my $host = $host{$program}{$dataset};

	if ($program =~ /^blat/i) {

	    $cmd = "$blatBinDir/gfClient $host $port / $seqtmp -out=blast $blastOutputFile >> /dev/null 2>&1";
	
	}
	else {

	    $cmd = "$blatBinDir/gfClient $host $port / $seqtmp -out=blast -q=prot -t=dnax $blastOutputFile >> /dev/null 2>&1"

	}


    }
    else {

	$program = $blastBinDir.$program;
  
	$cmd = "$program $dataset $seqtmp $options -cpus=2 -progress=20 >> $blastOutputFile 2>&1";

    }

    my $err = system($cmd);

    if ($err) {

	print "Error occurred when running BLAST/BLAT program. See the following message:", p;

	print '<pre>';

	system("/usr/bin/cat $blastOutputFile");

	print '</pre>';

	exit;

    }
   

}

####################################################################
sub showGraph {
####################################################################

   my $graph = 
	  Bio::GMOD::Blast::Graph->new(-outputfile=>$blastOutputFile,
				       -dstDir=>$imageDir,
				       -dstURL=>$imageUrl);
			       

    $graph->showGraph;

  
}

####################################################################
sub showResult {
####################################################################

    print p, hr;

    my $in = new Bio::SearchIO(-format=>'blast',
			       -file=>$blastOutputFile,
			       -verbose=>0,
			       -signif=>0.1);

    my $result = $in->next_result;

    my $writer = new Bio::SearchIO::Writer::HTMLResultWriter;

    my $out = new Bio::SearchIO(-writer => $writer);

    
    eval { $out->write_result($result); };

    if ($@) {

	print "error=$@",p;

    }

}

#####################################################################
sub blastForm {
#####################################################################
# This method simply calls 'blastSearchBox' method to display the 
# popup menu for databases and search programs, and calls 
# 'blastSearchOptions' to display the options for the blast program. 

    my ($optionBg) = @_;

    $optionBg ||= 'white';

    return table({-width=>600,
		  -border=>0,
		  -rules=>'none',
		  -cellpadding=>0,
		  -cellspacing=>0},
		 Tr(td({-colspan=>2},
		       start_multipart_form)).
		 Tr(td({-colspan=>2},
		       &blastSearchBox)).
		 Tr(td({-colspan=>2},
		       &blastSearchOptions($optionBg))));


}

#####################################################################
sub blastSearchBox {
#####################################################################
# This method displays the popup menu for the blast search databases
# and search programs. You should update this method to include your
# database names and search programs.

    return b("Query Comment (optional, will be added to output for your use):").br.
	   textfield(-name=>'seqname',
		     -size=>60).p."\n".
	   b(font({-color=>'red'},
		"NOTE: If the input sequence is less than 30 letters you should change the default Cutoff Score value to something less than 100 or you can miss matches.")).p.
	    b("Upload Local TEXT File: FASTA, GCG, and RAW sequence formats are okay").br.
	    "WORD Documents do not work unless saved as TEXT.".
	    filefield(-name=>'filename',
		      -size=>60,
		      -accept=>"text/*").p."\n".
	    b("Type or Paste a Query Sequence : (No Comments, Numbers Okay)").br."\n".
	    textarea(-name=>'sequence',
		     -columns=>'80',
		     -rows=>'5',
		     -value=>"\n$sequence").p."\n".
	    b("Choose the Appropriate Search Program:").br.
	    popup_menu(-name=>'program',
		       -values=>\@program,
		       -labels=>\%programLabel).p."\n".
	    b("Choose a Sequence Database:").br.
	    popup_menu(-name=>'database',
		       -values=>\@db,
		       -labels=>\%dbLabel).br."\n".
	    submit(-value=>'Run BLAST').' or '.reset();


}

######################################################################
sub blastSearchOptions {
######################################################################
# This method is used to display the options for the blast search.

    my ($optionBg) = @_; 

    my $ncbiBlastHelp = 'http://www.ncbi.nlm.nih.gov/BLAST/blast_help.html';

    ######## output format 
    my @format = ('gapped', 'nongapped');

    my %formatLabel = ('gapped'=>'gapped alignments',
		       'nongapped'=>'nongapped alignments');

    my $formatDefault = 'gapped';

    ######## cutoff score 
    my @cutoff = ('default', '30', '50', '70', '90', '110');

    my $cutoffDefault = 'default';

    ######## word length 
    my @wordLength = ('default');

    for (my $i = 15; $i >= 2; $i--) {
	push(@wordLength, $i);
    }

    my $wordLengthDefault = 'default';

    ######## Expect threshold
    my @eValue = ('default', '0.0001', '0.01', '1', '10', '100', '1000');
    
    my $eValueDefault = 'default';

    ######## Number of best alignments to show
    my @alignNum = ('0', '25', '50', '100', '200', '400', '800', '1000');

    my $alignNumDefault = 100;
    
    ######## Sort output by 
#    my @sortBy = ('pvalue', 'count', 'highscore', 'totalscore');

#    my $sortByDefault = 'pvalue';

    return b('Options: ').
	   'For descriptions of BLAST options and parameters, refer to the '. 
	   a({-href=>$ncbiBlastHelp}, 
	     'BLAST documentation at NCBI.').p.
	   table({-bgcolor=>$optionBg,
		  -cellspacing=>0},
		 Tr(th({-align=>'left'},
		       'Output format :').
		    td(popup_menu(-name=>'output',
				  -values=>\@format,
				  -default=>$formatDefault,
				  -labels=>\%formatLabel)).
		    td(br)).
		 Tr(th({-align=>'left'},
		       'Comparison Matrix :').
		    td(popup_menu(-name=>'matrix',
				  -values=>\@matrix)).
		    td(br)).
		 Tr(th({-align=>'left'},
		       'Cutoff Score (S value) :').
		    td(popup_menu(-name=>'sthr',
				  -values=>\@cutoff,
				  -default=>\$cutoffDefault)).
		    td(br)).
		 Tr(th({-align=>'left'},
		       'Word Length (W value) :').
		    td(popup_menu(-name=>'wordlength',
				  -values=>\@wordLength,
				  -default=>\$wordLengthDefault)).
		    td('Default = 11 for BLASTN, 3 for all others')).
		 Tr(th({-align=>'left'},
		       'Expect threshold (E threshold) :').
		    td(popup_menu(-name=>'ethr',
				  -values=>\@eValue,
				  -default=>$eValueDefault)).
		    td(br)).
		 Tr(th({-align=>'left'},
		       'Number of best alignments to show :').
		    td(popup_menu(-name=>'showal',
				  -values=>\@alignNum,
				  -default=>$alignNumDefault)).
		    td(br)).
		 Tr(th({-align=>'left'},
		       'Filter options :').
		    td(radio_group(-name=>'filtop',
			     -values=>['On', 'Off'])).
		    td('DUST file for BLASTN, SEQ filter for all others')));

#		 Tr(th({-align=>'left'},
#		       'Sort output by :').
#		    td(popup_menu(-name=>'sortop',
#				  -values=>\@sortBy,
#				  -default=>\$sortByDefault))));

}

####################################################################
sub setVariables {
####################################################################

    open(CONF, "$CONF_FILE") ||
	die "Can't open '$CONF_FILE' for reading:$!";

    while(<CONF>) {
	
	if (/^\#/ || /^$/) { next; }

	chomp;

	my ($name, $value);

	if (/^([^\=]+) *= *(.+)$/) {

	    $name = $1;

	    $value = $2;
	    $value =~ s/^ *//;
	    $value =~ s/ *$//;

	}

	if ($name =~ /^tmpDir/i) {

	    $seqtmp = $value."blastseq.$$.tmp";
    
	    $blastOutputFile = $value."blast.$$.output";

	}
	elsif ($name =~ /^imageDir/i) {

	    $imageDir = $value;

	}
	elsif ($name =~ /^imageUrl/i) {

	    $imageUrl = $value;

	}
	elsif ($name =~ /^databaseDir/i) {

	    $datasetDir = $value;

	    $ENV{'BLASTDB'} = $value;

	}
	elsif ($name =~ /^database/i) {

	    my ($db, $type, $desc) = split(/=>/, $value);

	    push(@db, $db);

	    $dbType{$db} = $type;

	    $dbLabel{$db} = $desc;

        }
	elsif ($name =~ /^blastBinDir/i) {

	    $blastBinDir = $value;

	}
	elsif ($name =~ /^blatBinDir/i) {

	    $blatBinDir = $value;

	}
	elsif ($name =~ /^port/i) {

	    my ($port, $host, $program, $dataset) = split(/=>/, $value);

	    $port{$program}{$dataset} = $port;

	    $host{$program}{$dataset} = $host;

	}
	elsif ($name =~ /^program/i) {

	    my ($program, $type, $desc) = split(/=>/, $value);

	    push(@program, $program);

	    $programType{$program} = $type;

	    $programLabel{$program} = $desc;

	}
	elsif ($name =~ /^blastMAT/i) {

	    $ENV{'BLASTMAT'} = $value;

	}
	elsif ($name =~ /^matrix/i) {

	    push(@matrix, $value);

	}
	elsif ($name =~ /^blastFILTER/i) {
 
	    $ENV{'BLASTFILTER'} = $value;

	}

    }
    close(CONF);

    ############ 
    $program = param('program');
    $dataset = param('database');    

}

####################################################################
sub checkParameters {
####################################################################

    &checkDatabase;
    
    &checkSequence;

    &checkSeqLengthAndSvalue;

    &checkSeqLengthAndWordLength;
    
    &checkDatasetAndProgram;

    &checkProgramAndSeqlength;

}

####################################################################
sub createTmpSeqFile {
####################################################################

    my $seqname = param('seqname');

    $seqname .= "  (Length: ".length($sequence).")";

    Bio::GMOD::Blast::Util->createTmpSeqFile($seqtmp, $seqname, $sequence);

}

####################################################################
sub checkSeqLengthAndSvalue {
####################################################################
    
    if (param('sthr') ne "default" && param('sthr') < 60 && 
	length($sequence) > 100 ) {

	print "The maximum sequence length for an S value less than 60 is ",
	       b("100"),".", p,
	       "Return to the form to adjust either the S value or ",
               " sequence.",p;
    
	print end_html;

	exit;

    }

}

####################################################################
sub checkSeqLengthAndWordLength {
####################################################################

    if ($program eq "blastn" && param('wordlength') ne "default" && 
	param('wordlength') < 11 && length($sequence) > 10000) {

	print "The maximum sequence length for a word length of less than 11 is ", b("10000"), ".", p,
	      "Return to the form to adjust either the word length ",
	      "or sequence.",p;
	
	print end_html;

	exit;
    }

}


####################################################################
sub checkDatasetAndProgram {
####################################################################

    if ($dbType{$dataset} eq $programType{$program}) {

	return;

    }

    #### add your own checking code here to make sure 
    #### the selected blast search program matches the database.

    print "Your choice of Database (".b($dataset).") does not match the ",
          "choice of BLAST search program (".b($program).").",p,
	  "BLASTP and BLASTX require a protein sequence database and ",
	  "other BLAST programs require a nucleotide  sequence database. ",p,
	  "Return to the form and adjust either the program ",
          "or database selection.",p;
    
    print end_html;

    exit;

}

####################################################################
sub checkProgramAndSeqlength {
####################################################################
    
#    if (!param('email') && $program =~ /(tblastx|tblastn)/ &&
#	length($sequence) > 5001) {

#	print "The maximum sequence length for TBLASTN and TBLASTX ",
#              "is 5,000 bp unless the Email option is used.",p,
#	      "Return to the form and reduce the sequence length, ",
#	      "select the Email option or choose another BLAST program.";

#        print end_html;
    
#        exit;

#    }

}

####################################################################
sub checkEmail {
####################################################################
    
    if (!param('email')) { return; }

    if (!Bio::GMOD::Blast::Util->validateEmail(param('email'))) {

	print "You requested that the results be sent to your e-mail ",
	      "account. However, your email address is missing, ",
	      "appears incomplete, or does not contain a valid hostname.",p,
	      "You entered this email address: ".b(param('email')),p,
	      "Please return to the form and check that your email address ",
	      "is correct.",p;

	print end_html;
    
	exit;

    }

}

####################################################################
sub setOptions {
####################################################################
    
    return if ($program =~ /blat/i);

    $options = &blastOptions($program, length($sequence));

    if (param('sortop') && param('sortop') ne "pvalue") { 

	$options .= " -sort_by_".param('sortop'); 

    }
    if (param('ethr') && param('ethr') ne "default") {

	$options .= " E=".param('ethr');

    }
    if (param('sthr') && param('sthr') ne "default") {

	$options .= " S=".param('sthr');

    }
    $options .= " B=".param('showal')." V=".param('showal');

    if (param('output') ne "gapped") { $options .= " -nogap"; }

    if ($program ne "blastn" && param('matrix') ne "BLOSUM62") { 

	$options .= " -matrix=".param('matrix'); 

    }

    if (param('wordlength') ne "default") { 

	$options .= " -W=".param('wordlength');

    }

    if (param('filtop') =~ /^on/i) {
    
	$filtering = 1;
 
	if ( $program ne "blastn" ) {

	    $options .= " -filter=seg";

	} 
	else {
		
	    $options .= " -filter=dust";
	
	}
	  
    } 
    else {
    
	$filtering = 0;

    }

}

#######################################################################
sub blastOptions {
#######################################################################
    my ($program, $seqlen) = @_;

    return if ($program =~ /^blat/i);

    my $hspmax;
    my $gapmax;

    if ( $seqlen < 10000 ) {

	if ($program eq "blastn") {

	    $hspmax = 6000;

	    $gapmax = 3000;

	} 
	else {

	    $hspmax = 2000;

	    $gapmax = 1000;

	}
    } 
    else {

	$hspmax = 10000;

	if ($program eq "blastn") {

	    $gapmax = 3000;

	} 

	else {

	    $gapmax = 1000;
	}
    }

    return " -hspsepsmax=" . $hspmax . " -hspsepqmax=" . $hspmax . " -gapsepsmax=" . $gapmax . " -gapsepqmax=" . $gapmax . " ";

}
		
####################################################################
sub checkDatabase {
####################################################################
    
    if (param('database') eq '-') {

	print b("No Database Selected."),p;

	print "Please return to the form and select a database.",p;

	print end_html;

	exit;

    }

    my $datasetLockFile = $datasetDir.param('database').".update";

    if (-e "$datasetLockFile") {

	print b("SORRY the ".param('database')." dataset is currently being UPDATED. Please try again in a few minutes or select another dataset."),p;
	
	print end_html;

	exit;

    }

}

####################################################################
sub checkSequence {
####################################################################

    my $filehandle = upload('filename');

    if ($filehandle) {

	while (<$filehandle>) {

	    $sequence .= $_;
	}
       
    }
    else { $sequence = param('sequence'); }

    Bio::GMOD::Blast::Util->deleteUnwantedCharFromSequence(\$sequence);

    if (!$sequence) {

	print b("No Sequence Provided."),p;
	  
	print "Please return to the form and enter a sequence.",p;

	print end_html;

	exit;

    }

}

####################################################################
sub printStartPage {
####################################################################
   
    print header;

    print start_html(-title=>$title);

    print center(h2($title)), hr;

    if (param('program') =~ /^(blat|tblatn)$/i) {

 	print center('If there are no hits found using BLAT/TBLATN'.br.'the remainder of this page will be blank.'), hr({-width=>'20%'});

    }


    
}

####################################################################
# sub writeLog {
####################################################################
#    my ($Cuser, $Csystem) = @_;

#    if (param('email')) { return; }
 
#    Bio::GMOD::Blast::Util->writeLog($program, $dataset, $options, 
#                   $Cuser, $Csystem, length($sequence), $remoteLink);
		      
# }

####################################################################








