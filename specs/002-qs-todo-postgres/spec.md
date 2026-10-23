# Feature Specification: Offline Todo List Widget With Remote Database Sync

**Feature Branch**: `002-qs-todo-postgres`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "Offline Todo list widget on qshell with storing on postgress url database. search and check qshell ready to use widgets"

## Prior Art Survey *(requested: "search and check qshell ready to use widgets")*

Ready-made Quickshell todo widgets were checked on 2026-10-23 before writing this spec:

| Candidate | What it offers | Storage | Fit for this feature |
|-----------|----------------|---------|----------------------|
| end-4/dots-hyprland, `ii/services/Todo.qml` + `modules/ii/sidebarRight/todo/` (GPL-3.0) | Add, mark done/undone, delete; a list of `{content, done}` items in a sidebar tab | One local JSON file | Good reference for the item model and list UI; no remote storage, no ids or timestamps, so it cannot merge changes from two machines. Tied to the `ii` shell's own common modules and theme. |
| ziuus/caelestia-todo-widget (`TodoWidget.qml`, licence not stated) | Tasks with All/Active/Completed filters, daily habits, swipe-to-delete, date/time picker, Google Calendar view | Local, plus a Python script for calendar sync | Hyprland-oriented desktop-layer widget with its own Catppuccin styling and Python dependency; no database sync; licence unclear. |
| Caelestia shell, Noctalia, DankMaterialShell | Full shells | n/a | No built-in todo widget found. |

**Conclusion**: no ready-made widget provides offline use with sync to a remote database, and none follows this shell's theme or popout structure. This feature builds a native todo surface in the existing shell. It reuses the shell's existing local state-file pattern (as calendar events do) and borrows the item model and interaction ideas from end-4's widget. It does not vendor either project's code.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manage todos locally from the shell (Priority: P1)

The user opens a Todo panel from the bar or a keybind and adds a task by typing and pressing Enter. They tick tasks done, untick them, edit the text, and delete them. The list is kept on the machine, so it survives closing the panel, restarting the shell and rebooting. All of this works with no network and no database configured.

**Why this priority**: This is the widget itself. Without it nothing else has value, and on its own it is already a usable offline todo list.

**Independent Test**: With networking disabled and no database configured, open the panel, add three tasks, complete one, edit one, and delete one. Restart the shell and confirm the remaining two tasks appear with the correct text and done state.

**Acceptance Scenarios**:

1. **Given** the panel is open with an empty list, **When** the user types "Buy milk" and presses Enter, **Then** "Buy milk" appears as an open task and the input clears, ready for the next task.
2. **Given** an open task, **When** the user toggles it, **Then** it is shown as done, and toggling again makes it open.
3. **Given** a task, **When** the user edits its text and confirms, **Then** the new text is shown and kept after a shell restart.
4. **Given** a task, **When** the user deletes it, **Then** it disappears and does not return after a restart.
5. **Given** no network, **When** the user does any of the above, **Then** each action takes effect at once with no error shown.

---

### User Story 2 - Keep todos in a remote database and sync when online (Priority: P2)

The user supplies a connection URL for their own database server. When the server is reachable, local changes are sent to it and changes stored there are pulled in. While it is unreachable, the user keeps working locally. Pending changes are sent automatically once it is reachable again. Because every machine syncs with the same database, the user sees the same list on each of their machines.

**Why this priority**: Remote storage is the specific ask. It depends on Story 1's local list, which keeps working without it.

**Independent Test**: Configure the URL on two machines. Add a task on machine A while offline, reconnect it, and confirm the task appears on machine B within the sync interval. Stop the database, edit tasks on A, restart the database, and confirm the edits reach the database and then B.

**Acceptance Scenarios**:

