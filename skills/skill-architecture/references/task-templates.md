**Skill**: [Skill Architecture](../SKILL.md)

# Task Templates

**MANDATORY**: Select and load the appropriate template before any skill work.

> For detailed context on each step, see [Skill Creation Process (Detailed Tutorial)](./creation-tutorial.md) or [Creation Workflow](./creation-workflow.md).

## Template A: Create New Skill

```
1. Gather requirements (ask user for functionality, examples, triggers)
2. Identify reusable resources (scripts, references, assets needed)
3. Run `scripts/init_skill.py <name> --path <dir>` to create the skill directory structure
4. Create bundled resources first (scripts/, references/, assets/)
5. Write SKILL.md with YAML frontmatter (name, description with triggers)
6. Add task templates section to SKILL.md
7. Add Post-Change Checklist section to SKILL.md
8. Validate with `scripts/validate_skill.py`
9. Test skill on real example
10. Register skill in project CLAUDE.md
11. Verify against Skill Quality Checklist below
```

## Template B: Update Existing Skill

```
1. Read current SKILL.md and understand structure
2. Identify what needs changing (triggers, workflow, resources)
3. Make targeted changes to SKILL.md
4. Update any affected references/ or scripts/
5. Validate with `scripts/validate_skill.py`
6. Test updated behavior
7. Update project CLAUDE.md if description changed
8. Verify against Skill Quality Checklist below
```

## Template C: Add Resources to Skill

```
1. Read current SKILL.md to understand skill purpose
2. Determine resource type (script, reference, or asset)
3. Create resource in appropriate directory
4. Update SKILL.md to document new resource
5. Validate with `scripts/validate_skill.py`
6. Test resource integration
7. Verify against Skill Quality Checklist below
```

## Template D: Troubleshoot Skill Not Triggering

```
1. Check YAML frontmatter syntax (no colons in description)
2. Verify trigger keywords in description match user queries
3. Ask Claude to quote the description back ("when would you use X?") to expose the gap between the triggers you wrote and what Claude perceives (see [Troubleshooting](./troubleshooting.md))
4. Check skill location (~/.claude/skills/ or project .claude/skills/)
5. Validate with `scripts/validate_skill.py` for errors
6. Test with explicit trigger phrase
7. Document findings in skill if new issue discovered
8. Verify against Skill Quality Checklist below
```

## Template E: Create Lifecycle Suite

```
1. Identify lifecycle phases needed (bootstrap, operate, diagnose, configure, upgrade, teardown)
2. Create one skill per lifecycle phase (see Suite Pattern in Structural Patterns)
3. Create shared library in scripts/lib/ for common functions (logging, locking, config)
4. Create commands for most-used operations (setup, health, hooks)
5. Add hooks for event-driven automation if cross-session behavior needed
6. Ensure skills cross-reference each other (health check failure -> suggest diagnostic skill)
7. Write CLAUDE.md for the plugin (conventions, key paths, shared library API)
8. Validate each skill with `scripts/validate_skill.py`
9. Test full lifecycle: bootstrap -> operate -> diagnose -> configure -> upgrade -> teardown
10. Verify against Skill Quality Checklist below
```

## Skill Quality Checklist

After ANY skill work, verify:

- [ ] YAML frontmatter valid (name lowercase-hyphen, description has triggers)
- [ ] `name` matches parent directory name exactly, no consecutive hyphens (`--`)
- [ ] Description includes WHEN to use (trigger keywords)
- [ ] Description not too broad (doesn't false-trigger on unrelated conversations)
- [ ] SKILL.md body under 500 lines (move detail to `references/`)
- [ ] Classify skill as **reference** (inline knowledge) or **task** (side-effect action):
  - `disable-model-invocation: true` ONLY for hook-installation skills — all others keep `false` (default)
  - Reference-only skills users shouldn't invoke: set `user-invocable: false`
- [ ] If using `context: fork`, skill has explicit actionable instructions (not guidelines-only)
- [ ] If skill requires external tools (git, docker, jq), add `compatibility` field
- [ ] Task templates cover all common scenarios
- [ ] Post-Change Checklist included for self-maintenance
- [ ] Final template step references this checklist
- [ ] Project CLAUDE.md updated if new/renamed skill
- [ ] Validated with `scripts/validate_skill.py`
- [ ] All markdown links use relative paths (plugin-portable)
- [ ] No broken internal links (`scripts/validate_skill.py` passes)
- [ ] Tested activation **both ways**: manual `/name` AND organic trigger keywords
- [ ] Run `/context` to verify skill is loaded (not excluded by description budget)
- [ ] Phased execution: task templates use `[Preflight]`/`[Execute]`/`[Verify]` labels where applicable
- [ ] Interactive: AskUserQuestion used for destructive actions and multi-option workflows
- [ ] No unsafe path patterns (see [Path Patterns](./path-patterns.md)):
  - No hardcoded `/Users/<user>` or `/home/<user>` (use `$HOME`)
  - No hardcoded `/tmp` in Python (use `tempfile.TemporaryDirectory`)
  - No hardcoded binary paths (use `command -v` or PATH)
- [ ] Bash compatibility verified (see [Bash Compatibility](./bash-compatibility.md)):
  - No `declare -A` (associative arrays) - use parallel indexed arrays
  - No `grep -P` (Perl regex) - use `grep -E` with awk
  - No `\!=` in conditionals - use `!=` directly
