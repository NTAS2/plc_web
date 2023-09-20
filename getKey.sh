#!/usr/bin/perl
use LWP::Simple;
use Sys::Hostname;

if ( ($#ARGV + 1) != 1) {
    print Timestamp() . " Default config: plc.conf\n";
    $configFile="plc.conf";
} else {
    print Timestamp() . "Using " . $ARGV[0] . " as config.\n";
    $configFile=$ARGV[0];
}


$platform = hostname();

print "Config: $configFile, ";
$identified=0;

my $content;
open(my $fh, '<', $configFile) or die "cannot open file $configFile";
{
    local $/;
    $content = <$fh>;
}
close($fh);

if ( grep { /myKEY=1/ } $content ) {
    print "and an uninitialized key found.\n";
    do "./$configFile";
    $URLbase="http://$server_ipaddress/ntas/";
    print "$URLbase\n";
    
    $url="$URLbase/listkeys.php";
    $reply=get $url;
    
    if ( $reply =~ $platform ) {
	print "Platform found.\n";
	
	@replyline = split(/\R/,$reply);
	foreach $line (@replyline) {
	    if ($line=~ $platform) {
		if ($identified==1) {
		    print "$name -- $key -- $comment \n";
		}
		@data=split(/\s+/,$line);
		$name=$data[0];
		$key=$data[1];
		$comment=$data[2];
		#print "$name -- $key -- $comment \n";
		$identified++;
		if ($identified>1) {
		    print "$name -- $key -- $comment \n";
		}
	    }
	}
	if ( $identified>1 ) {
	    print "Problems multiple platforms found.\n";
	    print "Things needs to be fixed on the server, $URLbase.\n";
		
	    exit(1);
	}
	##
	print "Updating $configFile with $name, $key .\n";
	$fileContent=read_file($configFile);
	$fileContent =~ s/myKEY=1/myKEY=$key/g;
	write_file($configFile,$fileContent);
	
	
	
    } else {
	print "Platform is missing, make sure its added.\n"
    }
    
	
} else {
    print "seems to contain a valid key.\n"
}



sub Timestamp {
        my ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst);
        ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst)=localtime(time);
        $year+=1900;
        $mon+=1;
        return "$year $mon $mday $hour:$min:$sec ";
}

sub read_file {
    my ($filename) = @_;
 
    open my $in, '<:encoding(UTF-8)', $filename or die "Could not open '$filename' for reading $!";
    local $/ = undef;
    my $all = <$in>;
    close $in;
 
    return $all;
}
 
sub write_file {
    my ($filename, $content) = @_;
 
    open my $out, '>:encoding(UTF-8)', $filename or die "Could not open '$filename' for writing $!";;
    print $out $content;
    close $out;
 
    return;
}
