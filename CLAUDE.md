# CLAUDE.md - Project Configuration for Claude Code

This project follows the Special Claude Code Workflow for rapid, high-quality development.
Reference: @CONTEXT.md for project architecture, @docs/01-scope.md for current objectives, @PLAYBOOK.md for project-specific patterns.

## Core Workflow: The 35-Minute Build Loop

**CRITICAL: We work in strict 35-minute cycles. That means that the scope of the task we are about to or already doing should not exceed the complexity that could be implemented within 35-minute cycle. If you see that the complexity of the current scope discussed in the current chat is too big, warn me about it and suggest how we can break the task into subtasks.**

### Loop Structure
- **Minutes 0-5:** Frame (scope and context)
- **Minutes 5-20:** Build (one atomic task)
- **Minutes 20-30:** Test (failing test first, then fix. IMPORTANT: right now we are not creating any tests, only provide me with instructions on how to test manually)
- **Minutes 30-35:** Commit & compress (update docs)

## House Rules (ALWAYS FOLLOW)

1. **Return patch diffs, not prose** - Use unified diff format for all code changes
2. **Respect /CONTEXT.md constraints** - Never violate architectural decisions  
3. **If unsure, propose 2 options with trade-offs** (<80 words each)
4. **Keep changes surgical** - Max 3 files unless explicitly expanded
5. **If more than 3 files needed** - Tell me why and what files will be touched

## Git Commit Format

```
type: description (max 50 chars)

Types: feat, fix, refactor, test, docs, style, perf
Example: feat: add invoice CSV export
```

## Workflow for using Git

- Before the loop, ask whether we need to checkout to master, pull and create a new feature branch for the loop. We follow a pattern in naming branches - a number plus one (task number) from the previous branch, a hyphen, and a meaningful name with words separated by a hyphen.
- In the end of the loop, ask whether to add all the files (otherwise ask to specify which files to include), add if answer is yes, and provide with meaningfull commit message (I'll add the commit by myself after).

## Critical Reminders

- **CONTEXT.md is the guardrail** - Read it, respect it, never violate it
- **Keep CONTEXT.md tiny** (<200 lines) - It's compressed knowledge, not documentation
- **After each loop:** Update CONTEXT.md deltas, append to 02-decisions.md if decisions made. Add only one line of decision made after the loop (if any)
- **35 minutes means 35 minutes** - Don't stretch it. Quality through constraint.

## Project TODO List

When user says **"Добавь в todo-list"** or **"Add to todo-list"**:
1. Open `TODO.md` in project root
2. Add new entry under appropriate category (or create new category)
3. Use the format with Status, За/Против (or Pros/Cons), and empty Решение field
4. Status markers: 💭 На обдумывании | ✅ Решено делать | ❌ Отклонено | ⏳ В работе

## Default Behavior

When starting work:
1. Check @docs/01-scope.md for current objectives
2. Read @CONTEXT.md for architecture constraints
3. Work in atomic, testable increments
4. Return patch diffs with clear commit messages

