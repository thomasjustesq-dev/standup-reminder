# Claim files

One markdown file per claim. Land the claim on the default branch before
product work. See [`../WORKBOARD.md`](../WORKBOARD.md).

## Naming

`YYYY-MM-DD-{task-id-slug}-{short-slug}.md`

## Required metadata

```md
# Claim — short title

- Task Type: Maintenance
- Task ID: process/example
- Branch: agent/grok/task-example
- Base Branch: main
- Tool: Grok
- Assigned By: Thomas
- Date Claimed: YYYY-MM-DD
- Last Updated: YYYY-MM-DD
- Status: Active
- Blocked By: none
- Pull Request: none
```

Required sections: `## Scope`, `## Write surface`, `## Hot spots`, `## Handoff`.

Closed claims → `archive/` via `scripts/archive-merged-claims.sh --apply`.
