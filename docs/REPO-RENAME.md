# Repo Rename Checklist

When renaming `ideo/Rubber-Duck` to a new name (e.g. `ideo/duck-duck-duck`).

## Blocker

`ideo/duck-duck-duck` already exists (marketing/preorder site). Either rename that repo first or pick a different name for the main app repo.

## Code References to Update

### Functional (will break installs)

| File | Line | Reference |
|------|------|-----------|
| `widget/Sources/RubberDuckWidget/StatusBarManager.swift` | ~532 | `installCommand` string |
| `widget/Sources/RubberDuckWidget/StatusBarManager.swift` | ~590 | `run(claude, args: [..., "ideo/Rubber-Duck"])` |
| `widget/Sources/RubberDuckWidget/StatusBarManager.swift` | ~705, ~721 | Gemini extension install refs |
| `.claude-plugin/marketplace.json` | 12, 19 | Marketplace source + homepage |
| `plugin/hooks/on-session-start.sh` | ~64 | Download URL in session start message |

### Docs (won't break — GitHub redirects, but should update)

| File | References |
|------|-----------|
| `README.md` | Release link, clone URL, marketplace command |
| `plugin/README.md` | Marketplace add command |
| `plugin/.claude-plugin/plugin.json` | Description URL |
| `plugin/PLAN.md` | ~12 references throughout |
| `plugin/RISKS.md` | Marketplace add command |
| `docs/ONBOARDING.md` | Download URLs |
| `widget/Sources/RubberDuckWidget/HelpView.swift` | GitHub link in About |
| `widget/Playground/Sources/LLMPlayground/HelpPlayground.swift` | Docs URL |

## External References

| Item | Action |
|------|--------|
| GitHub release page | Auto-redirects, but update body text |
| Collaborator git remotes | Each runs `git remote set-url origin <new-url>` |
| Collaborator local folders | Optional rename |
| GitHub Desktop | Auto-follows redirect, may need refresh |
| Existing marketplace installs | Must reinstall: `claude plugin marketplace remove` → `marketplace add <new>` |
| CLAUDE.md | Update repo reference |
| `.claude/projects/` memory files | Update any repo references |
| Slack/email links shared | GitHub redirects handle these |

## Steps

1. Rename marketing site repo (e.g. `duck-duck-duck` → `duck-duck-duck-site`)
2. Rename main repo on GitHub (`Rubber-Duck` → `duck-duck-duck`)
3. Update all code references (find/replace `ideo/Rubber-Duck` → `ideo/duck-duck-duck`)
4. Push changes
5. Cut new release with updated DMG
6. Notify collaborators to update remotes
7. Existing plugin users reinstall

## Notes

- GitHub auto-redirects old URLs after rename — nothing breaks immediately
- The `claude plugin marketplace` system has NOT been tested with redirects — assume it breaks
- Only ~1 external install exists as of 2026-03-23, so impact is minimal
- Internal Swift module stays `RubberDuckWidget` (no user-facing impact)
- Bundle ID stays `com.duckduckduck.widget` (no change needed)
