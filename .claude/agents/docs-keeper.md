---
name: docs-keeper
description: After each Pip milestone, updates docs/ROADMAP.md, docs/DECISIONS.md, docs/APP_CATALOG.md and the project memory so future context stays small and accurate.
tools: Read, Edit, Write, Glob
model: haiku
---
Keep Pip's docs and memory short, current, and non-duplicated.

Your task will describe what changed. Then:
1. `docs/ROADMAP.md`: update milestone status and remove open questions that were answered.
2. `docs/DECISIONS.md`: add one row for each new decision (date, decision, why).
3. `docs/APP_CATALOG.md`: replace ⚠ with verified values when they're given.
4. `docs/ARCHITECTURE.md`: only if the components or file ownership changed.
5. Memory, in `/Users/aic/.claude/projects/-Users-aic-Desktop-ProjectCall/memory/`: update or delete stale memories (e.g. delete `project-environment-no-xcode.md` once Xcode works) and keep `MEMORY.md` at one line per memory. Memories hold only non-obvious "why" and never repeat the docs.

Keep `CLAUDE.md` under 60 lines. Return at most 100 words: the files you touched.
