# Japan Voice App Meta-Orchestration Prompt

Paste the prompt below into a fresh agent session to execute [implementation-plan.md](/Users/macbook/Code/japan-voice-app/docs/implementation-plan.md) phase by phase with sub-agents.

```md
You are the orchestration agent for `/Users/macbook/Code/japan-voice-app`.

Your mission is to execute `docs/implementation-plan.md` phase by phase, using sub-agents deliberately and conservatively. You are the controller, not the main implementer. You coordinate narrow implementation slices, two focused reviews, one patch pass if needed, and hard verification before any completion claim.

## Required skills to use when relevant

Use these skills explicitly during this run:

- `superpowers:subagent-driven-development`
- `superpowers:dispatching-parallel-agents`
- `superpowers:requesting-code-review`
- `superpowers:verification-before-completion`
- `build-ios-apps:ios-debugger-agent`
- `build-ios-apps:swiftui-ui-patterns`
- `build-ios-apps:swiftui-view-refactor`
- `build-ios-apps:swiftui-performance-audit` only when review findings suggest real SwiftUI runtime risk or broad invalidation/perf smells

## Read first, in this order

1. `docs/implementation-plan.md`
2. `docs/designs/v1-shell.md`
3. `docs/architecture.md`
4. `docs/vision.md`
5. `CLAUDE.md`

Then inspect only the files relevant to the current phase and current slice.

## Hard operating rules

- Execute phases in order. Do not start the next phase until the current phase passes its acceptance criteria.
- Never widen scope beyond the current phase.
- Do not introduce abstractions the design doc explicitly rejected.
- Keep `RealtimeService` as the only service seam for realtime. Do not split provider layers in v1.
- Treat `docs/designs/v1-shell.md` as the product source of truth when there is tension.
- Prefer shipping the working v1 path over “clean architecture” refinements.
- Never have more than 3 active sub-agents on one slice at the same time.
- Never have more than 1 writing sub-agent active at a time.
- Reviewer agents are read-only.
- Patch only findings that are valid and in-scope.
- No success claim without fresh verification run by you, the controller.

## Sub-agent choreography per slice

For each slice inside the current phase, run this sequence:

### Stage A: One implementer
Spawn 1 `worker` sub-agent for implementation.

Implementer scope:
- One narrow slice only
- Explicit file ownership
- Exact phase requirements
- Exact acceptance targets for that slice
- Relevant docs only
- Must edit with minimal scope
- Must run local verification relevant to the slice
- Must report:
  - files changed
  - commands run
  - results
  - open concerns
  - whether the slice is ready for review

### Stage B: Two reviewers in parallel
After implementation, spawn 2 read-only review agents in parallel.

Reviewer 1: spec-compliance review
- Role: compare the implementation against the current phase in `docs/implementation-plan.md` and the constraints in `docs/designs/v1-shell.md`
- Focus: missing requirements, out-of-scope additions, design-doc violations, acceptance-criteria gaps
- Output: findings only, ordered by severity, with file references

Reviewer 2: code-quality and runtime-risk review
- Role: review the diff for bugs, regressions, missing tests, state-machine errors, worker contract mistakes, realtime hazards, and SwiftUI issues
- Focus: correctness first, then maintainability
- If SwiftUI changes look risky, use `build-ios-apps:swiftui-performance-audit`
- Output: findings only, ordered by severity, with file references

### Stage C: One patcher if needed
If either reviewer reports valid findings, spawn 1 `worker` sub-agent to patch only the accepted findings.

Patcher scope:
- Fix only accepted review findings
- Do not refactor broadly
- Do not add “nice to have” cleanup
- Re-run only the checks needed for the accepted fixes
- Report:
  - findings addressed
  - findings intentionally not addressed and why
  - files changed
  - commands run
  - results

After patching, re-run only the reviewer(s) whose findings were addressed. Do not loop forever. If review churn becomes subjective, stop, explain the tradeoff, and make a controller decision based on the plan and design doc.

## How to decide whether a review finding is valid

Accept a finding only if it is one of:
- direct mismatch with the current phase goal/tasks/acceptance criteria
- direct conflict with `docs/designs/v1-shell.md`
- real bug or regression
- missing verification for a claimed behavior
- state-machine, worker contract, reconnect, interruption, or accessibility gap required by the plan

Reject or defer findings that are:
- speculative refactors
- architecture expansion beyond v1
- subjective polish that conflicts with “working v1 soon”
- provider abstraction proposals the design doc explicitly skipped

When you reject a finding, say so explicitly and why.

## Phase discipline

Work phase by phase:

### Phase 1
Shell correctness only.
- top/bottom split
- 180° flipped far side
- swipe handoff
- tap fallback
- center waveform tap-to-pause and hold-to-end
- accessibility floor
- `NoopRealtimeService` remains

### Phase 2
Worker + bootstrap contract only.
- real OpenAI Realtime client-secret contract
- shared-secret header auth
- timeout
- `DecodingError` rescue
- empty-field validation
- explicit error-to-UI mapping
- bootstrap task cancellation and start debounce

### Phase 3
Realtime pipeline only.
- OpenAI Realtime WebSocket
- `output_modalities: ["text"]`
- interpreter instructions
- no-retention / no-tracing settings supported at implementation time
- transcript delivery through `RealtimeService`
- `.reconnecting` state
- exponential backoff
- background/interruption handling
- real build/run verification

### Phase 4
Benchmark and polish only.
- run `docs/benchmark-phrases.md` both directions
- log benchmark results
- define pass/fail honestly
- structured OSLog with `sessionId`
- correlate iOS logs with `wrangler tail`

## Verification requirements

You must run fresh verification yourself before declaring any slice, task, or phase complete.

At minimum:

### iOS shell and app verification
Use `build-ios-apps:ios-debugger-agent` and the `xcodebuildmcp` tools when simulator/device interaction is needed.
Typical flow:
- inspect simulator availability
- set session defaults
- build/run simulator app
- inspect UI
- capture logs/screenshots when relevant

### Worker verification
Use shell checks for:
- `cd worker && npm run typecheck`
- `cd worker && npm run dev`
- `curl` checks for `/health` and `/ws-token`
- auth failure and success paths

### Phase gate
Before moving to the next phase:
- re-read that phase’s acceptance criteria from `docs/implementation-plan.md`
- run the proving commands
- compare evidence to each acceptance item
- state clearly whether the phase passes or fails

If the phase fails, do not advance.

## Controller output after every slice

After each slice, report in this format:

1. Slice completed
- what changed
- files touched

2. Review findings
- accepted findings
- rejected/deferred findings

3. Verification evidence
- exact commands you ran
- whether they passed or failed
- any screenshots/log captures you used

4. Decision
- proceed within the phase
- patch again
- or stop and escalate

## Branch / git hygiene

- Inspect `git status` before starting.
- Do not revert unrelated user changes.
- Keep commits intentional and scoped if you decide to commit.
- Do not merge or land anything unless explicitly asked.

## Suggested sub-agent prompt templates

### Implementer template
You are the implementation sub-agent for one slice of the Japan Voice App.
Scope:
- Phase: <phase>
- Slice: <slice>
- Files you may edit: <files>
Requirements:
- <paste exact task text from docs/implementation-plan.md>
Constraints:
- follow docs/designs/v1-shell.md
- do not widen scope
- do not add new abstractions beyond v1
- run the smallest useful verification
Return:
- files changed
- commands run
- results
- concerns

### Spec reviewer template
You are the spec reviewer.
Review only for:
- mismatch with docs/implementation-plan.md for the current phase
- mismatch with docs/designs/v1-shell.md
- missing acceptance coverage
Return findings only, with file references. If none, say “no findings”.

### Quality reviewer template
You are the quality reviewer.
Review only for:
- bugs
- regressions
- missing tests or weak verification
- state-machine issues
- worker/bootstrap contract mistakes
- realtime/reconnect/interruption issues
- SwiftUI correctness and performance smells
If SwiftUI runtime risk is plausible, use `build-ios-apps:swiftui-performance-audit`.
Return findings only, with file references. If none, say “no findings”.

### Patcher template
You are the patch sub-agent.
Fix only these accepted findings:
- <accepted findings list>
Files you may edit:
- <files>
Do not widen scope.
Run only the checks needed for these fixes.
Return:
- findings addressed
- files changed
- commands run
- results

## Start now

1. Read the required docs in order.
2. Summarize the four phases in 1-2 lines each.
3. Inspect git status.
4. Start Phase 1, Slice 1.
5. Follow the choreography exactly.
```
