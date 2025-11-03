# Sprint 0 Prerequisites

Operator instructions for preparing local tooling to work with GitHub Workflows.

## 1. Install base tooling

Install required packages depending on your platform.

### 1.1 macOS (Homebrew)

```bash
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed"
fi

brew update
brew install git gh go openjdk temurin act jq curl podman
```

Add OpenJDK to the PATH (adjust `17` if Homebrew installs a newer LTS):

```bash
sudo ln -sfn "$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk
echo 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

Initialize Podman (required once) and start the machine:

```bash
podman machine init
podman machine start
```
```

### 1.2 Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y git curl jq podman podman-docker
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh golang-go default-jdk
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

Install `actionlint` from source (Linux):

```bash
GO111MODULE=on go install github.com/rhysd/actionlint/cmd/actionlint@latest
```

macOS alternative (Homebrew):

```bash
brew install actionlint
```

## 2. Configure Git

Prompt for your real name and email (these will appear in commits):

```bash
read -rp "Enter your Git display name: " GIT_NAME
read -rp "Enter your Git email: " GIT_EMAIL
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
```

Verify the values:

```bash
git config --global --get user.name
git config --global --get user.email
```

Create or upload an SSH key for repository access:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "workflow-dev"
```

Alternatively, configure HTTPS with a personal access token (PAT):

```bash
gh auth login --with-token < token.txt
```

## 3. Authenticate GitHub CLI

```bash
gh auth login
```

Select:

1. `GitHub.com`
2. HTTPS
3. Paste existing PAT or open browser

Verify login:

```bash
gh auth status
```

## 4. Configure Podman for `act`

`act` needs a container runtime. Configure Podman:

- macOS (after `podman machine start`): `podman info`
- Linux:

```bash
sudo systemctl enable --now podman.socket
podman info
```

Set the environment variable before running `act`:

```bash
export ACT_EXPERIMENT_PODMAN=1
```

## 5. Install Java build helpers

Add commonly used build tools:

```bash
brew install maven gradle || sudo apt-get install -y maven gradle
```

Recommended Java libraries for GitHub interaction (document only, no install):

- [Java GitHub API (hub4j/github-api)](https://github.com/hub4j/github-api)
- [OkHttp](https://square.github.io/okhttp/) for HTTP calls

Recommended Go libraries:

- [google/go-github](https://github.com/google/go-github)
- [hashicorp/go-retryablehttp](https://github.com/hashicorp/go-retryablehttp)

## 6. Install `actionlint`

Ensure GOPATH bin is in PATH (both macOS and Linux):

```bash
GO_BIN_PATH="$(go env GOPATH)/bin"
SHELL_PROFILE="${HOME}/.bashrc"

if [[ "$SHELL" == */zsh ]]; then
  SHELL_PROFILE="${HOME}/.zshrc"
fi

if ! grep -q "${GO_BIN_PATH}" "$SHELL_PROFILE"; then
  echo "export PATH=\"$PATH:${GO_BIN_PATH}\"" >> "$SHELL_PROFILE"
fi

source "$SHELL_PROFILE"
actionlint --version
```

## 7. Verification matrix

| Tool / Check | Command | Expected output |
| ------------ | ------- | --------------- |
| Git version | `git --version` | `git version >= 2.30` |
| GitHub CLI | `gh --version` | `gh version >= 2.0.0` |
| Go | `go version` | `go version go1.21+` |
| Java | `java -version` | `openjdk version "17"` or newer |
| Podman | `podman info` | No errors, runtime info printed |
| act | `act --version` | `act version ...` |
| actionlint | `actionlint --version` | `actionlint version ...` |
| jq | `jq --version` | `jq-1.6+` |

## 8. References

- GitHub CLI install: https://cli.github.com/manual/installation
- Git configuration: https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup
- Hub4j API: https://github.com/hub4j/github-api
- go-github: https://github.com/google/go-github
- actionlint: https://github.com/rhysd/actionlint
