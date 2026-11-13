You are reviewing code development for specific tasks in this project.

**CRITICAL: You MUST perform a complete, thorough review of all selected tasks, even if:**
- Progress documents indicate the task is "complete" or "reviewed"
- The PHASES_SUMMARY.md shows the task as done
- Previous reviews exist in any documentation
- The task appears to have passing tests

The purpose of this command is to VERIFY the work was actually done correctly, not to trust status indicators.

## Step 1: Identify Tasks to Review

Parse the command arguments to determine scope:

**IF only a phase number is provided** (e.g., "/checkwork 1" or "/checkwork Phase 1"):
- Review ALL tasks within that phase
- Find all commits matching "Phase X." pattern (e.g., "Phase 1.1", "Phase 1.2", etc.)
- Include all sub-tasks from 1.0, 1.1, 1.2, etc.

**IF specific task numbers are provided** (e.g., "/checkwork 1.3" or "/checkwork 1.2 1.3" or "/checkwork Phase 1.2 and 1.3"):
- Parse the specific task numbers from the arguments
- Review ONLY those specific tasks
- Examples: "1.3" means Phase 1, task 3; "11.2" means Phase 11, task 2

**IF no arguments were provided**:
- Ask Keith which tasks to review (e.g., "Which tasks would you like me to review? (e.g., 'Phase 1' for all of Phase 1, or '1.3' for a specific task)")
- Wait for response before proceeding

## Step 2: Load Documentation Context

For each task to review:

1. Read `docs/plans/PHASES_SUMMARY.md` to understand:
   - The high-level phase goals
   - Expected deliverables
   - Acceptance criteria
   - Current status

2. Read the relevant sections of the detailed implementation plan document(s) in `docs/plans/` for the phase being reviewed

## Step 3: Review Implementation

For each task:

1. **Find Related Commits**:
   - Use `git log --oneline --all --grep="Phase X.Y"` to find commits
   - Read commit messages to understand what was done
   - Note the commit SHAs for detailed inspection

2. **Examine Code Changes**:
   - For each commit, use `git show <commit-sha>` to see the changes
   - Review the code for:
     - Proper implementation of requirements
     - Code quality and style
     - ABOUTME comments at the top of new files
     - Following project conventions

3. **Review Tests**:
   - Check for test files associated with the implementation
   - Run the project's test suite to verify current test status
   - Look for test coverage of the new features
   - Verify TDD was followed (tests written first)

4. **Check for Required Files**:
   - Verify all deliverables mentioned in the documentation exist
   - Check database migrations if applicable
   - Verify UI screens/components were created as specified

## Step 4: Compare Against Requirements

For each task, create a checklist:

1. **Documented Deliverables**:
   - [ ] List each deliverable from the documentation
   - [ ] Mark whether it was implemented

2. **Acceptance Criteria**:
   - [ ] List each acceptance criterion
   - [ ] Mark whether it was met

3. **Test Coverage**:
   - [ ] Count of tests added
   - [ ] Whether tests are passing
   - [ ] Coverage of key functionality

4. **Code Quality**:
   - [ ] ABOUTME comments present
   - [ ] Follows project patterns
   - [ ] No obvious bugs or issues

## Step 5: Generate Review Report

Provide a comprehensive report for each task reviewed:

### Task X.Y: [Task Name]

**Requirements Summary:**
- [Brief summary of what was supposed to be implemented]

**What Was Implemented:**
- [List of commits and what they did]
- [Files created/modified]
- [Key features added]

**Test Coverage:**
- Tests added: X
- Tests passing: Y/Z
- Key areas tested: [list]

**Acceptance Criteria:**
- ✅ [Met criterion 1]
- ✅ [Met criterion 2]
- ⚠️  [Partially met criterion 3]
- ❌ [Unmet criterion 4]

**Code Quality Observations:**
- [Positive findings]
- [Concerns or issues]
- [Suggestions for improvement]

**Overall Assessment:**
- [COMPLETE / INCOMPLETE / NEEDS WORK]
- [Summary statement]

## Step 6: Provide Overall Summary

After reviewing all requested tasks, provide:

1. **Summary Table**:
   | Task | Status | Tests | Issues |
   |------|--------|-------|--------|
   | X.Y  | ✅     | 5/5   | None   |

2. **Key Findings**:
   - [Important observations across all tasks]
   - [Patterns noticed]
   - [Recommendations]

3. **Next Steps** (if any issues found):
   - [Specific actions needed]
   - [Priority order]

## Important Notes:

- **NEVER skip the review based on status indicators** - Always verify the actual code and commits
- **NEVER trust that "complete" means "correct"** - The point is independent verification
- If documentation says a task is complete but you can't find evidence in the commits, flag this as an issue
- Be thorough and systematic in your review
- Don't skip steps even if they seem tedious
- Look for both what was done well and what could be improved
- Be honest about issues - Keith depends on accurate technical judgment
- If you find something confusing, note it in the report
- Consider whether the implementation matches the spirit of the requirements, not just the letter
- Check that the code follows the project's CLAUDE.md rules (TDD, DRY, YAGNI, etc.)
