# Vibe Coding Without Holding Context — talk for Cybr Hak Con

Approver-facing summary for the vibe-coding talk. Title and executive summary are the version to share with reviewers; the line-item table of contents below is the structural follow-up for that conversation.

## Title

**Primary:** *How to Vibe Code Without Holding Context*

The primary keeps the reframe in the title: the project context exists, you just don't carry it. Reads as a how-to for a security-fluent crowd that wants concrete patterns rather than evangelism.

**Alternate (drier):** *Patterns for Shipping with AI: Layered Context, Validation Loops, Test Shapes, Parallel Build*

The alternate names the four patterns directly. More concept-forward; works if approvers want the title to match the security-conference register.

## Executive summary

Vibe coding fails on real projects because the developer ends up holding the whole project in their head, which is the opposite of what vibe coding promised. The reframe of this talk is that you don't need a smarter agent or more elaborate tooling; you need to apply four patterns that move the project's mental load out of your head and into the project itself, where the agent can read it. The talk is a personal share of how the speaker actually ships work using these patterns: layered context documents that shrink the input and sharpen the output, validation loops that confirm the agent's work without reading every line, testing shapes that signal what's actually broken instead of what merely changed, and project layouts that let multiple workstreams build in parallel without colliding.

Embeddings, vector stores, retrieval-augmented generation, and the Model Context Protocol come up only as examples of small useful tools you can build using these patterns — they are not the content of the talk. For attendees who want a hands-on follow-up, an optional self-driven workshop walks through building one such tool (a dockerized RAG-backed MCP server) using exactly the patterns the talk describes, with the side effect of teaching what RAG and MCP actually are by having you build them. The workshop format is a folder of prompt files, one per step; participants explicitly invoke each prompt and choose how much of the work to drive themselves versus delegate to AI.

The audience is the technically apt, security-fluent crowd at Cybr Hak Con, expected to be skeptical of agentic AI hype and unfamiliar with AI-specific terminology. The talk runs about fifty-five minutes inside a sixty-minute slot, leaves attendees with a single concrete first step (have their assistant draft and take ownership of `.abstract.md` for a project they are already in), and seeds further work without depending on it. The takeaway is the recognition skill — knowing which pattern to apply given the friction in your current sessions — rather than a list of tools to copy.

## Contents (line-item)

1. **Opening: the reframe** (4 min) — vibe coding fails because the developer holds context the project should hold; pre-load it instead, in a shape the agent can navigate
2. **Layered context documents** (10 min) — `.abstract.md` at the top, `.overview.md` below it, source as the deepest layer; the discipline that keeps the layers current as the project grows; why precision beats volume for the agent's input
3. **Validation tools and steps** (10 min) — the feedback loop that lets you trust the agent's output without reading every line; what gets wired in (build, lint, type, test, custom checks); the gap between "code compiles" and "code is right"
4. **Testing shapes and purpose** (10 min) — different test shapes for different signals; what AI workflows tend to over-test (mechanical changes) and under-test (interface contracts); how to compose shapes so the green build actually means something
5. **Positioning a project to build in parallel** (10 min) — decomposing work so multiple workstreams (you and agents, or agents and agents) don't collide on shared state; how parallel-by-construction layouts compress the MVP timeline; the role of dedicated subagents (code-focused, SRE-focused) once shape is established
6. **What this doesn't fix** (4 min) — judgment about what to build, hallucination in unfamiliar territory, ambiguous requirements, the human review gate
7. **Closing: pick one to start with** (3 min) — single concrete first step (have your assistant draft and take ownership of `.abstract.md` for a project you're already in; from there the assistant owns keeping the layered docs current as the project evolves), and a pointer to the optional workshop for attendees who want to build a small tool that exercises all four patterns

Total runs to fifty-one minutes including transitions; comfortably inside a sixty-minute slot. Compressible to forty-five by trimming the parallel-build section, which has the most material that lives in the optional workshop anyway.
