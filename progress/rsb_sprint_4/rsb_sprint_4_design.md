# RSB Sprint 4 - Design

## RSB-3. YOLO mode - agent process full life cycle in autonomous mode

Status: Proposed

### Requirement Summary

Implement YOLO (You Only Live Once) mode for agents that enables autonomous processing of the full development lifecycle with minimal human intervention. YOLO mode should:
- Make reasonable assumptions for ambiguous situations
- Continue processing without blocking on minor issues
- Minimize interruptions to the human operator
- Display visible ASCII graphics at agent start to indicate YOLO mode is active
- Be enabled by default for `rup-manager` command
- Be disabled by default for individual `agent-*` commands
- Be controllable via command parameter

### Feasibility Analysis

**Implementation Approach:**
YOLO mode can be implemented as a configuration parameter passed to agents that modifies their behavior patterns. This is fully feasible using existing agent architecture.

**Technical Constraints:**
1. Agents are defined in markdown files (`.claude/commands/agents/*.md`)
2. No direct parameter passing mechanism in current markdown-based agent system
3. Need convention-based approach for YOLO mode detection

**Alternative Approaches:**
1. **Environment Variable**: Set `YOLO_MODE=true` in environment
2. **File-Based Flag**: Create `.yolo` file in workspace root
3. **Convention-Based**: Detect if invoked by `rup-manager` vs. direct agent call
4. **Command Prefix**: Use special invocation syntax (e.g., `@rup-manager.md` vs `@agent-analyst.md`)

**Risk Assessment:**
- **LOW RISK**: YOLO mode is additive behavior modification
- **MEDIUM RISK**: Over-automation could make poor assumptions
- **MITIGATION**: Clear logging of all YOLO-mode decisions

### Design Decision: Configuration-Based YOLO Mode

**Selected Approach:** YOLO mode configured in PLAN.md as a project-level setting

#### Activation Mechanism

YOLO mode is set in the Sprint section of `PLAN.md`:

**Option A: Managed Mode (Default - Interactive)**
```markdown
## Sprint 20

Status: Progress
Mode: managed

Backlog Items:
* GH-27. Trigger long running workflow
```

**Option B: YOLO Mode (Autonomous)**
```markdown
## Sprint 20

Status: Progress
Mode: YOLO

Backlog Items:
* GH-27. Trigger long running workflow
```

**For RSB Sprints:**
```markdown
## RSB Sprint 4 - Agent Enhancements

Status: Progress
Mode: YOLO

Backlog Items:
* RSB-3. YOLO mode implementation
```

#### Benefits of Configuration-Based Approach

✅ **Centralized Control** - Mode configured in PLAN.md (single source of truth)  
✅ **Visible State** - Anyone can see current mode by reading PLAN  
✅ **Git Tracked** - Mode changes tracked in version control  
✅ **Audit Trail** - Permanent record that implementation was done autonomously  
✅ **No Arguments Needed** - Agents read mode from PLAN.md automatically  
✅ **Persistent** - Mode stays set until explicitly changed  
✅ **Per-Sprint Control** - Can mix YOLO and managed sprints  
✅ **Traceability** - Future readers know if sprint was human-supervised or autonomous  

#### Detection Logic in Agents

Each agent reads the mode from PLAN.md:

```markdown
## Step 1: Detect Execution Mode

1. Read PLAN.md
2. Identify the active Sprint (Status: Progress)
3. Check for "Mode:" field in that Sprint section
   - If "Mode: YOLO" → Enable YOLO behaviors
   - If "Mode: managed" → Use interactive mode
   - If no Mode field → Default to managed (interactive)

Example PLAN.md parsing:
- Find: "Status: Progress"
- Read next lines for "Mode: YOLO" or "Mode: managed"
- Apply corresponding behaviors
```

This is a **configuration-based** approach where mode is a project setting, not a runtime argument.

#### Mode Field Specification

**In PLAN.md, each Sprint section should include:**

```markdown
## Sprint ${no} - [Title]

Status: [Planned|Progress|Designed|Implemented|Tested|Done|Failed]
Mode: [managed|YOLO]

Backlog Items:
* ...
```

**Default Mode:** `managed` (if Mode field is absent)  
**YOLO Mode:** `YOLO` (explicit opt-in to autonomous operation)

### Technical Design

#### 1. YOLO Mode Indicators

**ASCII Banner for YOLO Mode:**
```
╔═══════════════════════════════════════╗
║                                       ║
║     Y O L O   M O D E   A C T I V E   ║
║                                       ║
║   Autonomous Lifecycle Processing     ║
║   Minimal Human Intervention          ║
║                                       ║
╚═══════════════════════════════════════╝
```

