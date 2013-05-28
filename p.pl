#!/usr/bin/env perl
# http://www.freescale.com/files/sensors/doc/app_note/AN3785.pdf
# to add this script as a munin plugin, 
# put the following in "/etc/munin/plugin-conf.d/munin-node"
# [pressure]
# user pi
use strict;
my $verbose=0;

#echosys("gpio load i2c");
echosys("i2cset -y 1 0x60 0x12 0x01");
my @ret=split(/[\s]+/,`i2cdump -y 1 0x60 i | grep 00: `);
@ret=@ret[1..16];
print @ret if $verbose;
print "\n" if $verbose;

my $padc= getadc(@ret[0,1]);
my $tadc= getadc(@ret[2,3]);

my $a0=convcoef(@ret[4,5],1,13,16,0);
my $b1=convcoef(@ret[6,7],1,3,16,0);
my $b2=convcoef(@ret[8,9],1,2,16,0);
my $c12=convcoef(@ret[10,11],1,2,16,9);
my $c11=convcoef(@ret[12,13],1,1,11,11);
my $c22=convcoef(@ret[14,15],1,1,11,15);

my $pcomp = $a0+($b1+$c11*$padc+$c12*$tadc)*$padc+($b2+$c22*$tadc)*$tadc;
printf( "%7.2lf\n",$pcomp);


sub convcoef {
	# convert bits to coefficient of AN3785
	my ($uw,$lw,$signbit,$digibit,$decimalbit,$padbit) = @_;
	my $bit = (hex($uw)<<8)|hex($lw);
	printf( "bit = %s %s %d\n", $uw, $lw, $bit) if $verbose;
	my $sign=extractbit($bit,0,$signbit)&1?-1:1;
	my $digit=extractbit($bit,$signbit,$digibit);
	my $decimal=extractbit($bit,$digibit,$decimalbit);
	printf( "dec = %d\n", $decimal) if $verbose;
	my $result = $sign*($digit+$decimal*2.**($digibit-$decimalbit))*10**(-$padbit);
	
	print "$result\n" if $verbose;

	return $result;
}

sub extractbit {
	# internal subroutine for convcoef
	my ($bit,$stx,$etx) = @_;
	my $result=0;
	printf( "%d, %d\n", $stx, $etx) if $verbose;
	for(my $i=$stx;$i<$etx;$i++) {
		my $j=$i-$stx;
		$result|=(($bit&(1<<(15-$i)))?1:0)<<($etx-($i+1));
		printf("%d", (($bit&(1<<(15-$i)))?1:0)) if $verbose;
	}
	printf("\n%d\n", $result) if $verbose;
	return $result;
}

sub getadc {
	return hex($_[0])<<2^(hex($_[1])&0x3);
}

sub echosys {
#	print "@_\n";
	system(@_);
}
