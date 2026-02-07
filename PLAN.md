# tlmgr Development Plan

## Progress Tracking

- `[ ]` Todo
- `[-]` In progress (append start date)
- `[x]` Completed (append completion date)

## High Priority

- [ ] Verify `cmd_changes` handles staged-only changes (ref: commit 77dce04)
- [x] Register tlmgr on Forge and add remote (2026-02-07)

## Medium Priority

- [ ] `tlmgr add <url> [name]` — clone + auto-register in repos.conf
- [ ] `tlmgr remove <name>` — unregister from repos.conf (optionally delete dir)
- [ ] Repo name filtering — `tlmgr changes mdsuite tidyup` (operate on subset)
- [ ] `tlmgr versions` — extract version from pyproject.toml/VERSION across tools

## Low Priority

- [ ] `tlmgr push` — push all repos with unpushed commits
- [ ] `tlmgr update` — pull all repos (friendlier alias for `pull`)
- [ ] `tlmgr stale` — show repos not touched in N days
- [ ] `tlmgr diff` — combined diff across all changed repos
- [ ] `tlmgr doctor` — health check (verify remotes, stale branches, missing upstreams)
- [ ] `tlmgr init` — initialize new tool project from template
- [ ] `--color=auto|always|never` flag
- [ ] `~/.config/tlmgr/config` settings file (color, default_remote, etc.)
- [ ] Zsh completion — `tlmgr completion zsh [--install]`

## Archive

(Completed and skipped items moved here with dates)