**Agent Start Indication:**
Each agent should display a mode indicator:
- YOLO Mode: Full ASCII banner
- Interactive Mode: Simple status line

#### 2. YOLO Mode Behaviors

**Design Phase (agent-designer):**
- **Interactive Mode**: Wait for explicit design approval from Product Owner
- **YOLO Mode**: Wait 60 seconds, then assume approval and proceed

**Implementation Phase (agent-constructor):**
- **Interactive Mode**: Stop on any test failure and request guidance
- **YOLO Mode**: Document failures, attempt fixes, retry once, then proceed

**Documentation Phase (agent-documentor):**
- **Interactive Mode**: Report doc issues and wait for corrections
- **YOLO Mode**: Log issues, make best-effort corrections, proceed

**Analysis Phase (agent-analyst):**
- **Interactive Mode**: Request clarification for ambiguous requirements
- **YOLO Mode**: Document assumptions, proceed with reasonable interpretation

#### 3. Assumption Documentation

In YOLO mode, all assumptions and autonomous decisions must be logged:

```markdown
## YOLO Mode Decisions

### [Timestamp] - [Agent] - [Decision]
**Context:** [What situation required a decision]
**Assumption Made:** [What was assumed]
**Action Taken:** [What the agent did]
**Rationale:** [Why this choice was made]
```

This log should be appended to the sprint's implementation notes.

#### 4. rup-manager.md Enhancement

The `rup-manager.md` command should:
1. Read PLAN.md to detect mode for active Sprint
2. Display mode banner (YOLO or Managed)
3. Execute agents (agents will read mode from PLAN.md themselves)
4. Collect and summarize all YOLO decisions at end (if YOLO mode)

**Implementation:**
```markdown
# RUP Manager - Full Lifecycle Automation

## Step 1: Detect Execution Mode from PLAN.md

1. Read PLAN.md
2. Find Sprint with "Status: Progress"
3. Check for "Mode:" field
   - If "Mode: YOLO" → Display YOLO banner
   - If "Mode: managed" or no Mode field → Display Managed banner

**If YOLO Mode Detected:**

╔═══════════════════════════════════════╗
║                                       ║
║     Y O L O   M O D E   A C T I V E   ║
║                                       ║
║   Autonomous Lifecycle Processing     ║
║   Minimal Human Intervention          ║
║   (Configured in PLAN.md)             ║
║                                       ║
╚═══════════════════════════════════════╝

**If Managed Mode (Interactive):**

📋 Managed Mode - Guided Operation
- Agents will wait for your approval at key points
- You'll be prompted for decisions
- Full control over each phase
- (Configured in PLAN.md)

## Step 2: Execute Lifecycle Phases

Phase 1: Contracting
@agent-contractor.md

Phase 2: Inception (Analysis)
@agent-analyst.md

Phase 3: Elaboration (Design)
@agent-designer.md

Phase 4: Construction (Implementation)
@agent-constructor.md

Phase 5: Documentation
@agent-documentor.md

[Each agent will read PLAN.md independently to detect mode]
```

#### 5. Individual Agent YOLO Mode Support

Each agent should include YOLO mode detection and behavior modification:

**agent-analyst.md:**
```markdown
## Step 1: Execution Mode Detection

**Read Mode from PLAN.md:**
1. Open and read PLAN.md
2. Find Sprint with "Status: Progress"
3. Check for "Mode:" field
   - If "Mode: YOLO" → Enable YOLO behaviors
   - If "Mode: managed" or absent → Use interactive behaviors

**Display Mode Indicator:**
- **YOLO Mode:** 🚀 YOLO MODE - Autonomous operation
- **Managed Mode:** 📋 Managed Mode - Guided operation

**YOLO Mode Behaviors:**
- Make reasonable assumptions for ambiguous requirements
- Document all assumptions in analysis
- Proceed without blocking on minor clarifications

**Managed Mode Behaviors:**
- Request clarifications for ambiguous requirements
- Wait for Product Owner feedback
- Block on unclear specifications
```

**agent-designer.md:**
```markdown
## Step 1: Execution Mode Detection

**Check for YOLO Mode:**
Look for "YOLO MODE: ACTIVE" in the invocation context.

- **If found** → Enable autonomous approval
- **If not found** → Wait for manual approval

**YOLO Mode Behaviors:**
- Submit design with Status: Proposed
- Display: "⏳ Waiting 60 seconds for Product Owner review..."
- Wait 60 seconds
- If no response, automatically mark as Accepted
- Proceed to next phase
- Document: "Design auto-approved after 60s timeout (YOLO mode)"
```

