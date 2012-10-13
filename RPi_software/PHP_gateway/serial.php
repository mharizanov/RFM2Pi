<?php

function microtime_float()
{
        list($usec, $sec) = explode(" ", microtime());
        return ((float)$usec + (float)$sec);
}

function post2emoncms($json)
{

        $url = "/emoncms3/api/post?apikey=ae903ccd020f6b05f94cb6f7ca86bd93&json=" . $json;
        echo $url;
        echo "\r\n";
        getcontent("127.0.0.1",80,$url);
}

function getcontent($server, $port, $file)
{
   $cont = "";
   $ip = gethostbyname($server);
   $fp = fsockopen($ip, $port);
   if (!$fp)
   {
       return "Unknown";
   }
   else
   {
       $com = "GET $file HTTP/1.1\r\nAccept: */*\r\nAccept-Language: de-ch\r\nAccept-Encoding: gzip, deflate\r\nUser-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)\r\nHost: $server:$port\r\nConnection: Keep-Alive\r\n\r\n";
       fputs($fp, $com);
/* Don't realy need to fetch output as it slows us down
       while (!feof($fp))
       {
           $cont .= fread($fp, 500);
       }
*/	   
       fclose($fp);
//       $cont = substr($cont, strpos($cont, "\r\n\r\n") + 4);
//       return $cont;
   }
}



include "php_serial.class.php";

// Let's start the class
$serial = new phpSerial;
$serial->deviceSet("/dev/ttyAMA0");
$serial->confBaudRate(9600);
$serial->confParity("none");
$serial->confCharacterLength(8);
$serial->confStopBits(1);
$serial->confFlowControl("none");
// We may need to return if nothing happens for 10 seconds
//stream_set_timeout($serial->_dHandle, 10);

// Then we need to open it
//$serial->deviceOpen();
//$serial->sendMessage("210g");
//$serial->sendMessage("7i");
//$serial->sendMessage("8b");



echo ("Started..\r\n");

while(1) {

$serial->deviceOpen();


// Or to read from
$read = '';
$theResult = '';
$start = microtime_float();

//1 second limit to read
while ( ($read == '') && (microtime_float() <= $start + 1)) {
        $read = $serial->readPort();
        if ($read != '') {
                $theResult .= $read;
                $read = '';
        }
}

$serial->deviceClose();
if ($theResult =='') echo ".";
//raw packet data
echo($theResult);

$que = trim( $theResult);
$binarydata = "";
$valores=explode( " ", $que );
for ( $i=0; $i<count( $valores ) ; $i++) {
    $binarydata.=   str_pad(dechex( $valores[$i] ),2,'0',STR_PAD_LEFT) ;
}
$bin_str = pack("H*" , $binarydata);
//Decode data from known sources

//Elecrticity meter
if($valores[0]==10) {
	$array = unpack("CnodeID/vrealPower/vapparentPower/vVrms/vpowerFactor/fIrms", $bin_str);
	echo "Electricity meter packet received..\r\n";
	$json = json_encode($array);
	post2emoncms($json);
	//echo $json;
}

//remote temperature sensors
if( $valores[0]==7) {
	$array = unpack("CnodeID/vTemp1/vVoltage/vTemp2", $bin_str);
	echo "Temperature packet received..\r\n";
	$json = json_encode($array);
	post2emoncms($json);
}
//remote temperature sensors
if( $valores[0]==11) {
        $array = unpack("CnodeID/vTemp11/vVoltage/vTemp12", $bin_str);
        echo "Temperature packet received..\r\n";
        $json = json_encode($array);
        post2emoncms($json);
}

//Time sender NanodeRF
if($valores[0]==15) {
        $array = unpack("CnodeID/vHour/vMin/vSec", $bin_str);
	echo ("Time packet received");
        //echo json_encode($array);
        //echo("\r\n");
}






//while
}
$serial->deviceClose();
?>
