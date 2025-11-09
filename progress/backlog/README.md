# Progress Backlog Directory

This directory organizes progress files by Backlog Item ID using symbolic links. Each backlog item has its own subdirectory containing links to all related documents across different sprints.

## Structure

```
backlog/
├── GH-1/          # Backlog item GH-1 related documents
│   ├── sprint_0_prerequisites.md -> ../../sprint_0/sprint_0_prerequisites.md
│   └── ...
├── GH-2/          # Backlog item GH-2 related documents
│   ├── sprint_1_implementation.md -> ../../sprint_1/sprint_1_implementation.md
│   └── ...
├── RSB-1/         # Backlog item RSB-1 related documents
│   ├── rsb_sprint_0_implementation.md -> ../../rsb_sprint_0/rsb_sprint_0_implementation.md
│   └── ...
└── ...
```

## Usage

### Finding Documents for a Specific Backlog Item

```bash
cd progress/backlog/GH-15
ls -la
```

This shows all documents related to backlog item GH-15 across all sprints.

### Creating Links for a New Backlog Item

```bash
# Create backlog directory
mkdir -p progress/backlog/GH-27

# Create symbolic links to related documents
cd progress/backlog/GH-27
ln -s ../../sprint_X/sprint_X_design.md .
ln -s ../../sprint_X/sprint_X_implementation.md .
ln -s ../../sprint_X/sprint_X_tests.md .
```

## Benefits

1. **Traceability** - Quickly find all work related to a specific requirement
2. **Cross-Sprint View** - See how a backlog item evolved across multiple sprints
3. **Easy Navigation** - Navigate from requirement to implementation without searching
4. **Audit Trail** - Track complete lifecycle of each feature

## Maintenance

When creating new progress documents:
1. Create the document in the appropriate sprint directory
2. Create symbolic link in the relevant backlog item directory
3. Multiple backlog items can link to the same document if it addresses multiple requirements

