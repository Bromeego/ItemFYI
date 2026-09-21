# Development

Player-facing documentation is in [README.md](README.md). This file is for
maintainers and contributors.

## Reporting issues

Please log bugs and suggestions in this GitHub repository, using the issue
templates. Prefer GitHub issues over CurseForge comments so they stay in one
place.

## Testing

From the repository root:

```bash
./tools/validate.sh
```

GitHub Actions runs the same check on every push and pull request.

## Releasing

Keep `## Version:` in `ItemFYI.toc` as a real version number (for example
`0.2.19`). Do not replace it with `@project-version@`; the addon is often
loaded directly from this Git checkout.

With CurseForge set to package all commits, every push to `main` is uploaded.
A Git tag is optional and is only something you create yourself.

1. Finish and test changes.
2. Update `CHANGELOG.md` when the change should appear in release notes.
3. Update `## Version:` in `ItemFYI.toc` when the public version changes.
4. Commit and push to `main`. CurseForge packages that commit as an **alpha**.

To publish a build most CurseForge users will receive, also create a tag:

```bash
git tag v0.2.20
git push origin v0.2.20
```

- Untagged `main` commits → **alpha**
- Tags containing `beta`, such as `v0.2.20-beta1` → **beta**
- Tags such as `v0.2.20` → **release**

See tags on GitHub under **Releases → Tags**, or with `git tag`. Nothing is
tagged until you run `git tag`.
