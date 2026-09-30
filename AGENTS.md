# Command-Line Search Tools

Ripgrep is installed on the host at:

`/opt/homebrew/bin/rg`

Before reporting that `rg` is unavailable, try:

`/opt/homebrew/bin/rg --version`

When ripgrep is needed, invoke it using the absolute path:

`/opt/homebrew/bin/rg`

If that exact executable is unavailable or blocked inside the active agent sandbox, report that once and use `find` or `/usr/bin/grep` as the fallback. Do not repeatedly investigate or treat unavailable ripgrep as a task blocker.

# ScoreKeep Work Rules

- Before work, verify the absolute repository root, branch or detached HEAD, and working-tree status against the requested current or Legacy app.
- For Xcode verification, prefer connected Xcode build/test tools when available. Classify CoreSimulator, DerivedData, destination, and plugin failures before blaming source; after a confirmed sandbox denial, switch gates instead of retrying the same route.
- Discover exact active-plan test identifiers, run focused changed-area and adjacent tests first, and require a positive executed-test count for the intended cases. Preserve `xcodebuild`'s own exit status when filtering shell output.
- Use a full test plan when scope or release criteria require it. Triage each failure against current behavior and fixture preconditions before changing production code.
- Resolve Xcode navigator paths to actual filesystem paths before shell or patch edits.
- For migration work, establish authentic store provenance, metadata, and production classification; test the exact startup route with backups and independent verification evidence. Do not infer ordered semantics from unordered SwiftData relationships.
- When a SwiftUI destination gains an `EnvironmentObject`, check every production presentation route that can reach it.
- Preserve unrelated work, stage only intended paths or hunks, inspect the staged diff, and verify the pushed remote SHA independently of local tracking refs. Report final working-tree status.

# Persistent Task Reports

ScoreKeep work may be performed by Codex, Gemini, or Claude. When a task has an established final-report file, update that file with the current task results before finishing. Do not satisfy this requirement only by returning a report in the conversation.

The established report file may reside inside or outside the repository. If the task prompt, current conversation, or existing workflow identifies a report file by path, filename, or established location, treat that file as the required persistent report artifact.

Current established report paths include:

- Codex: `/Volumes/XcodeSSD/Users/karldev/Documents/ScoreKeep-Codex-Report-Latest.txt`
- Gemini: `/Volumes/XcodeSSD/Users/karldev/Documents/ScoreKeep-Gemini-Report-Latest.txt`
- Claude: use the exact persistent report path specified in the task prompt, when one is assigned.

Do not let one agent overwrite another agent’s report file.

## Report Content and Location

- Update the existing report file in place.
- Replace the previous report contents with the current final report unless the task explicitly requires appending.
- Preserve the established filename and location.
- Do not create a second report file, numbered copy, timestamped copy, or alternate `latest` report unless the task explicitly requires one.
- If the report file already exists, overwrite it rather than creating a replacement.
- Include the implementation summary, verification performed, exact results, files changed, commit and push results when applicable, and final Git status appropriate to the task.
- Report the exact path of the updated report file in the final response.
- For report files stored outside the repository, update the file but never attempt to commit or push it.
- For report files stored inside the repository, do not commit or push the report unless the task explicitly authorizes Git changes.

## Reports Outside the Repository Workspace

Persistent ScoreKeep report files normally reside outside the repository workspace root. Assume that normal shell-writing methods such as redirection, `cp`, `tee`, and similar commands will be blocked by sandbox permissions.

For an external report file:

- Use the `apply_patch` file-editing tool to create or replace the report at the exact established path.
- Use `apply_patch` as the primary method rather than first attempting shell redirection.
- Do not repeatedly retry blocked shell-writing commands.
- Do not request elevated permissions merely to write the report.
- Do not treat an expected shell permission failure as a task failure when `apply_patch` can update the file.

After updating the report, verify the exact assigned path with:

`test -r "<report-path>"`

`wc -l "<report-path>"`

Include the verification result in the final response.

Always update and verify the persistent model-specific report file before finishing. Do not repeat the complete report in the conversation response when the persistent report file was successfully written and verified. If the persistent report cannot be written or verified, include the complete report in the conversation response as a backup.

## Failure Handling

If the established report file cannot be located or updated using the permitted file-editing tools, stop and report the problem instead of silently creating a new report or returning only a conversation report.

When a task explicitly requires updating an established report file, completion is not achieved until that exact file has been successfully updated and verified. Returning an equivalent report only in the conversation is not an acceptable substitute.
