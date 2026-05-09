# Vibe Coding Without Holding Context — talk for Cybr Hak Con

Approver-facing summary for the vibe-coding talk. Title and executive summary are the version to share with reviewers; the line-item table of contents below is the structural follow-up for that conversation.

## Title

**Primary:** *How to Vibe Code Without Holding Context*

The primary keeps the speaker's framing and points at the resolution: the context exists, you just don't carry it. Reads as a how-to for a security-fluent crowd that wants practical patterns rather than evangelism.

**Alternate (drier):** *The Pattern That Builds Itself: AI Context Infrastructure for Real Projects*

The alternate names the recursion directly. More concept-forward; works if approvers want the title to match the security-conference register.

## Executive summary

Vibe coding fails on real projects because the agent runs out of context and the developer ends up holding the rest of the project in their head, which is the opposite of what vibe coding promised. The reframe of this talk is that you don't need a smarter agent; you need to pre-load the context the agent needs in a shape it can navigate, and ship that context as part of the project. The recursive insight is that the context infrastructure is itself a great vibe project, so each tool you build to make vibe coding work makes the next tool easier to build.

The talk walks five named pieces of context infrastructure: layered documentation written for the agent to read in a defined order, scoped agent definitions that constrain what each subagent owns, permission gates for destructive actions, a retrieval system for external knowledge, and a project template that bundles the pattern. Embeddings, vector stores, retrieval-augmented generation, and the Model Context Protocol are each defined from scratch when introduced; the talk assumes no AI vocabulary on the way in. Concrete examples of what to vibe next thread through every section, so the audience leaves with a recognition skill rather than a list of tools to copy.

The audience is the technically apt, security-fluent crowd at Cybr Hak Con, expected to be skeptical of agentic AI and unfamiliar with AI-specific terminology. The talk runs about fifty-five minutes inside a sixty-minute slot, leaves attendees with a single concrete first step (write `.abstract.md` and `.overview.md` for the project they're already in), and seeds further work without depending on it. The takeaway is the ability to recognize what context tool to build next given the friction in their current sessions.

## Contents (line-item)

1. **Opening: the reframe** (5 min) — vibe coding fails because the agent runs out of context; pre-load it instead
2. **Why vibe coding fails for real projects** (5 min) — hallucinated functions, wrong abstractions, repeated discovery cost
3. **The shape of pre-loaded context** (4 min) — five pieces named: layered docs, scoped agents, permission gates, retrieval, template
4. **Layered context documents** (8 min) — `.abstract.md`, `.overview.md`, source files; the discipline that keeps them current
5. **Scoped agents and the orchestrator pattern** (8 min) — per-component instructions, role agents, three-phase planning
6. **External knowledge: embeddings, vectors, RAG, MCP** (12 min) — audience-floor definitions, the four-part retrieval pattern
7. **The pattern compounds — what to vibe next** (6 min) — recognizing which context tool to build next
8. **What this doesn't fix** (3 min) — judgment, hallucination in unfamiliar libraries, ambiguous requirements
9. **Closing: what to vibe first** (5 min) — single concrete first step, the recurring question

Total runs to fifty-six minutes including transitions; compressible to forty-five by trimming sections 5, 6, and 7.
