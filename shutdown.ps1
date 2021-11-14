param(
  [Alias("d", "doozle")][switch] $keep_dozzle,
  [Alias("h")][switch] $help
)

function show_help() {
    Write-Host @"
  Usage:
      -d, --dozzle                Prevent shutdown from killing Dozzle as well.
      -h, --help                  Show's this help message
"@
}

if($show_help) {
    show_help
    exit 0
}

Write-Host -ForegroundColor Blue @'
   _____ __          __  __  _                ____                    
  / ___// /_  __  __/ /_/ /_(_)___  ____ _   / __ \____ _      ______ 
  \__ \/ __ \/ / / / __/ __/ / __ \/ __ `/  / / / / __ \ | /| / / __ \
 ___/ / / / / /_/ / /_/ /_/ / / / / /_/ /  / /_/ / /_/ / |/ |/ / / / /
/____/_/ /_/\__,_/\__/\__/_/_/ /_/\__, /  /_____/\____/|__/|__/_/ /_/ 
                                 /____/   Bye-bye! 
'@

if(-not $keep_dozzle) {
    if(docker ps --format "{{.Names}}" | Select-String verify_dozzle_1) {
        Write-Host "Stopping Verify Dozzle" -ForegroundColor Green
        docker stop verify_dozzle_1 | Out-Null
    }
}

docker-compose down