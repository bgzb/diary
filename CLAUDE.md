### . Think Before Coding



**Don't assume. Don't hide confusion. Surface tradeoffs.**

LLMs often pick an interpretation silently and run with it. This principle forces explicit reasoning:

- **State assumptions explicitly** — If uncertain, ask rather than guess
- **Present multiple interpretations** — Don't pick silently when ambiguity exists
- **Push back when warranted** — If a simpler approach exists, say so
- **Stop when confused** — Name what's unclear and ask for clarification

### 2. Simplicity First



**Minimum code that solves the problem. Nothing speculative.**

Combat the tendency toward overengineering:

- No features beyond what was asked
- No abstractions for single-use code
- No "flexibility" or "configurability" that wasn't requested
- No error handling for impossible scenarios
- If 200 lines could be 50, rewrite it

**The test:** Would a senior engineer say this is overcomplicated? If yes, simplify.

### 3. Surgical Changes



**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- Match existing style, even if you'd do it differently
- If you notice unrelated dead code, mention it — don't delete it

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused
- Don't remove pre-existing dead code unless asked

**The test:** Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution



**Define success criteria. Loop until verified.**

Transform imperative tasks into verifiable goals:

| Instead of...    | Transform to...                                       |
| ---------------- | ----------------------------------------------------- |
| "Add validation" | "Write tests for invalid inputs, then make them pass" |
| "Fix the bug"    | "Write a test that reproduces it, then make it pass"  |
| "Refactor X"     | "Ensure tests pass before and after"                  |

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```



Strong success criteria let the LLM loop independently. Weak criteria ("make it work") require constant clarification.

### 5. Development Log



**After every coding session, write a dev log entry.**

After each modification session (not after every single edit, but after the user's request is completed), append to the "开发日记" group:

- **Where**: `开发日记` group → `YYYY-MM-DD-开发日志.md` (create if missing, append if exists)
- **Content** (all sections required):
  - **做了什么** — what was done, feature added, bug fixed
  - **发现了什么** — issues found, patterns noticed, edge cases discovered
  - **做错了什么** — mistakes made, wrong assumptions, things that needed fixing
  - **需要反思的地方** — what could have been done better, architectural concerns, design tradeoffs

**Storage path**: Read from `defaults read com.diary.app diary_storagePath`, default `~/Documents/Diary/entries`.

**Why**: The user wants a continuous record of development decisions, mistakes, and lessons learned.
**How to apply**: After `./build.sh && open Diary.app` succeeds, write the log entry before reporting completion.