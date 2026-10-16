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
It also runs on version tags and checks release metadata. Python 3 is required
for the release checks and their tests.

## Releasing

Keep `## Version:` in `ItemFYI.toc` as a real version number (for example
`0.2.19`). Do not replace it with `@project-version@`; the addon is often
loaded directly from this Git checkout.

With CurseForge set to package all commits, every push to `main` is uploaded.
A Git tag is optional and is only something you create yourself.

1. Finish and test changes.
2. Update `CHANGELOG.md` when the change should appear in release notes.
3. Update `## Version:` in `ItemFYI.toc` when the public version changes.
4. Validate, commit, and merge the release changes into `main`. CurseForge
   packages that commit as an **alpha**.

To publish a build most CurseForge users will receive, also create a tag:

Use the TOC as the source of truth. After merging, update your local `main`,
run the validation suite, then create its matching tag:

```bash
git switch main
git pull --ff-only origin main
./tools/validate.sh
python3 tools/release.py --create-tag
```

The helper requires a clean checkout on `main`, fetches the remote, checks that
HEAD matches `origin/main`, and requires the latest numbered changelog heading
to match `## Version:` in `ItemFYI.toc`. It creates an annotated tag derived from
that version and prints the exact push command. It never moves an existing tag
or pushes automatically.

For example, TOC version `0.2.40` produces tag `v0.2.40`. To check a proposed tag
without creating it, use `python3 tools/release.py --tag v0.2.40`.

Tag CI independently verifies that the pushed tag matches the TOC and changelog.
This reports mistakes but cannot prevent an external CurseForge integration
from reacting to a manually pushed tag; use the helper to catch mistakes before
pushing. Bump the TOC and add its numbered changelog section before each release.

- Untagged `main` commits → **alpha**
- Tags containing `beta`, such as `v0.2.20-beta1` → **beta**
- Tags such as `v0.2.20` → **release**

See tags on GitHub under **Releases → Tags**, or with `git tag`. Nothing is
tagged until you run `git tag`.
