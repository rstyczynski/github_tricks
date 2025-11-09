# RUP Strikes Back - backlog

RUP Strikes Back method is developed as piggy back on top on GitHub Tricks project. As it getting complex it must has own backlog and traceability boards.

## Backlog

### RSB-1. RUP Strikes Back method has own life-cycle tools

RUP Strikes Back method has own life-cycle tools:

* backlog: RSB_BACKLOG
* plan: RSB_PLAN
* progress board: RSB_PROGRESS_BOARD

### RSB-2. Agents are technology agnostic

RUP Strikes Back command and agents are universal working for all technologies. Specific technology used by a project is driven by best practices and rules collected in `rules/<technology>/` directory (e.g., `rules/github_actions/`, `rules/ansible/`).

### RSB-3. YOLO mode - agent process full life cycle in autonomous mode

YOLO means that agent process full life cycle in autonomous mode. Makes assumptions for weak problems. Tries not to disturb human if not really needed. YOLO is a parameter of `rup-manager` command and by default is enabled for this command. `agent-*` specific commands have YOLO by default disabled and may be enable by a command from `rup-manager` invocation. Operator may of course invoke agent with YOLO argument. Work in YOLO m ode is manifested by visible ASCII graphics presented at start of each agent.

### RSB-4. progress directory contains sprint subdirectories that collects sprint related file together

Goal is to eliminate accumulation of files in progress directory. Having specific files in own sprint directory will distribute abd better organize files.

### RSB-5. progress directory contains backlog subdirectory that has symbolic links to sprint documents

progress/backlogs directory has backlog id subdirectory with symbolic links to documents in various progress/sprint directories

### RSB-6. rules directory has subdirectories to keep generic and technology specific rules

Rules directory has subdirectories to keep generic and technology specific rules:

* `rules/generic/` - RUP Strikes Back universal rules that apply to any tech stack (GENERAL_RULES, GIT_RULES, PRODUCT_OWNER_GUIDE)
* `rules/github_actions/` - GitHub Actions specific rules (GitHub_DEV_RULES)
* `rules/ansible/` - Ansible specific rules (future)
* `rules/images/` - Shared visual assets

Each technology subdirectory contains rules specific to that technology, while generic rules establish the foundation for all projects.

### RSB-7. Remove v99 tag from names in rules directory

Rules in rules directory are tracked by github and does not need _v99 tags in the name. Existing tags must be removed.
