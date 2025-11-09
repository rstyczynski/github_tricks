# RSB Sprint 1 - Implementation Notes

## RSB-6. Rules directory has subdirectories to keep generic and technology specific rules

Status: Implemented

### Implementation Details

Reorganized the rules directory from a flat structure to an organized hierarchy separating generic methodology rules from technology-specific implementations.

#### Directory Structure Created

```
rules/
├── README.md                           # Directory structure documentation
├── generic/                            # Universal rules for all technologies
│   ├── GENERAL_RULES.md               # Core cooperation rules and state machines
│   ├── GIT_RULES.md                   # Git conventions and commit standards
│   ├── PRODUCT_OWNER_GUIDE.md         # Complete Product Owner workflow guide
│   └── images/                         # Generic methodology visual assets
│       ├── agentic_cooperation_v2.png
│       └── agentic_cooperation.drawio
└── github_actions/                     # GitHub Actions specific rules
    ├── GitHub_DEV_RULES.md            # GitHub-specific implementation guidelines
    └── images/                         # (future GitHub-specific visual assets)
```

#### Files Moved

Used `git mv` to preserve file history:

1. `rules/GENERAL_RULES.md` → `rules/generic/GENERAL_RULES.md`
2. `rules/GIT_RULES.md` → `rules/generic/GIT_RULES.md`
3. `rules/PRODUCT_OWNER_GUIDE.md` → `rules/generic/PRODUCT_OWNER_GUIDE.md`
4. `rules/GitHub_DEV_RULES.md` → `rules/github_actions/GitHub_DEV_RULES.md`

#### References Updated

Updated all references to rules files throughout the entire GitHub Tricks project (99 occurrences):

**Main Project Files:**
- `AGENTS.md` - Updated 4 rule references
- `HUMANS.md` - Updated 6 rule references
- `BACKLOG.md` - Updated 2 rule references
- `README.md` - Updated 1 rule reference
- `RSB_BACKLOG.md` - Updated descriptions and examples

**Progress Files:**
- All files in `progress/` directory updated using batch sed commands
- Updated both exact file references (`rules/GENERAL_RULES.md`)
- Updated wildcard references (`rules/GENERAL_RULES*.md`)

#### Documentation Added

Created `rules/README.md` documenting:
- Directory organization and purpose
- Description of each subdirectory
- Usage guidelines
- Instructions for adding new technology stacks
- Version history

### Benefits

1. **Technology Agnostic** - Generic rules are clearly separated from technology-specific rules
2. **Scalable** - Easy to add new technology stacks (Ansible, Terraform, Kubernetes, etc.)
3. **Clear Organization** - Developers immediately understand which rules apply universally vs. technology-specific
4. **Maintainable** - Related rules are grouped together
5. **Future Ready** - Structure supports RUP Strikes Back expansion to other technologies
6. **Per-Technology Images** - Each technology subdirectory has its own images/ for visual assets specific to that technology

### Testing

Verified reorganization:

```bash
# Verify new structure
ls -R rules/

# Verify no broken references
grep -r "rules/GENERAL_RULES" . --include="*.md" | grep -v "rules/generic"
grep -r "rules/GIT_RULES" . --include="*.md" | grep -v "rules/generic"
grep -r "rules/GitHub_DEV" . --include="*.md" | grep -v "rules/github_actions"
grep -r "rules/PRODUCT_OWNER" . --include="*.md" | grep -v "rules/generic"
```

All references successfully updated. No broken links found.

### Notes

This reorganization completes the foundation for technology-agnostic agent operation (RSB-2). Future technology stacks can now be added by creating new subdirectories under `rules/` following the established pattern.

## RSB-7. Remove v99 tag from names in rules directory

Status: Implemented

### Implementation Details

Removed version tags (v1, v3, v4) from all rules filenames since files are tracked by git and version tags in filenames are redundant.

#### Files Renamed

Used `git mv` to preserve file history:

1. `rules/generic/GENERAL_RULES_v3.md` → `rules/generic/GENERAL_RULES.md`
2. `rules/generic/GIT_RULES_v1.md` → `rules/generic/GIT_RULES.md`
3. `rules/generic/PRODUCT_OWNER_GUIDE_v3.md` → `rules/generic/PRODUCT_OWNER_GUIDE.md`
4. `rules/github_actions/GitHub_DEV_RULES_v4.md` → `rules/github_actions/GitHub_DEV_RULES.md`

#### References Updated

Updated all references throughout the entire project (100+ occurrences):

- Main project files
- All progress files (including historical references)
- Command files in `.claude/commands/`
- Rules README documentation
- Internal cross-references within rules files

#### Benefits

1. **Git Tracking** - Version history is properly tracked by git, not filename
2. **Cleaner Naming** - Simpler, more maintainable filenames
3. **Consistency** - Follows standard practice for git-tracked files
4. **Future Proof** - Updates don't require filename changes

#### Testing

Verified all version tags removed:

```bash
# Check new filenames
ls -la rules/generic/*.md rules/github_actions/*.md

# Verify no versioned references remain
grep -r "_v[0-9]\.md" . --include="*.md" | grep -E "(GENERAL_RULES|GIT_RULES|PRODUCT_OWNER|GitHub_DEV)"
```

All references successfully updated. Clean filenames verified.

