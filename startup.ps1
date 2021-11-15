#!/usr/bin/env pwsh

# To get things running in windows the following commands maybe helpful
# netsh int ipv4 set dynamicport tcp start=10000 num=55000
# netsh int ipv4 set dynamicport udp start=10000 num=55000
# net stop winnat
# Run this script
# net start winnat

param(
  [Alias("y","yaml-file")][string] $yaml_file = "repos.yml",
  [Alias("t")][int32] $threads = 0,
  [Alias("r","retry-build")][int32] $retries = 1,
  [Alias("w","write-build-log")][switch] $write_build_log,
  [Alias("s","skip-data-check")][switch] $skip_data_check,
  [Alias("b","skip-build")][switch] $skip_build,
  [Alias("rd","rebuild-data")][switch] $rebuild_data,
  [Alias("i","include-maven-local")][switch] $include_maven,
  [Alias("d")][switch] $dozzle,
  [Alias("p","dozzle-port")][int32] $dozzle_port = "30999",
  [Alias("g","generate-only")][switch] $generate_only,
  [alias("v", "enable-logging")][switch] $logging,
  [Alias("c")][switch] $clean,
  [Alias("h")][switch] $help
)

function show_help {
  Write-Host @"
  Usage:

  Options:
    -y, --yaml-file <file>      Yaml file with a List of repos to build.
                                Default ./repos.yml
    -t, --threads <number>      Specifies the number of threads to use to do the
                                the build.  If no number given will generate as many
                                threads as repos.  Suggested 4 threads.
                                On macs the default is 2 on other systems 0.
    -r, --retry-build <number>  Sometimes the build can fail due to resourcing issues
                                by default we'll retry once.  If you want to retry
                                more times set a number here or set it to 0 to not retry.

  Switches:
    -w, --write-build-log       Writes the build log even for successful builds
    -s, --skip-data-check       Skip checking the age of the data directory
    -b, --skip-build            Allows you to skip the build process.  Useful if you've
                                already built everything and your developing something.
    -rd, --rebuild-data          Tells the script to remove and rebuild the data directory.
    -i, --include-maven-local   Copy your local maven directory to the Docker images. Allows
                                you to use SNAPSHOTs of our libraries in the build.
    
  Dozzle (useful on Linux):
    -d, --dozzle                Run Dozzle for docker output viewing on port 50999.
    -p, --dozzleport <number>   Sets the port doozle should run on if you choose to run
                                Dozzle (see the -d switch).  Default 50999

  Tasks:
    -g, --generate-only         Generates the data directory and env files and then exits.
    -c, --clean                 Cleans up the verify local startup directory and exits.

    -h, --help                  Show's this help message and exits
"@
}

Function Test-CommandMissing
{
 Param ($command)
 $oldPreference = $ErrorActionPreference
 $ErrorActionPreference = ‘stop’
 try {if(Get-Command $command){RETURN $false}}
 Catch {RETURN $true}
 Finally {$ErrorActionPreference=$oldPreference}
}

function check_requirements {
  if(Test-CommandMissing docker) {
    Write-Host "Docker is not installed.  Please install Docker!"
    Write-Host "You can install docker from https://www.docker.com/get-started"
    Exit 1
  }
  if(Test-CommandMissing git) {
    Write-Host "Git is not installed.  Please install git!"
    Write-Host "You can get git from https://gitforwindows.org/"
    Write-Host "Please make sure you you set the option to checkout as is and commit with Linux/Unix line endings"
    Exit 1
  }
  if(Test-CommandMissing ruby) {
    Write-Host "Ruby is not installed.  Please install Ruby!"
    Write-Host "You can install ruby 2.7.4 from https://rubyinstaller.org/"
    Exit 1
  }
}