1. **Given** a valid URL and a reachable database, **When** the user adds a task, **Then** the task is stored in the database within the sync interval.
2. **Given** the database is unreachable, **When** the user adds, edits, completes or deletes tasks, **Then** the changes are kept locally and marked as pending.
3. **Given** pending changes and the database becoming reachable, **When** the next sync runs, **Then** all pending changes are stored remotely, none are lost or duplicated, and the pending mark clears.
4. **Given** a task changed on another machine, **When** this machine syncs, **Then** the change appears in this machine's list without the user reopening the panel.
5. **Given** the same task was edited on two machines while both were offline, **When** both sync, **Then** both machines end with the same version, the most recently changed one.
6. **Given** a task deleted on one machine, **When** the other machine syncs, **Then** the task is removed there too and is not brought back by the other machine's local copy.

---

### User Story 3 - See sync status at a glance (Priority: P3)

The panel shows whether the list is synced, waiting to sync (with the number of pending changes), offline, or failing because of a configuration or authentication problem. The user can also ask for a sync immediately.

**Why this priority**: This is about trust and troubleshooting. Syncing works without it, but the user could not tell whether their data has reached the server.

**Independent Test**: Toggle the database between reachable, unreachable and a bad password, and confirm the indicator shows each state correctly. Use "sync now" and confirm the indicator changes to synced.

**Acceptance Scenarios**:

1. **Given** no URL is configured, **When** the panel is open, **Then** it shows "local only" and no error.
2. **Given** the database rejects the credentials, **When** a sync is attempted, **Then** the panel shows an authentication error. The connection URL and password are not displayed or logged.
3. **Given** pending changes and a reachable database, **When** the user chooses "sync now", **Then** sync runs immediately and the indicator changes to synced.

---

### Edge Cases

- Empty or whitespace-only task text is not added.
- Very long task text (over 500 characters) is accepted and wraps in the list; it is not silently cut.
- The local list file is corrupt or unreadable: it is set aside, the user starts from an empty list or the remote copy, and the corrupt file is not overwritten.
- The URL is malformed, or names a host that does not resolve: this is treated as a configuration error shown in the status. It never blocks local use.
- The database lacks the todo storage on first use: it is created automatically, or a clear error is shown if the account is not allowed to create it.
- The database is reachable but slow, or drops mid-sync: the shell never freezes, and a partial sync either completes later or is retried without duplicating tasks.
- The machine's clock is wrong: a skewed clock must not cause a deletion to be undone or a newer edit to be lost permanently (see FR-012).
- Two machines create tasks with identical text while offline: both are kept as separate tasks.
- The list grows to 1,000 tasks: the panel still opens and scrolls smoothly.
- The URL is changed to a different database: the local list is kept, and the next sync merges it into the new database.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to open and close a Todo panel in the desktop shell from a bar control and from a keyboard shortcut. It must also be openable by the shell's existing command interface for panels.
- **FR-002**: Users MUST be able to add a task by typing text and confirming. Empty or whitespace-only text MUST be rejected.
- **FR-003**: Users MUST be able to mark a task done or not done, edit its text, and delete it.
- **FR-004**: The panel MUST show open tasks before done tasks, and newest first within each group. Done tasks MUST be visibly distinct.
- **FR-005**: Users MUST be able to clear all done tasks in one action.
- **FR-006**: Every change MUST be saved on the local machine immediately and survive panel close, shell restart and reboot, whether or not a database is configured or reachable.
- **FR-007**: All task actions MUST work fully with no network connection and with no database configured.
- **FR-008**: The user MUST be able to configure a single database connection URL. The URL (including any password) MUST be read from a private location outside the repository. It MUST NOT be stored in the configuration repository, shown in the panel, or written to logs.
- **FR-009**: When a URL is configured, the system MUST sync automatically in the background. It MUST sync after each local change (batched within a few seconds), periodically (at least every 5 minutes) to pick up remote changes, and when the database becomes reachable again after being unreachable.
- **FR-010**: Changes made while the database is unreachable MUST be queued locally. The queue MUST survive restarts and be sent in full once the database is reachable.
- **FR-011**: Each task MUST have a stable identity that does not depend on its text or position. That way, tasks created on different machines never collide, and a retried sync never creates duplicates.
- **FR-012**: When the same task has been changed on more than one machine, the version with the latest change MUST win, and every machine MUST converge on the same result. Deletions MUST be recorded rather than just removing the task, so a stale copy on another machine cannot bring a deleted task back.
- **FR-013**: The system MUST prepare the database storage it needs on first sync if it is missing. If the account cannot do this, it MUST report a clear error.
- **FR-014**: The panel MUST show the sync state: local only, synced, pending (with count), offline, or error (configuration/authentication/other). It MUST also offer a "sync now" action.
- **FR-015**: Sync and database access MUST never block or freeze the shell's interface.
- **FR-016**: A corrupt local list MUST be set aside (not deleted or overwritten) and recovery MUST continue from the remote copy if one is available, otherwise from an empty list.
- **FR-017**: The panel MUST follow the shell's live theme and its light/dark switch, like the existing panels.
- **FR-018**: The local task data MUST be documented as mutable runtime state that the repository does not manage. How to supply the database URL MUST also be documented.

