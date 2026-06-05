# Cursor Automation — SpecKit maintain pulse (scheduled)

You are running a **scheduled pulse** for this repository. Follow `.cursor/skills/speckit-drive/SKILL.md` §Scheduled pulse.

1. `cd` to the repository root.
2. Run `.specify/scripts/bash/check-pulse-schedule.sh --json`. If `should_run` is false, exit quietly with the reason (no user question).
3. Set `SPECIFY_FEATURE_DIRECTORY` from the JSON `feature_directory` field (or resolve `auto_latest_delivered` per speckit-drive).
4. Run **one** maintain pulse: read `pulse_focus` for this round index, ask **exactly one** question (experience / new_demand / priority / regression), append to `FEATURE_DIR/pulse-log.md`, wait for user reply in this thread.
5. After user replies (or explicit waive), run `.specify/scripts/bash/record-pulse-run.sh`.
6. **Do not**: auto implement, auto release, bypass gate-verify, or ask multiple questions in one run.
