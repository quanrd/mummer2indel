use strict;
use warnings;
use Getopt::Long;

my($mmpfile,$regionlist,$outfile) = @ARGV;

my $usage = "USAGE:\nperl $0 <minimap output> <region list> <output file>\n";
$usage .= "<region list> is a list of regions, containing four columns: CHR START END.\n";

die $usage unless(@ARGV == 3);

my %hash_region;
my %hash_t;

open(IN,"cat $regionlist|sort -k1,1 -k2,2n -k3,3n|") or die $!;

while(<IN>){
	chomp;
	my($chr,$start,$end,@others) = split/\t/;
	next unless($start =~ /^\d+$/ and $end =~ /^\d+$/);
	next unless($end - $start + 1 > 0);
	$hash_region{$chr}{$start}{$end}{covered} = 0;
}
close IN;

open(IN,"<$mmpfile") or die $!;
while(<IN>){
	chomp;
	my($query,$qlen,$qstart,$qend,$strand,$target,$tlen,$tstart,$tend,$match,$blocklen,@others) = split/\t/;
	unless(exists $hash_t{$target}){
		$hash_t{$target}{length} = $tlen;
	}
	#push @{$hash_t{$target}{covered_ctg}{$tstart}}, $query;
	if(exists $hash_t{$target}{covered}{$tstart}){
		next if($hash_t{$target}{covered}{$tstart} > $tend);
	}
	$hash_t{$target}{covered}{$tstart} = $tend;
}
close IN;

foreach my $target(sort keys %hash_t){
	my @starts = sort {$a <=> $b} keys %{$hash_t{$target}{covered}};
	my $tlen = $hash_t{$target}{length};
	my $tcovered = 0;
	
	for(my $i = 0; $i < @starts; $i++){
		for(my $j = $i+1; $j < @starts; $j++){
			my $starti = $starts[$i];
			my $endi = $hash_t{$target}{covered}{$starti};
			my $startj = $starts[$j];
			my $endj = $hash_t{$target}{covered}{$startj};
			if($startj > $endi + 1){
				splice(@starts, $i, 1);
				$i--;
				last;
			}
			# merge two blocks into one
			#push @{$hash_t{$target}{covered_ctg}{$starti}}, @{$hash_t{$target}{covered_ctg}{$startj}};
			if($endj > $endi){
				$endi = $endj;
				$hash_t{$target}{covered}{$starti} = $endj;
			}
			delete($hash_t{$target}{covered}{$startj});
			splice(@starts, $j, 1);
			$j--;
		}
	}
}

foreach my $target(keys %hash_region){
	unless(exists $hash_t{$target}){
		print "# ERROR: chr:$target does not exist in the minimap result.\n";
		next;
	}
	my @starts = sort {$a <=> $b} keys %{$hash_t{$target}{covered}};
	foreach my $start(sort {$a <=> $b} keys %{$hash_region{$target}}){
		foreach my $end(sort {$a <=> $b} keys %{$hash_region{$target}{$start}}){
			for(my $i = 0; $i < @starts; $i++){
				my $covstart = $starts[$i];
				my $covend = $hash_t{$target}{covered}{$covstart};
				if($covend < $start){
					splice(@starts, $i, 1);
					$i--;
					next;
				}
				if($covstart > $end){
					last;
				}
				my($overlap,$type) = overlapper($covstart,$covend,$start,$end);
				$hash_region{$target}{$start}{$end}{covered} += $overlap;
				#print "$overlap\t$type\t$covstart\t$covend\t$start\t$end\t".join(",",@{$hash_t{$target}{covered_ctg}{$covstart}})."\n";
			}
		}
	}
}

open(OUT,">$outfile");
foreach my $chr(sort keys %hash_region){
	foreach my $start(sort {$a <=> $b} keys %{$hash_region{$chr}}){
		foreach my $end(sort {$a <=> $b} keys %{$hash_region{$chr}{$start}}){
			my $len = $end - $start + 1;
			my $covratio = $hash_region{$chr}{$start}{$end}{covered}/$len;
			print OUT "$chr\t$start\t$end\t$covratio\n";
		}
	}
}
close OUT;

sub overlapper{
	my($start1,$end1,$start2,$end2) = @_;
	my $overlap = 0;
	my $type = 0;
	# -1 for no overlap; 0 for overlap ; 1 for the first region contains the second region; 2 for the second region contains the first region
	if($end1 < $start2 or $end2 < $start1){
		$type = -1;
	}elsif($end1 <= $end2 and $start1 >= $start2){
		$type = 2;
		$overlap = $end1 - $start1 + 1;
	}elsif($end2 <= $end1 and $start2 >= $start1){
		$type = 1;
		$overlap = $end2 - $start2 + 1;
	}elsif($end1 >= $end2){
		$type = 0;
		$overlap = $end2 - $start1 + 1;
	}elsif($end1 <= $end2){
		$type = 0;
		$overlap = $end1 - $start2 + 1;
	}
	return($overlap,$type);
}
