# Sprint 0 - Implementation Notes

## GH-1. Prepare tools and techniques
Status: Progress

- Added operator guide `sprint_0_prerequisites.md` with platform-specific setup for GitHub CLI, Go, Java (Temurin/OpenJDK), Podman (container runtime), `act`, `actionlint`, and helper utilities (`jq`, Maven, Gradle), including interactive prompts to capture the operator's real Git author name and email, OS-specific `actionlint` installation paths, and guidance for exporting GOPATH binaries on macOS or Linux shells.
- Document includes copy/paste commands for macOS (Homebrew) and Ubuntu/Debian, authentication steps for Git and `gh`, and recommended GitHub client libraries (`hub4j/github-api`, `google/go-github`, `hashicorp/go-retryablehttp`, `OkHttp`).
- Verification matrix at the end provides commands to confirm toolchain availability (`gh --version`, `go version`, `java -version`, `actionlint --version`, etc.).
- References chapter links to the canonical documentation for future updates.
