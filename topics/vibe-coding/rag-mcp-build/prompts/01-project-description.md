# Step 01 — Project description

## What this step accomplishes (read this yourself)

You'll set up `.abstract.md` — a roughly 100-token summary of what you're building. From this point forward your assistant owns this file. As the project shape changes in later steps, the assistant keeps it current. You stay in the loop by reading what it writes and redirecting when something is off, but **you don't edit the file by hand** — you tell the assistant what should change and why.

That ownership pattern (the assistant owns the project's context infrastructure; you direct) is the headline thing being taught here. It will recur in every later step for `.overview.md`, per-subsystem layered docs, and the role agent files.

You don't have an `AGENTS.md` yet — that arrives in step 03. For now, point your assistant at this prompt directly and follow along.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant set up step 01 of a six-step build. The deliverable is a Retrieval-Augmented Generation tool with a Model Context Protocol server interface that ingests the HackTricks repository and exposes search. For this step, you're not building any of that — you're capturing the participant's intent into a single short orientation file.

Operate in the project's working directory (wherever the participant is running you from). All file paths below are relative to that directory.

### Step 1 — confirm fresh start

Check whether `.abstract.md` already exists. If it does, the participant has either run this step before or imported a file from elsewhere. Read it, summarise its content for the participant, and ask whether to:
- Keep it as-is and skip to the next workshop step
- Rewrite it from scratch (continue with the questions below)
- Edit specific parts (ask which)

If `.abstract.md` doesn't exist, proceed to the questions.

### Step 2 — ask three orienting questions

Ask the participant these questions, **one at a time**, and wait for each answer before asking the next. Do not draft anything until all three are answered.

1. **What problem does this project solve, in one sentence?** For the workshop's reference build, the answer is something like *"Make HackTricks searchable by an LLM agent so it can look up techniques without re-reading every page."* The participant may pick a different scope; honour their answer.
2. **Who will use it, and in what context?** Themselves working through a security task? A team's MCP-aware tooling? An automated CI workflow? The answer shapes what "useful" means for this build.
3. **What does the smallest useful version look like?** Not the full feature set — the smallest version that does anything useful. For the workshop's reference, that's *"ingest HackTricks once, expose a search endpoint that returns relevant chunks."* Participants on a different scope answer for themselves.

If any answer is vague (e.g. "I want it to be fast and easy"), push back gently — ask for one specific concrete example. The L0 file is going to be ~100 tokens; vague inputs produce vague summaries that don't help the next session.

### Step 3 — propose `.abstract.md`

Once all three answers are clear, draft `.abstract.md` in the project root targeting roughly 100 tokens. Use this format:

```markdown
# .abstract.md — <project-name>

L0 project map. For full detail, read `.overview.md` (L1) or each subsystem's own `.abstract.md` and `.overview.md`.

<one-paragraph project description, ~50 tokens, derived from the three answers>

| Subsystem | Path | Purpose |
|-----------|------|---------|
| <!-- subsystems are defined in step 02 — leave this row as a placeholder until then --> | | |
```

The token budget matters. ~100 tokens is small enough that any future session reads it without burning context. The placeholder subsystem row is intentional — step 02 fills it in.

Show the draft to the participant. Ask: *"Does this match what you want this project to be? Anything to add, cut, or rephrase before I write it?"* Iterate on their feedback. Do not write the file until they approve.

### Step 4 — write the file and declare ownership

Write `.abstract.md` to disk. Then tell the participant explicitly, in roughly these words:

> From this point forward I own `.abstract.md`. When the project's shape changes in later steps, I'll keep it accurate. If you want something in it to change, tell me what and why — don't edit the file by hand.
>
> If a change you ask for doesn't fit the wider project context, I'll push back rather than make it silently. The point of layered docs is that they stay coherent; an edit that contradicts the rest of the project would defeat that.
>
> This same ownership pattern applies to every layered doc you'll see in later steps — `.overview.md` at the project root in step 02, then per-subsystem `.abstract.md` and `.overview.md` files in step 03 onward.

### Step 5 — stop

Do not proceed to step 02 within this prompt. Stop here. Wait for the participant to invoke the next prompt (`prompts/02-output-and-interface.md`) when they're ready.

If the participant asks "what's next?" before invoking, summarise step 02 in one sentence (*"Step 02 picks the project's subsystems, stack, and external endpoints, and produces the root `.overview.md`."*) but do not start it.

## Outputs you'll have at the end of this step

- `.abstract.md` at the project root, roughly 100 tokens, owned by your assistant
- A clear-enough mental model to answer "what is this project?" in one sentence
- The ownership pattern declared explicitly between you and the assistant — carries forward to every other layered doc in this workshop
