#!/usr/bin/perl -w
# Reads data from serial port and posts to emoncms


# Run apt-get install libdevice-serialport-perl
# if you ger "Can't locate device/SerialPort.pm in @INC (@INC includes ..."


# use lib '/usr/lib/perl5/Device'
# sudo apt-get install libwww-mechanize-perl

#To install Proc:Daemon
#perl -MCPAN -e 'install Proc::Daemon' OR sudo apt-get install libproc-daemon-perl 

# Martin Harizanov
# http://harizanov.com


# Declare the subroutines
sub trim($);


BEGIN {
        push @INC,"/usr/lib/perl5/";
        }

use strict;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use WWW::Mechanize;
use Time::localtime;
use Scalar::Util 'looks_like_number'; 
use Proc::Daemon;

print "Serial to EmonCMS gateway for RaspberryPi with TinySensor\r\n";

my $PORT = "/dev/ttyAMA0";

my $ob = Device::SerialPort->new($PORT);
$ob->baudrate(9600); 
$ob->parity("none"); 
$ob->databits(8); 
$ob->stopbits(1); 
#$ob->handshake("xoff"); 
$ob->write_settings;

#Configure the TinySensor
$ob->write("\r\n");
$ob->write("22i");   #Node ID=22
sleep 2;
$ob->write("8b");    #868Mhz
sleep 2;
$ob->write("210g");  #Group=210
sleep 2;


open(SERIAL, "+>$PORT");

my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

while ($continue) {
       my $line = trim(<SERIAL>);
	print $line; print "\r\n";
       my @values = split(' ', $line);
       my $bindata;
       if(looks_like_number($values[0]) && $values[0] >=1 && $values[0]<=26) {

          $bindata="";
          for(my $j=1; $j<@values; $j++) {
            $bindata.=sprintf ("%.2x",$values[$j]);
	  }
	  #print $bindata . "\r\n";       
	  $bindata=pack("H*",$bindata);

	  #Example of decoding packet content for nodes 17 and 18
          if($values[0]==18 || $values[0]==17) {
	          my($temperature, $battery) = unpack("ss",$bindata);
		  $temperature /=100;
		  print "Temperature $temperature\n";
		  print "Battery $battery\n";
	  }

	  #Example of decoding packet content for node 10
          if($values[0]==10) {
	          my($realpower, $apparentpower, $vrms, $powerfactor, $irms) = unpack("ssssf",$bindata);
		  print "Real power: $realpower W Apparent Power: $apparentpower W VRMS: $vrms V Power Factor: $powerfactor IRMS: $irms \n\r";
	  }

          my $msubs ="";
          for(my $i=1; $i<@values; $i+=2){
            $msubs .= $values[$i] + $values[$i+1]*256;
            if($i!=@values-2) {$msubs .= ","}; }
 	  }
          post2emoncms($values[0],$msubs);

	  my $hour=localtime->hour();
          my $min=localtime->min();
          $ob->write("$hour,00,$min,00,s\r\n");
	  sleep(2);
       }
}

sub post2emoncms {

my $ua = WWW::Mechanize->new();
my $url = "http://127.0.0.1/emoncms3/api/post?apikey=23338d373027ce83b1f81b9e9563b629&node=" . $_[0] ."&csv=" . $_[1];
#print $url; print "\r\n";
my $response = $ua->get($url);
if ($response->is_success)
{
#print "Success!\n";
#my $c = $ua->content;
#print ("$c");
}
else
{
#print "Failed to update emoncms!";
#die $response->status_line;
}

}


# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
#