### Key Entities

- **Task**: One todo item. It has a stable unique id, the text, a done flag, the time it was created, the time it was last changed, and a deleted marker (a tombstone, kept so the deletion syncs).
- **Local Task Store**: The machine's copy of all tasks, including tombstones, plus the time of the last successful sync. Saved on the machine and readable with no network.
- **Pending Change Queue**: Local changes not yet confirmed as stored remotely. Kept across restarts and emptied as sync succeeds. This can be derived from the local store (tasks changed since the last confirmed sync) rather than kept as a separate list.
- **Remote Task Store**: The tasks held in the user's database. It is shared by every machine that uses the same URL.
- **Sync Status**: The current state shown to the user: local only, synced, pending, offline, or error with a category. It also holds the time of the last successful sync.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can open the panel, add a task and close the panel in under 5 seconds, with the task shown less than 100 ms after pressing Enter.
- **SC-002**: With no network, 100% of add, edit, complete and delete actions succeed and persist across a reboot.
- **SC-003**: After reconnecting, a change made offline on one machine appears on a second machine within 5 minutes (or immediately after "sync now" on both).
- **SC-004**: In a test of 50 mixed changes made on two machines while offline (including the same task edited on both and a task deleted on one), both machines and the database end with identical lists. No task is lost, no task is duplicated, and no deleted task returns.
- **SC-005**: When the database is unreachable or slow, the shell stays fully responsive: no interaction ever waits on the network.
- **SC-006**: The connection URL and password do not appear in the repository, the panel, or any shell log output.
- **SC-007**: With 1,000 tasks, the panel opens and is ready for input in under 300 ms.

## Assumptions

- "Offline" means local-first: the local list is always the working copy, and the database is a synced, shared copy. It is not online-only use with an offline fallback.
- The database server already exists and is run by the user. Setting up or hosting a database server is out of scope. The user provides a standard connection URL with credentials.
- A single user owns the list. Sharing between users, per-user permissions and multiple lists are out of scope for this version. There is one flat list.
- Due dates, reminders, priorities, tags, subtasks and recurring tasks are out of scope. Date-based reminders already exist as calendar events in the shell.
- The most recent change wins when two machines change the same task (FR-012). Merging the edits within a single task's text is not attempted.
- Machine clocks are kept roughly correct by network time sync. Clock skew is still handled so that a skewed clock cannot undo a deletion.
- The URL is kept in a private, user-only file or secret on each machine, in line with the repository rule that secrets are never committed.
- Tombstones may be cleaned up after a retention period (default 30 days) once every machine has had time to sync.
- The panel lives in the existing desktop shell as a popout, like the other accessories. It is not a separate application.
