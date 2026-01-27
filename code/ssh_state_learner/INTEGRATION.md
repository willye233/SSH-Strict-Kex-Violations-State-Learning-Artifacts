Integration tests for `ssh_state_learner`

Prerequisites
- Docker and Docker Compose installed and accessible from the shell
- Java and tools required by the project (the repository includes `run-maven-local.ps1` to bootstrap Maven)

Quick run (recommended)

1. Bring up the OpenSSH SUL container and run the integration tests (leaves compose running):

```powershell
./scripts/run-integration-sshstatelearner.ps1
```

2. If you want the helper to tear the compose down after tests finish, run:

```powershell
./scripts/run-integration-sshstatelearner.ps1 -DownAfterRun
```

Manual steps

1. Start OpenSSH compose (module-relative compose file):

```powershell
docker compose -f code/impl/openssh/docker-compose.yml up -d --build
```

2. Run the integration profile (this uses the repo `run-maven-local.ps1` bootstrap script):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-maven-local.ps1 -Module code/ssh_state_learner -AdditionalArgs '-Pintegration-tests verify'
```

Notes
- The integration tests are tagged `@Tag("integration")` and are executed by the Maven Failsafe profile `integration-tests`.
- The integration test expects the OpenSSH compose to map host ports in the range `30020-30035` (see `code/impl/openssh/docker-compose.yml`). The test probes that range and selects a reachable host port automatically.
- If tests skip due to Docker not being available, make sure Docker is running and accessible to your shell.
