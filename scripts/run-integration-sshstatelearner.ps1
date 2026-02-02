Param(
    [switch]$DownAfterRun
)

Write-Host "Bringing up OpenSSH docker-compose (code/impl/openssh/docker-compose.yml)..."
docker compose -f code/impl/openssh/docker-compose.yml up -d --build

Write-Host "Running integration tests for module code/ssh_state_learner..."
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-maven-local.ps1 -Module code/ssh_state_learner -AdditionalArgs '-Pintegration-tests verify'

if ($DownAfterRun) {
    Write-Host "Tearing down OpenSSH compose..."
    docker compose -f code/impl/openssh/docker-compose.yml down
} else {
    Write-Host "OpenSSH compose left running. To stop it run:`n  docker compose -f code/impl/openssh/docker-compose.yml down"
}