**agent-constructor.md:**
```markdown
## Step 1: Execution Mode Detection

**Check for YOLO Mode:**
Look for "YOLO MODE: ACTIVE" in the invocation context.

**YOLO Mode Behaviors:**
- If test fails: 
  - Display: "🔧 Test failed - attempting automatic fix..."
  - Attempt automatic fix once
  - Retry test
- Document failure and fix attempt
- If fix succeeds: Continue normally
- If fix fails: 
  - Mark as partial implementation
  - Continue to documentation phase
  - Do not block entire sprint
```

**agent-documentor.md:**
```markdown
## Step 1: Execution Mode Detection

**Check for YOLO Mode:**
Look for "YOLO MODE: ACTIVE" in the invocation context.

**YOLO Mode Behaviors:**
- If documentation issues found: 
  - Display: "⚠️ Documentation issues detected - attempting auto-fix..."
  - Log all issues
- Attempt automatic corrections where possible
- Proceed with warnings rather than blocking
- Generate documentation quality report
- Mark documentation as "needs review" if issues found
```

#### 6. Safety Mechanisms

**Critical Failures:**
Even in YOLO mode, agents must stop for:
- Security violations
- Data loss risks
- Broken git history
- Failed critical tests (determined by Product Owner rules)

**Decision Logging:**
All YOLO mode decisions must be logged in:
`progress/sprint_${no}/yolo_decisions.md`

#### 7. Timeout Parameters

**Design Approval Timeout:**
- Wait time: 60 seconds
- After timeout: Assume approval, proceed
- Log: "Auto-approved (YOLO timeout)"

**Test Retry Limit:**
- Initial attempt + 1 retry
- If still failing: Document and proceed
- Mark: "Partial implementation - test failures"

**Documentation Correction Attempts:**
- Attempt automatic fixes: Yes
- Max correction attempts: 2
- If unfixable: Log and proceed with warnings

### Implementation Plan

**Phase 1: PLAN.md Specification Update**
1. Add Mode field specification to PLAN.md format
2. Document Mode field values: `managed` (default) and `YOLO`
3. Add Mode field to current Sprint in PLAN.md as example

**Phase 2: rup-manager Enhancement**
1. Add PLAN.md reading and mode detection
2. Add conditional mode banner display (YOLO vs Managed)
3. Add YOLO decision summary at end (if YOLO mode)

**Phase 3: Agent Modifications**
1. Add PLAN.md reading to detect mode (all 5 agents)
2. Add YOLO-specific behavior branches
3. Add decision logging mechanisms
4. Add mode indicators (🚀 YOLO vs 📋 Managed)

**Phase 4: Documentation**
1. Update AGENTS.md with YOLO mode explanation
2. Update HUMANS.md with mode configuration instructions
3. Update PLAN.md template to include Mode field
4. Document mode values and behaviors

**Phase 5: Testing**
1. Set "Mode: YOLO" in PLAN.md, invoke `@rup-manager.md` → verify autonomous
2. Set "Mode: managed" in PLAN.md, invoke `@rup-manager.md` → verify interactive
3. Omit Mode field in PLAN.md → verify defaults to managed
4. Test individual agents reading mode from PLAN.md
5. Verify decision logging works in YOLO mode

### Benefits

1. **Autonomous Operation**: Full sprint can run unattended
2. **Faster Iteration**: No blocking on minor issues
3. **Documented Decisions**: All assumptions logged for review
4. **Flexible Control**: Can run full auto or step-by-step
5. **Safety Preserved**: Critical failures still stop execution
6. **Progressive Enhancement**: Works with existing agent structure
7. **Audit Trail**: Mode: YOLO in PLAN.md permanently records autonomous execution
8. **Compliance**: Clear record for reviews, audits, and retrospectives
9. **Transparency**: Anyone reading PLAN.md knows how sprint was executed

### Trade-offs

**Advantages:**
- Significantly faster development cycles
- Reduced human interruption
- Can run overnight or in CI/CD
- Documents all decision-making

**Disadvantages:**
- May make suboptimal assumptions
- Requires post-execution review of decisions
- Could propagate errors through phases
- Less human oversight during execution

### Testing Strategy

**Test Scenarios:**
1. **Full YOLO Run**: Execute rup-manager, verify autonomous operation
2. **Mixed Mode**: Run some agents in YOLO, others interactive
3. **Failure Handling**: Inject test failures, verify YOLO recovery
4. **Decision Logging**: Verify all decisions are documented
5. **Timeout Behavior**: Verify design approval timeout works

**Success Criteria:**
- ✅ YOLO banner displays correctly
- ✅ Agents detect YOLO mode from context
- ✅ Autonomous behaviors work as designed
- ✅ All decisions logged properly
- ✅ Critical failures still stop execution
- ✅ Interactive mode still works when YOLO disabled

