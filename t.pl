#!/usr/bin/perl
$verbose=0;
$pathtow1="/sys/bus/w1/devices/w1_bus_master1/";
if ( $ARGV[0] =~/-v/ ) {
	print "verbose\n";
	$verbose=1;
}
$mods = `cat /proc/modules`;
if ($mods =~ /w1_gpio/ && $mods =~ /w1_therm/)
{
	print "w1 modules already loaded \n" if($verbose);
}
else 
{
	print "loading w1 modules \n" if $verbose;
	$mod_gpio = `sudo modprobe w1-gpio`;
	$mod_them = `sudo modprobe w1-therm strong_pullup=0`;
}

opendir DIR, $pathtow1;
@dir=readdir( DIR );
close DIR;
@devices=grep(/.+-.+/,@dir);

foreach my $device ( @devices ) { 
	for (my $i=0;$i<5;$i++) {
		$sensor_temp = `cat $pathtow1/$device/w1_slave 2>&1`;
		if ($sensor_temp =~ /No such file or directory/) {
			next;
		}
		if ($sensor_temp =~ /NO/) {
			next;
		}

		$sensor_temp =~ /t=(\d+)/i;
		$tempreature = (($1/1000));

		printf( "%s = %6.3lf\n", $device, $tempreature); 
		last;
		sleep(0.1);
	}
}
# die "Error locating sensor file or sensor CRC was invalid";


