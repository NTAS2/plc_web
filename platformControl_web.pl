#!/usr/bin/perl
# The aim of the script is to Query the controller for experimental configuration; If an experimental configuration is found, it would execute else it would sleep for 30 seconds and query again. 

use IO::Socket;
use Sys::Hostname;
use Getopt::Long;
use MIME::Base64;
use HTTP::Request::Common;
use LWP::Simple;

if ( ($#ARGV + 1) != 1) {
    print Timestamp() . " Default config: plc.conf\n";
    do "plc.conf";
} else {
    print Timestamp() . "Using " . $ARGV[0] . " as config.\n";
    do "$ARGV[0]";
}
if (! defined $server_ipaddress) {
    print Timestamp() . "Im missing some serious shit; fix it!\n";
    exit(1);
}


$platform = 'ndef' ; # Platform, used for running the traffic generators ( Sikuli in mma) # Option3
$URLbase="http://$server_ipaddress/ntas/api";

print Timestamp() . "Syslog to $server_ipaddress.\n";
if ( -e $pidfile) { 
	#PID do exist..
	open(PID,"$pidfile");
	$timest=<PID>;
	close(PID);
	if( (time-$timest)>3600 ) {
		print "pC.$platform Process ID file found, but not written for an hr.";
	} else {
		#OK
		print "Process exist?\n";
		exit(1);
	}
}
print Timestamp(). "Starting.\n";
updatePID($pidfile);

$SIG{'INT'} = 'INT_handler';

my $host = hostname();
print Timestamp() . " No Host type specified, assumes that platform is detectable via name.\n";
$host = "CUSTOM";
$platform = hostname();
print Timestamp() . " host      : $host \n";
print Timestamp() . " platform  : $platform \n";
print Timestamp() . " server    : $URLbase  \n";

for ($i = 0 ; $i > -1; $i++){ 
	if($i!=0){
		print Timestamp() . "\tUpdatePID and sleep 30s.\n";
		updatePID($pidfile);
		sleep (30);
		print Timestamp() . "\tSleept.\n";
	}
	
	# Inform server QUERY
    $exp_id = 0;
	$run_id = 0;
	$uri="$URLbase/query.php?keyid=$myKEY&platform=$platform";
	print Timestamp() . "\tSending message> QUERY.\n";
	print Timestamp() . "\t$uri\n";
	$reply=get "$uri";
	chomp($reply);
	print Timestamp() . "\tResponse:  $reply \n";
	if( $reply !~/PROCEED/){
		close($socketreceiver); 
		next;
	} 
	print Timestamp() . "\tMoving on. \n";
	waitforconfig ($URLbase,$myKEY,$platform);
	# wait for reply 
	if($socketreceiver!=0){
	    print "Sending BYE!\n";
	    informHost ($socketreceiver, "BYE");
	    close($socketreceiver); 
	}

	# if reply is NOINFORMATION  sleep (60) else execute a subroutine
	
 }
$pidfile->remove;
exit(1);

# Sub_routines ( note the subroutine is slightly modified than original one)
sub informHost{
	my ($SAC,$message) = @_;
	print Timestamp() . "Sending...\n";
	print $SAC "$platform;$message\n";
	print Timestamp() . "Sent...\n";
}

  

sub waitforconfig {
	my ($URLbase,$myKEY,$platform) = @_;

	$uri="$URLbase/configuration.php?keyid=$myKEY&platform=$platform";
	print Timestamp() . "\tSending message> CONFIG.\n";
	print Timestamp() . "\t$uri\n";
	$reply=get "$uri";
	@replyline = split(/\R/,$reply);
	
	foreach $line (@replyline) {
	 #print Timestamp() . " $line \n";
	 chomp($line);
	 if ($line=~ /CONFIG/) {  
		print Timestamp() . " $line \n";
		@args = split (/,/,$line);
		$exp_id = $args[1];
		$run_id = $args[2];
		$key_id = $args[3];
		$total_run_id = $args[4];
		$application_command = decode_base64($args[5]); 
		$temp = $application_command; 
	#debug 
		printf Timestamp() . " Expid= $exp_id Runid=$runid Key_id = $key_id , Total Runs = $total_run_id";
		printf Timestamp() . " Application command is $application_command\n";
		$application_commandNew = eval('$application_command');
#		printf "CURRENT Line= $application_command\n";
#		printf "NEW calling = $application_commandNew\n";
		$ENV{EXPID} = $exp_id;
		$ENV{RUNID} = $run_id;	

	  if ($args[1] == 0) {
		last line;  
	  }

	  print Timestamp() . "Entering Parsing \n";


#Each Section may require adaptation to work on given platform. 
	 if ( $application_command =~ /SIKULI/ )  {
		@siks = split (' ', $application_command);
		$sikuli_file_name = $siks[1]; 
		$ENV{EXPID} = $exp_id;
		$ENV{RUNID} = $run_id;
		#WINDOWS
		if ($platform =~  /Windows/) {
			$application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\project\\Documents\\sikuli\\$sikuli_file_name\" --args ");
			for ($i = 2 ; $i < @siks ; $i++) {
				$t = $siks[$i];
				$application_command = "$application_command"."$t ";
			}
		}
	#MAC
		if ($platform =~  /Mac/) {
			$application_command = sprintf ("/Applications/Sikuli-IDE.app/sikuli-ide.sh -r /Users/com/Documents/sikuli/$sikuli_file_name --args ");
			for ($i = 2 ; $i < @siks ; $i++) {
				$t = $siks[$i];
				$application_command = "$application_command"."$t ";
			}
		print "We are in $platform case\n";
 		print "$application_command"."\n";
		}
	#LINUX
		if ($platform =~  /Linux/) {
			$application_command = sprintf ("/home/com/Sikuli/Sikuli-IDE/sikuli-ide.sh -r /home/com/Sikuli_scripts/$sikuli_file_name --args ");
			for ($i = 2 ; $i < @siks ; $i++) {
				$t = $siks[$i];
				$application_command = "$application_command"."$t ";
			}
		}
	#Android
		if ($platform =~  /Android/) {
			$application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\Android_$sikuli_file_name\" --args ");
			for ($i = 2 ; $i < @siks ; $i++) {
				$t = $siks[$i];
				$application_command = "$application_command"."$t ";
			}
		}
	#IPhone
		if ($platform =~  /IPhone/) {
			$application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\IPhone_$sikuli_file_name\" --args ");
			for ($i = 2 ; $i < @siks ; $i++) {
				$t = $siks[$i];
				$application_command = "$application_command"."$t ";
			}
		}	
		
	#WinMobile
		if ($platform =~  /WinMobile/) {
			$application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\WinMobile_$sikuli_file_name\" --args ");
			for ($i = 2 ; $i < @siks ; $i++) {
				$t = $siks[$i];
				$application_command = "$application_command"."$t ";
			}
		}	

	}
	my $execstr = sprintf ("$application_command");
	
	print "\nToEXECUTE->$execstr|\n";
	  if ($platform =~  /Windows/ ){
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif ($platform =~  /Android/) { 
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif ($platform =~  /IPhone/) { 
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif ($platform =~  /WinMobile/){ 
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } else { #DEFAULT; should work on Linux and Mac.
	      open PS, "$execstr 2>&1|" or print "Can't open STDOUT: $!"
	  }; #2>&1|
	  my $response="CRAP";
	  my $bigSTDOUTlog="";
	  while(my $myIn=<PS>){
	      print $myIn;
	      $bigSTDOUTlog.=$myIn;
	      if($myIn=~/SUCCESS/){
		  $response = "SUCCESS";
		  #	  last line;
	      } #End of If
	      if($myIn=~/FAILURE/){
		  $response = "FAILURE";
		  #	  last line;
	      }
	      
	  } #End of While
	  close PS;
	  #Make sure that the environment does not retain a exp/run id.
	  $ENV{EXPID} = 0;
      $ENV{RUNID} = 0;	
	  print Timestamp() . "$platform PCSENDERDONE\nToServer:$response\n";
	  $x = "";
	  @std = split (/\n/,$bigSTDOUTlog);
		for ($i = 0 ; $i < @std ; $i++) {
		$t = $std[$i];
		$x = "$x"."GGGGGG$t ";
		}
		$xx =encode_base64($x,"");
		$app = encode_base64($temp,""); 
		
		$uri="$URLbase/result.php";
		print Timestamp() . "\tSending message> CONFIG.\n";
		print Timestamp() . "\t$uri\n";
		$ua = LWP::UserAgent->new;
		$postString="";
		if ($response=~/CRAP/) {
			$postString="$platform;*CRAP*:$exp_id:$run_id:$key_id:$total_run_id:$app:$xx\n";
		} else {
			 $postString="$platform;$response:$exp_id:$run_id:$key_id:$total_run_id:$app:$xx\n";
		}
		$post_data = [ keyid => $myKEY,
						platform => $platform,
						data => $postString ];
						
		print Timestamp() . " Contacting server \n";
		print Timestamp() . " $uri POST $postString \n";
		$reply=$ua->request(POST "$uri", $post_data );
		print Timestamp() . " Server reply;\n";
		if ($reply->is_success) {
			print "Ok\n";
			print $reply->decoded_content;
			print "\n";
		} else {
			print "Error: " . $reply->code . "\n";
			print $reply->decoded_content;
			print "\n";
		}
		print Timestamp() . " (END OF SERVER MSG) \n";
		#open FILE, ">> $fname" or die "cant work with $fname, get $! ";
		#print FILE "$args[1]-$args[2]-$args[3]-$args[4]-$response-$bigSTDOUTlog Done \n";
		#close FILE ;
	  }
	}
	print "Hello World, My Wait for $SAC is over\n";
}

sub Timestamp {
        my ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst);
        ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst)=localtime(time);
        $year+=1900;
        $mon+=1;
        return "$year $mon $mday $hour:$min:$sec ";
}
               

sub updatePID{
	open(PID,">$pidfile");
	print PID time()."\n";
	close(PID);
}

sub INT_handler {
	print "got SIGINT\n";
	$response = "FAILURE";
	$xx = "MANUAL RESTART";
	$datastring="$platform;$response:$exp_id:$run_id:$total_run_id:$app:$xx\n";
	$uri="$URLbase/inthandler.php?keyid=$myKEY&platform=$platform&data='$datastring'";
	print Timestamp() . "\t$uri\n";
	$reply=get "$uri";
	@replyline = split(/\R/,$reply);
	
	print Timestamp() . "Interrupted, informed server. \n";
	print Timestamp() . "$reply \n";
	exit (0);
}
