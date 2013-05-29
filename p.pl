#!/usr/bin/env perl
# This script will retrieve pressure value and then print out it.
# I assume that the communication line is I2C and the sensor is
# http://www.freescale.com/files/sensors/doc/app_note/AN3785.pdf
#
# An application of this script is a munin plugin.
#
# To enable this script as a munin plugin, 
# You need to put the following lines in "/etc/munin/plugin-conf.d/munin-node"
# [pressure]
# user pi
#
# Error handling may not be sufficient.
use strict;
my $verbose=0;

# retrieve values from I2C device
echosys("gpio load i2c");
echosys("i2cset -y 1 0x60 0x12 0x01");
my @ret=split(/[\s]+/,`i2cdump -y 1 0x60 i | grep 00: `);
@ret=@ret[1..16];
print STDERR @ret if $verbose;
print STDERR "\n" if $verbose;

# then process a data packet to show actual pressure value
my $padc= getadc(@ret[0,1]);
my $tadc= getadc(@ret[2,3]);

my $a0=convcoef(@ret[4,5],1,13,16,0);
my $b1=convcoef(@ret[6,7],1,3,16,0);
my $b2=convcoef(@ret[8,9],1,2,16,0);
my $c12=convcoef(@ret[10,11],1,2,16,9);
my $c11=convcoef(@ret[12,13],1,1,11,12);
my $c22=convcoef(@ret[14,15],1,1,11,16);
print STDERR "$a0 $b1 $b2 $c12 $c11 $c22\n" if $verbose;

my $pcomp = $a0+($b1+$c11*$padc+$c12*$tadc)*$padc+($b2+$c22*$tadc)*$tadc;
printf( "%7.2lf\n",$pcomp);

sub convcoef {
	# convert bits to coefficient of AN3785
	# padbit must be added 1 when not zero
	my ($uw,$lw,$signbit,$digibit,$decimalbit,$padbit) = @_;
	my $bit = (hex($uw)<<8)|hex($lw);
	printf( STDERR "bit = %s %s %d\n", $uw, $lw, $bit) if $verbose;
	my $sign=1;
	my $digit=extractbit($bit,$signbit,$digibit);
	my $decimal=extractbit($bit,$digibit,$decimalbit);
	printf( STDERR "dec = %d\n", $decimal) if $verbose;
	my $tmpbit = $digit<<($decimalbit-$digibit)|$decimal;
	if(extractbit($bit,0,$signbit)&1) {
		$sign=-1;
		my $mask = ~(0xFFFF<<($decimalbit-$signbit))&0xFFFF;
		$tmpbit = (~$tmpbit | 1) & $mask;
	}
	my $result = $sign*($tmpbit*2.**(-($decimalbit-$digibit+$padbit)));
	
	print STDERR "$result\n" if $verbose;

	return $result;
}

sub extractbit {
	# internal subroutine for convcoef
	my ($bit,$stx,$etx) = @_;
	my $result=0;
	printf( STDERR "%d, %d\n2nd: ", $stx, $etx) if $verbose;
	for(my $i=$stx;$i<$etx;$i++) {
		my $j=$i-$stx;
		$result|=(($bit&(1<<(15-$i)))?1:0)<<($etx-($i+1));
		printf( STDERR "%d", (($bit&(1<<(15-$i)))?1:0)) if $verbose;
	}
	printf( STDERR "\n%d\n", $result) if $verbose;
	return $result;
}

sub getadc {
	# read 16bit value from given 2 characters
	return hex($_[0])<<2^(hex($_[1])&0x3);
}

sub echosys {
	print STDERR "@_\n" if $verbose;
	system(@_);
}
