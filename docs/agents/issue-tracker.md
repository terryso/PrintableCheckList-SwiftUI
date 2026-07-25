# Issue tracker: GitHub

Issues and specifications for this repository live in GitHub Issues. Use the
`gh` CLI for tracker operations.

## Conventions

- Create issues with `gh issue create`.
- Read issues and comments with `gh issue view <number> --comments`.
- List issues with `gh issue list` and the appropriate state or labels.
- Apply and remove labels with `gh issue edit`.
- Do not use pull requests as a triage request surface.

Infer the repository from the `origin` remote when running inside this clone.

## Publishing

When an engineering skill says to publish to the issue tracker, create a GitHub
issue. Use GitHub native issue dependencies for blocking edges when available;
otherwise state each blocker in the issue body.