### Files to Modify

1. **rup-manager.md** - Add YOLO mode banner and context
2. **agent-analyst.md** - Add YOLO mode behaviors
3. **agent-designer.md** - Add timeout and auto-approval
4. **agent-constructor.md** - Add test retry and error recovery
5. **agent-documentor.md** - Add auto-correction and proceed-with-warnings
6. **AGENTS.md** - Document YOLO mode
7. **HUMANS.md** - Document YOLO mode operation

### Configuration Examples

**Setting YOLO Mode for a Sprint:**

Edit PLAN.md:
```markdown
## Sprint 20

Status: Progress
Mode: YOLO

Backlog Items:
* GH-27. Trigger long running workflow via REST API
```

Then invoke:
```markdown
@rup-manager.md
```
→ Reads mode from PLAN.md, runs in YOLO mode

**Setting Managed Mode (Interactive):**

Edit PLAN.md:
```markdown
## Sprint 20

Status: Progress
Mode: managed

Backlog Items:
* GH-27. Trigger long running workflow via REST API
```

Then invoke:
```markdown
@rup-manager.md
```
→ Reads mode from PLAN.md, runs in managed mode

**Default Behavior (No Mode Field):**

If PLAN.md has no Mode field:
```markdown
## Sprint 20

Status: Progress

Backlog Items:
* GH-27. Trigger long running workflow via REST API
```

→ Defaults to **managed** mode (safe default)

**Single Agent Invocation:**

```markdown
@agent-analyst.md
```
→ Agent reads PLAN.md to detect mode automatically

### Open Questions

1. **Q:** Should YOLO mode be configurable (different timeout values)?
   **A:** Start with fixed parameters, make configurable in future if needed

2. **Q:** Should there be a "super YOLO" mode that never stops?
   **A:** No - keep safety mechanisms even in YOLO mode

3. **Q:** How to handle git commits in YOLO mode?
   **A:** Auto-commit with detailed messages including YOLO decisions

4. **Q:** Should YOLO mode send notifications on completion?
   **A:** Nice to have for future - document as potential enhancement

5. **Q:** Should rup-manager default to YOLO or Interactive?
   **A:** Proposed: Interactive by default (safer), require explicit YOLO activation

### Audit Trail and Traceability

One of the key benefits of the Mode: field approach is **permanent traceability**:

**Historical Record:**
```markdown
## Sprint 15 - REST API Implementation

Status: Done
Mode: managed

## Sprint 16 - Artifact Management  

Status: Done
Mode: YOLO

## Sprint 17 - Advanced Features

Status: Done
Mode: YOLO
```

From this PLAN.md history, you can immediately see:
- Sprint 15 was done with human supervision
- Sprints 16-17 ran autonomously
- Anyone reviewing the project understands execution context
- Compliance/audit requirements satisfied with clear record
- Retrospectives can correlate mode with outcomes

**Git History Shows Mode Changes:**
```bash
git log -p PLAN.md
```
→ Shows when Mode: YOLO was added/removed
→ Provides complete audit trail of autonomous vs managed sprints

**Benefits for Project Management:**
- **Compliance**: Satisfies audit requirements for AI-assisted development
- **Transparency**: Stakeholders know which work was autonomous
- **Learning**: Correlate mode with success metrics
- **Risk Management**: Identify which sprints had less human oversight
- **Documentation**: Self-documenting execution methodology

### Future Enhancements

1. **Configurable YOLO Parameters**: Timeout values, retry counts
2. **YOLO Profiles**: Conservative, Balanced, Aggressive
3. **Notification System**: Slack/Email on completion
4. **CI/CD Integration**: Run YOLO mode in GitHub Actions
5. **Decision Review UI**: Web interface to review YOLO decisions
6. **Learning System**: Improve assumptions based on past decisions
7. **Mode Statistics**: Report showing % of sprints in each mode
8. **Mode Recommendations**: AI suggests appropriate mode based on sprint complexity

### Design Approval

- Initial Status: Proposed
- Awaiting Product Owner review and approval
- Once approved, will proceed to Implementation phase

## Design Summary

YOLO mode is an additive enhancement to the existing agent system that enables autonomous operation while maintaining safety and traceability. The design is:
- **Feasible**: Works within current markdown-based agent architecture
- **Safe**: Preserves critical failure stops
- **Traceable**: Logs all autonomous decisions
- **Flexible**: Can be enabled/disabled per execution
- **Progressive**: Enhances without breaking existing workflows

The implementation will use convention-based mode detection with clear ASCII indicators and comprehensive decision logging.

