use strict;
use warnings;

my($in) = @ARGV;

my $usage = "USAGE:\nperl $0 <minimap format file>\n";

die $usage unless(@ARGV == 1);

my %hash_target;
my $targetLength = 0;
my $targetCover = 0;

open(IN,"<$in") or die $!;
while(<IN>){
	chomp;
	my($query,$qlen,$qstart,$qend,$strand,$target,$tlen,$tstart,$tend,$match,$blocklen,@others) = split/\t/;
	unless(exists $hash_target{$target}){
		$hash_target{$target}{length} = $tlen;
		$targetLength += $tlen;
	}else{
		die "#ERROR: Wrong target length.\n" if($hash_target{$target}{length} != $tlen);
	}
	if(exists $hash_target{$target}{cover}{$tstart}){
		next if($hash_target{$target}{cover}{$tstart} >= $tend);
	}
	$hash_target{$target}{cover}{$tstart} = $tend;
}
close IN;

foreach my $target(sort keys %hash_target){
	my $len = $hash_target{$target}{length};
	my @starts = sort {$a <=> $b} keys %{$hash_target{$target}{cover}};
	for(my $i = 0; $i < @starts; $i++){
		my $start = $starts[$i];
		my $end = $hash_target{$target}{cover}{$start};
		for(my $j = $i+1; $j < @starts; $j++){
			my $start_ = $starts[$j];
			my $end_ = $hash_target{$target}{cover}{$start_};
			last if($start_ > $end);
			if($end_ > $end){
				$end = $end_;
				$hash_target{$target}{cover}{$start} = $end;
			}
			delete($hash_target{$target}{cover}{$start_});
			splice(@starts, $j, 1);
			$j--;
		}
	}
	my $cover = 0;
	my $ratio = 0;
	foreach my $start(@starts){
		$cover += $hash_target{$target}{cover}{$start} - $start + 1;
	}
	$targetCover += $cover;
	$ratio = $cover/$len;
	print "$target\t$len\t$cover\t$ratio\n";
}

my $targetRatio = $targetCover/$targetLength;
print "All\t$targetLength\t$targetCover\t$targetRatio\n";
 
