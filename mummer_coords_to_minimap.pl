use strict;
use warnings;

my($infile,$outfile) = @ARGV;

my $usage = "USAGE:\nperl $0 <input file> <output file>\n";
$usage .= "Convert mummer tab coords format to minimap output format.\n";

die $usage unless(@ARGV == 2);

open(IN,"<$infile") or die $!;
open(OUT,">$outfile");
while(<IN>){
	chomp;
	next unless($_ =~ /^\d+/);
	# [S1]    [E1]    [S2]    [E2]    [LEN 1] [LEN 2] [% IDY] [LEN R] [LEN Q] [COV R] [COV Q] [TAGS]
	my($tstart,$tend,$qstart,$qend,$tblock,$qblock,$identity,$tlen,$qlen,$tcover,$qcover,$target,$query) = split/\t/;
	my $block = $qblock;
	if($tblock > $qblock){
		$block = $tblock;
	}
	my $match = int($block * $identity / 100);
	
	my $strand = "+";
	if($qstart > $qend){
		$strand = "-";
		#my $qstart_new = $qlen - $qstart + 1;
		#my $qend_new = $qlen - $qend + 1;
		my $qstart_new = $qend;
		my $qend_new = $qstart;
		$qstart = $qstart_new;
		$qend = $qend_new;
	}
	print OUT "$query\t$qlen\t$qstart\t$qend\t$strand\t$target\t$tlen\t$tstart\t$tend\t$match\t$block\n";
}
close IN;
close OUT;