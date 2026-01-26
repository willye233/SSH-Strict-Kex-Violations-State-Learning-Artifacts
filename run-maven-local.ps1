# Downloads a portable Maven and runs the specified test in the ssh_state_learner module
param(
    [string]$MavenVersion = '3.9.4',
    [string]$ModulePath = 'code\\ssh_state_learner',
    [string]$Test = 'SshSymbolConstructorTest'
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $root

$artifactName = "apache-maven-$MavenVersion-bin.zip"
$mavenZip = Join-Path $root ".mvn\\$artifactName"
$mavenDir = Join-Path $root ".mvn\\apache-maven-$MavenVersion"

if (-not (Test-Path $mavenDir)) {
    New-Item -ItemType Directory -Path (Join-Path $root '.mvn') -Force | Out-Null
    $url = "https://downloads.apache.org/maven/maven-3/$MavenVersion/binaries/$artifactName"
    Write-Host "Downloading Maven $MavenVersion from $url ..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $mavenZip -ErrorAction Stop
    } catch {
        Write-Host "Primary download failed; trying Apache archive mirror..."
        $url = "https://archive.apache.org/dist/maven/maven-3/$MavenVersion/binaries/$artifactName"
        Write-Host "Downloading Maven $MavenVersion from $url ..."
        Invoke-WebRequest -Uri $url -OutFile $mavenZip -ErrorAction Stop
    }
    Write-Host "Extracting $mavenZip ..."
    Expand-Archive -Path $mavenZip -DestinationPath (Join-Path $root '.mvn') -Force
}

$mvnCmd = Join-Path $mavenDir 'bin\\mvn.cmd'
if (-not (Test-Path $mvnCmd)) {
    throw "Maven command not found at $mvnCmd"
}

$moduleFull = Join-Path $root $ModulePath
Set-Location $moduleFull
Write-Host "Running tests in $moduleFull ..."
& $mvnCmd "-Dtest=$Test" "test"

# exit with the process exit code
exit $LASTEXITCODE