function clean_up {
  docker build -t verify-local-startup .
  docker run -t -v "${PSScriptRoot}:/verify-local-startup/" verify-local-startup @'
if [ -d data ]; then
  rm -r data
fi
if [ -f hub.env ]; then
  rm *.env
fi
logfiles=(logs/*.log)
if [ ${#logfiles[@]} -gt 0 ]; then
  rm logs/*.log
fi
'@.Replace("`r`n", "`n")
  Write-Host -ForegroundColor Red "Verify local startup has been cleaned up."
  exit 0
}

function check_data_age {
  if (-Not (Test-Path ./data)) {
    return
  }

  $lastWrite = (Get-Item ./data).LastWriteTime
  $timespan = new-timespan -days 14

  if (((get-date) - $lastWrite) -gt $timespan) {
      Write-Host -ForegroundColor Red "Data directory has expired... Rebuilding"
      return $tue
  }
  return $false
}

if($help) {
  show_help
  exit 0
}

check_requirements

Write-Host -ForegroundColor Blue @"
__     __        _  __         _   _       _        ____  ___  
\ \   / /__ _ __(_)/ _|_   _  | | | |_   _| |__    / ___|/ _ \ 
 \ \ / / _ \ '__| | |_| | | | | |_| | | | | '_ \  | |  _| | | |
  \ V /  __/ |  | |  _| |_| | |  _  | |_| | |_) | | |_| | |_| |
   \_/ \___|_|  |_|_|  \__, | |_| |_|\__,_|_.__/   \____|\___/ 
                       |___/                                   
"@

if (-not (docker image ls | select-string verify-local-startup)) {
  # Build verify-local-startup image
  docker build -t verify-local-startup .
}

if ($clean) {
  Write-Host -ForegroundColor Red "Cleaning up Directory..."
  clean_up
}

if($skip_data_check) {
  $rebuild_data = check_data_age
}

if($rebuild_data -and (Test-Path ./data)) {
  $REMOVE_DATA_DIR = @"
  echo 'Removing data directory...'
  rm -r data
  rm *.env"
"@
}

$run_script = @"
set -e
$REMOVE_DATA_DIR
if ! test -d data; then
  generate/hub-dev-pki.sh
fi
./env.sh
"@

docker run -t -v ${PSScriptRoot}:/verify-local-startup/ verify-local-startup $run_script.Replace("`r`n", "`n")

if($generate_only) {
  exit 0
}

if( -not $skip_build) {
  bundle check || bundle install
  
  # Switch builder
  if ($write_build_log) {
    $WRITE_BUILD_LOG_FLAG = "-w"
  }
  if ($include_maven) {
    $INCLUDE_MAVEN_LOCAL_FLAG = '-i'
  }
  if ($logging) {
    $ENABLE_BUILD_LOG_FLAG = '-v'
  }
  ruby ./lib/build-local.rb -R $retries -y $yaml_file -t $threads $WRITE_BUILD_LOG_FLAG $INCLUDE_MAVEN_LOCAL_FLAG $ENABLE_BUILD_LOG_FLAG
}

if ($dozzle) {
  if(-not $isWindows) {
    Write-Host "Running Dozzle on port $dozzle_port"
    if (-not (docker ps |Select-String doz)) {
      Write-Host "Runing Dozzle..."
      docker run --rm --name verify_dozzle_1 --detach --volume=/var/run/docker.sock:/var/run/docker.sock -p $DOZZLEPORT:8080 amir20/dozzle
    }
    Write-Host "Dozzle is running and can be found at http://localhost:$dozzle_port/"
  } else {
    Write-Host -ForegroundColor Red "Dozzle is not supported on Windows.  To view container logs look in the Docker Desktop App"
  }
}

docker-compose -f docker-compose.yml --env-file .env up -d

$test_rp_url = (Get-Content config/urls.env | Select-String TEST_RP_URL).Line.split("=")[1]
Write-Host "Started - visit " -NoNewLine -ForegroundColor green
Write-Host "${TEST_RP_URL}/test-rp " -NoNewline -ForegroundColor blue
Write-Host "to start a journey (may take some time to spin up)" -ForegroundColor green
