---
name: router
description: Routes queries to cost-appropriate models based on task complexity. Matches patterns in user messages to select cheaper models for routine tasks and more capable models for complex work. Reduces API costs by 80-90%.
---

# Model Router

Automatically routes requests based on keyword patterns to optimize API costs.

**Pattern-based routing:**
- Routine tasks: email, schedule, remind, calendar, list, show, get, fetch, find, search, summarize
- Complex tasks: code, debug, plan, strategy, brainstorm, analyze, design, explain, reason

Model selection logic and pricing decisions are in `router.py`.
