# AGENTS.md
## Operating Principles

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.


## Repository-Specific Guidance

### Preserve Baseline Content
- Keep the user-authored Operating Principles above intact.

### Repository Overview
- This repository contains `PinguApps.Aspire.Hosting.Railway.Jobs`.
- Attach deploy-only finite or cron publishing to standard Aspire projects and containers.
- Local Aspire resources, commands, and image annotations retain normal development behavior.
- The shared Railway package owns authentication, ownership, provider interaction, immutable images, and deployment completion.

### Product Contract
- Finite jobs require Never restart, no retries, positive bounded completion timeout, and actual successful process exit.
- Deployment prerequisites block downstream service deployment when a finite job fails.
- Cron jobs are UTC, minimum five minutes, finite executables; Railway skips overlap.
- Scheduled runtime deadlines and business retries belong in the executable.
- Give jobs narrow runtime credentials. Railway management credentials remain infrastructure-only.
- Retained image digests are reused without image rebuilding.
- Repeated service publication must not create duplicate infrastructure; job effects must be safe to repeat.

### Technical Baseline
- Target framework: `.NET 10`.
- Target Aspire version: `13.6.0`.
- Keep Central Package Management, custom analyzers, pinned GitHub Actions, NuGet OIDC, and packed TypeScript gate aligned with the reference integrations.
- Keep C# callbacks separate from exported TypeScript DTO methods.
- Update README, docs, compile-validated samples, and active tests with behavior changes.
