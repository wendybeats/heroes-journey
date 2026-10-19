# 41 · Studio workflow (owner, 2026-10-19)

How Heroes Journey is planned, built, tested and reported from here on. These rules govern coordination, not game architecture; CLAUDE.md and the docs still govern implementation.

## Roles
| Role | Responsibility | Authority |
|---|---|---|
| Owner (Studio Director) | Vision, priorities, final creative decisions, budgets, releases | Final approval |
| ChatGPT (Product and Studio Strategy) | Planning, research, specifications, critiques, prioritisation | Recommend, prepare, update tasks |
| Claude (Engineering and Production) | Implementation, debugging, builds, technical QA, asset integration | Execute approved work |
| Linear | Tasks, progress, ownership, blockers, decisions | Authoritative project status |
| Slack | Progress summaries, handoffs, alerts, approvals | Communication, never task storage |

Linear project: **Heroes — Studio**. Slack: `#heroes-studio` (priorities, decisions, blockers, weekly summaries), `#heroes-build` (implementation updates, QA, releases, technical blockers), `#heroes-growth` (acquisition, research, marketing experiments).

## Operating rules for Claude
1. Substantive planned work uses the existing Linear issue, or a new one if none exists. No duplicates.
2. One outcome per issue, with a definition of done.
3. In Progress while actively executing.
4. Significant technical decisions and findings go on the issue.
5. Blocked means: record exactly what is missing and what decision or dependency unblocks it.
6. Done only when the acceptance criteria and test results confirm it, never because code was written. Implemented, verified and accepted are different things; checkboxes on the issue, not extra statuses.
7. Slack gets concise updates for meaningful milestones, blockers and work ready for review, not every code change.
8. Preserve the architecture unless the issue authorises a change.
9. Never independently start major product changes, external releases, spending or destructive actions.
10. An unrelated improvement found during work is captured as a suggestion, not folded into the task.

Within an approved task Claude may inspect code, plan, change code, run tests, fix directly related bugs and document. Claude asks before expanding scope, changing fundamental design, replacing architecture, irreversible data changes, public deployment, or paid services.

## Review handoff
When an issue is waiting on the owner (In Review, or a decision only the owner can take), assign it to the owner so the Linear "assigned to me" view is the review queue. Claude unassigns itself when handing over and takes it back when the review comes in.

## Issue format
Title (outcome), Why, Requirements, Acceptance criteria, References. Lifecycle: Backlog → Ready → In Progress → Blocked → Done.

## Completion report (on the issue, and in `#heroes-build` when it matters)
- Issue:
- Implemented:
- Tests/evidence:
- Known limitations:
- Status:
- Next action:

## Blockers
What is blocked, what is needed, who can resolve it, impact. On the issue; a short pointer in Slack.

## Handoffs
Neither agent assumes the other has seen a conversation. ChatGPT → Claude: the issue with requirements, references, constraints, acceptance criteria. Claude → ChatGPT: implementation summary, design discoveries, technical constraints, screenshots, open questions. Claude → owner: the playable result, not only a summary.

## Current objective
Prepare Chapter 1 for external testing, validate retention and engagement, begin acquisition experiments. Chapter 2 stays in preproduction.

## Keep it light
No unnecessary tickets, meetings, reports, autonomous agents or process. If documenting takes longer than doing, a lightweight issue note is enough. Release checklist for Chapter 1: build runs, critical paths tested, experience acceptable, analytics events working, owner approves; recorded on the release issue.
