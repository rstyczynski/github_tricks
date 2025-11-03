# Sprint 0 - design

## GH-1. Prepare tools and techniques
Status: Accepted

Description: Prepare toolset for GitHub workflow interaction. GitHub CLI, Go, and Java libraries should be used. Propose proper libraries for Go and especially Java, which will be used for production coding.

Goal: Prepare a toolset for GitHub workflow interaction covering GitHub CLI, Go, and Java libraries, and recommend production-suitable libraries (especially for Java).

- Produce a markdown guide named `sprint_0_prerequisites.md` that operators can follow sequentially. Each step will start with a short description followed by a fenced code block containing the exact command to copy.
- Cover environment requirements for macOS and Linux runners: package installation (Homebrew/apt), verifying shell environment, and documenting minimum versions for GitHub CLI, Go, and Java (e.g., gh ≥2.0, Go ≥1.21, Temurin/OpenJDK ≥17).
- Include sections for:
  - Authenticating `gh` via PAT or browser login, with command snippets.
  - Ensuring Git is configured (user/email) and SSH key or HTTPS PAT setup to interact with repositories.
  - Installing `act` for local workflow testing with Podman as the container runtime (including Podman setup and act configuration).
  - Installing `actionlint` using `go install`, with GOPATH instructions.
- Finish the document with a verification matrix checklist (table) that reiterates each prerequisite and provides a command to validate installation (e.g., `gh --version`, `go version`, `java -version`, `act --version`, `actionlint --version`).
- Reference official documentation links inline for each tool to support future updates.
