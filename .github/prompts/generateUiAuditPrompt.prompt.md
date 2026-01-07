---
name: generateUiAuditPrompt
description: Produce a reusable prompt to audit UI/UX and create a prioritized task list.
argument-hint: Provide the conversation transcript, workspace root, and optional target files.
---

You are given an existing conversation and a project workspace. Your goal is to produce a generalized, reusable prompt that an assistant can run to perform a comprehensive usability and UI audit and generate a prioritized task list that improves user experience.

Instructions for the assistant when this prompt is invoked:

1. Review the provided conversation (`{{conversation}}`) to identify the user's primary goal and task pattern.
2. Inspect the provided workspace path (`{{workspace_root}}`) and optional file list (`{{selected_files}}`) for relevant UI code or assets.
3. Produce a clear summary of the core intent (1-2 sentences), stripping out conversation-specific names, paths, and unrelated details.
4. Generate a prioritized task list focused on usability and UI improvements. Group tasks by priority (High / Medium / Low), include short rationale for each item (one sentence), and use Markdown checkboxes.
5. For code-related tasks, include actionable implementation hints (e.g., files to edit, UI patterns to add, API names to create). Use placeholders rather than concrete project names when appropriate (e.g., "create `DialogManager` autoload" becomes "create a standard dialog/autoload service").
6. If asked, save the output into a file `tasklist.md` at the workspace root; otherwise, return the generated Markdown inline.

Placeholders (to be substituted by the caller):
- `{{conversation}}` — full conversation transcript to analyze.
- `{{workspace_root}}` — repository root path to inspect (optional).
- `{{selected_files}}` — comma-separated list of relevant files or folders to prioritize (optional).
- `{{output_file}}` — target file to write the task list (optional, default: `tasklist.md`).

Output requirements:
- Produce a short core-intent line (1 sentence).
- Produce a prioritized Markdown task list with sections: High / Medium / Low.
- For each task include: title, one-line rationale, and one-line implementation hint (file or service where to change). Use checkboxes.
- If `{{output_file}}` is supplied, save the Markdown content to that path in the workspace; otherwise return inline.

Example use (caller should substitute placeholders):

```
{{conversation}}: (paste the chat transcript)
{{workspace_root}}: /workspace/project
{{selected_files}}: scripts/window_manager.gd,scripts/taskbar.gd,scenes/
{{output_file}}: tasklist.md
```

Guidelines for generalization:
- Remove project-specific names and convert specifics into generic placeholders.
- Keep the prompt focused on usability and UI improvements, but allow optional code-level recommendations.
- Keep results actionable: mention which components to change (UI manager, theme, start menu, taskbar, dialog service), and suggest quick wins (clock, keyboard nav, snapping visuals).

End of prompt template.
