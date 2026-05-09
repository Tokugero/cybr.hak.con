# Step 05b — First red-green cycle

## What this step accomplishes (read this yourself)

You'll write the *first* failing test, then the *minimum* implementation to pass it, then refactor. One feature, one cycle. The discipline is straight from the speaker's `tdd` skill: red (test fails for the right reason) → green (test passes with minimum code) → refactor (clean up without changing behaviour).

The feature you pick first matters. The right pick exposes the most integration risk early — for this build, that's *"embed a query, search the vector store, return ranked results."* If that works end-to-end, the architecture is sound and the rest of the features fall out naturally. Picking a peripheral feature first (e.g. tag extraction) leaves the integration risk for later, which is the opposite of what TDD is for.

This is one cycle. Step 05c is re-invokable for every additional feature. Don't try to cycle multiple features in this prompt — the discipline of stopping after one cycle is what makes the loop tight.

## Instructions for the assistant (paste this part to your assistant)

You are helping a workshop participant run the first TDD red-green-refactor cycle. The deliverable is one passing test for the most important behaviour, plus the minimum implementation to make it pass.

Read `AGENTS.md`, the root `.overview.md`, each subsystem's `.overview.md`, and the test scaffold from step 04. Re-read the interfaces from step 05a if needed.

### Step 1 — pick the first behaviour with the participant

Recommend: *"the most important behaviour is end-to-end search — embed a query, search the store, return results. If we can make that work with the fake_embedder and fake_store from step 04's conftest, we know the composition works. Other features build on top of this."*

The participant may push back: *"I want to test chunking first because that's where the trickiest logic is."* That's fine, but warn them: *"chunking is logic-heavy and easy to test in isolation, but it doesn't exercise the integration. If we test chunking first and search second, we don't catch a search bug until later. If we test search first and chunking second, the integration risk is paid early."*

Whatever they pick, capture it as one specific verifiable statement. *"Search returns the seeded chunk top-1 when the query mentions a keyword from the chunk's text"* is testable. *"Search works"* is not.

### Step 2 — confirm the behaviour list

Even though we're only writing one test now, list 2–4 behaviours the implementation should satisfy so the participant knows what's in scope versus what's deferred to step 05c. For the reference build, search behaviour list:

1. Returns top-1 result for a seeded chunk when the query keyword matches.
2. Returns an empty list when the store is empty.
3. Returns up to `top_k` results, defaulting to 10.
4. Sorts results by descending score.

Pick *one* — the headline behaviour — for this cycle. The rest go into step 05c's queue.

### Step 3 — write the failing test (red)

In the appropriate test file (`<library>/tests/test_search.py` for the reference), write one test for the chosen behaviour. It must:

- Be named clearly after the behaviour: `test_search_returns_seeded_chunk_top_one_when_keyword_matches`.
- Use the conftest fixtures from step 04 (`fake_embedder`, `fake_store`, `sample_chunks`).
- Test exactly one behaviour — no incidental assertions about other things.
- Fail for the right reason — call the method that doesn't exist yet, not import a missing module.

Run the test:

```sh
cd <library>/ && uv run pytest tests/test_search.py::<test_name> -v
```

Confirm it fails because the method body is `NotImplementedError`, not because of a syntax or import error. If it fails for the wrong reason, fix the test infrastructure first.

### Step 4 — write the minimum implementation (green)

Implement the smallest code path that makes the failing test pass. For the search test, that's `SearchService.search`:

```python
async def search(self, query: str, top_k: int = 10) -> list[SearchResult]:
    vector = await self.embedder.embed(query)
    return await self.store.search(vector, top_k=top_k)
```

That's three lines. It works because the fakes already do the right thing internally. Do *not* add features the test doesn't exercise (caching, retries, batching, etc.). If the participant asks for more, defer it to step 05c.

Run the test again. Confirm green:

```sh
cd <library>/ && uv run pytest tests/test_search.py::<test_name> -v
```

If any pre-existing test broke, fix it before continuing.

### Step 5 — refactor

With the test green, look at what you wrote. For each:
- Names that don't match intent → rename.
- Duplication that's already visible → factor.
- Comments explaining what the code does → rewrite the code to be self-explanatory; delete the comment.

Run tests after each refactoring change to confirm nothing broke. Don't add new behaviour during refactor.

If there's nothing to refactor, say so explicitly and skip — refactor-for-the-sake-of-it is itself a code smell.

### Step 6 — update `.overview.md` Exports column if signatures changed

If the implementation changed any public signature from what step 05a captured, update the Exports column in the relevant `.overview.md`. This is the living-docs discipline in action — the doc reflects current reality, not what you wrote two steps ago.

### Step 7 — offer an SOP

If the work involved any non-obvious decision (a quirky behaviour of the test fixture, a workaround for a library version, etc.), ask the participant: *"This had a non-trivial decision in it — would you like me to save it as `kb/sop-<action-name>.md` so the next session doesn't have to re-derive it?"* If yes, write the SOP using the format in `kb/README.md`.

Most first cycles produce no SOP-worthy decisions. That's fine.

### Step 8 — stop

Do not iterate to additional features. Wait for the participant to invoke `prompts/05c-iterate.md`.

## Outputs you'll have at the end of this step

- One passing test exercising the most important behaviour
- Minimum implementation across the modules to make that test pass
- Refactoring done if anything visible needed it
- `.overview.md` Exports column updated for any signature drift
- Optionally: `kb/sop-...md` capturing a non-trivial decision
