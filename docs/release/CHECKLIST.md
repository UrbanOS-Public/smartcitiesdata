# Release Checklist

This project is a Mix umbrella containing many independently-versioned apps under `apps/*`. There is no single project-wide version or changelog — **each app is released and documented on its own**, using its own `mix.exs` version and its own `docs/$microservice/RELEASE.md`.

Deployable microservices (the ones with a `Dockerfile` and built/published by CI) are:

`alchemist`, `andi`, `discovery_api`, `discovery_streams`, `estuary`, `flair`, `forklift`, `raptor`, `reaper`, `valkyrie`

Other apps under `apps/*` are internal libraries. They don't need to be tagged or built, but they can still keep a `docs/$app/RELEASE.md` if it's useful to track their changes.

## Pre-Release Steps

1.  **Pick the app**: Decide which app in `apps/` you're releasing (e.g. `andi`).
2.  **Identify Current Version**: Check the `version:` field in `apps/$microservice/mix.exs`.
3.  **Review Changes**: Find the last release tag for this app (tags are named `$app@$version`, e.g. `andi@23.7.12`):
    ```
    git tag -l "$microservice@*" --sort=-v:refname | head -1
    git log --oneline <last-tag>..HEAD -- apps/$microservice
    ```
    This tells you what actually changed in this app since its last release. Also check `git diff` for any unstaged/uncommitted work in `apps/$microservice`.
4.  **Write Release Notes**: Prepend an entry to `docs/$microservice/RELEASE.md` (create it if it doesn't exist yet — see template below). Keep it short: 2-5 bullet points per release, in plain language a user of the service would understand, not a raw commit log.
5.  **Bump Version**: Update the `version:` field in `apps/$microservice/mix.exs` to match the new version heading in `RELEASE.md`.
6.  **Commit**: Stage the `mix.exs` and `RELEASE.md` changes together and commit, e.g. `Release andi@23.7.13`.

## Release Steps

7.  **Tag the Release**: `git tag $microservice@$version` (e.g. `git tag andi@23.7.13`). The tag version must exactly match the `mix.exs` version — CI (`scripts/gh-action-release.sh`) checks this and fails the build if they don't match.
8.  **Push the Commit and Tag**: `git push origin <branch>` then `git push origin $microservice@$version`.
9.  **Create a GitHub Release** from that tag. This is what triggers `.github/workflows/release.yml`, which builds and publishes the Docker image for the app.

## Post-Release Steps

10. **Verify**: Confirm the GitHub Actions release workflow succeeded and the new image was published (Docker Hub / Quay).
11. **Communicate**: Share the `RELEASE.md` entry with stakeholders as the changelog for this release.

## `RELEASE.md` Template

Each `docs/$microservice/RELEASE.md` is just a running, newest-first log of what changed. New entries are prepended above older ones:

```markdown
# $microservice Release Notes

## 23.7.13
- Fixed an issue where X would fail when Y
- Added support for Z

## 23.7.12
- ...
```

No entry is required for versions where nothing user-facing changed, but every version bump that ships should get a heading, even if the bullet list is short.
