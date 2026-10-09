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

This project tags each release (`git tag $microservice@$version`) but does **not** drive builds off that
tag via GitHub Releases/CI — see the "Tagging policy" section in the top-level `README.md` for why.
The tag is a lightweight provenance bookmark only: it lets you point at exactly what source produced a
given image later (`git show $microservice@$version`), and it's what `CHECKLIST.md` step 3 diffs from
on the *next* release. It does not gate or trigger anything by itself.

7.  **Tag and Push**: `git tag $microservice@$version` (e.g. `git tag andi@23.7.13`), matching the
    `mix.exs` version exactly, then `git push origin <branch>` and `git push origin $microservice@$version`.
8.  **Build the image**: `scripts/build-local.sh --rebuild-base $microservice` (optionally `--push`
    once you're ready to publish). **Always pass `--rebuild-base`.** The script reuses the cached
    `smartcitiesdata:build` base image by default instead of rebuilding it, and that base image is
    where the umbrella source actually gets compiled from — a stale one silently bakes an old app
    version/code into the release even though the resulting container gets tagged with your new
    version. This is *especially* likely to bite you if it's been several days or more since the base
    image (or any project image) was last built — check with `podman images smartcitiesdata:build` and
    compare its `CREATED` age before assuming a cached build is safe to reuse.

## Post-Release Steps

9.  **Verify**: Confirm the image actually built and is tagged as expected (`podman images
    $microservice`), and that it runs/behaves correctly before pushing/deploying it.
10. **Communicate**: Share the `RELEASE.md` entry with stakeholders as the changelog for this release.

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
