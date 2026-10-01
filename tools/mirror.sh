#!/usr/bin/env bash
#
# mirror.sh — copy every listed bot's release archives into this repository's `mirror` release, so a bot stays
# installable after its author deletes or renames the repository. Run by mirror.yml; DRY_RUN=1 prints what it
# would upload and changes nothing.
#
# THE AUTHOR KEEPS THE REPOSITORY (the maintainer's call, 2026-10-01). Studio installs from the author's tag and
# falls back to this copy only when that answers 404. Nothing here is a second source of truth: an asset is the
# author's own GitHub archive of the tag, byte for byte, taken the first time this job saw the tag.
#
# THE ASSET NAME IS THE ADDRESS: <owner>__<repo>__<tag>.zip on the release tagged `mirror`, so Studio builds
#   https://github.com/BotMakerDev/botmaker-gallery/releases/download/mirror/<owner>__<repo>__<tag>.zip
# without reading catalog.json, which therefore carries nothing new (index.json's shape is frozen anyway).
# `__` because an owner is letters, digits and single hyphens, so it can never contain one.
#
# APPEND ONLY. An asset that exists is never replaced: a tag moved after it was mirrored is the author's
# business, and the copy is what was listed. Which tags: each listing's newest release, and a Vetted one's
# vettedVersion — so over the days the job runs, every release anybody could have installed.
#
# Every value from catalog.json or the API is data: read through jq, checked against a character class before
# it reaches a path or a URL, and only ever used as a quoted variable.
set -euo pipefail

repo="${GITHUB_REPOSITORY:-BotMakerDev/botmaker-gallery}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release=mirror
dry="${DRY_RUN:-}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

name_re='^[A-Za-z0-9][A-Za-z0-9._-]*$'

if ! gh release view "$release" --repo "$repo" >/dev/null 2>&1; then
    if [ -n "$dry" ]; then
        echo "would create release $release on $repo"
    else
        # --latest=false: the gallery's "latest release" must not become a pile of other people's zips.
        gh release create "$release" --repo "$repo" --latest=false --title "Mirror of listed bots" \
            --notes "Release archives of every listed bot, copied by mirror.yml. Studio installs from here only when the author's repository is gone. Assets are <owner>__<repo>__<tag>.zip and are never replaced."
    fi
fi

existing="$work/existing.txt"
gh release view "$release" --repo "$repo" --json assets --jq '.assets[].name' >"$existing" 2>/dev/null || : >"$existing"

jq -r '.bots[] | [.owner, .repo, (.vettedVersion // "")] | @tsv' "$root/catalog.json" |
while IFS=$'\t' read -r owner name vetted; do
    if ! [[ "$owner" =~ $name_re && "$name" =~ $name_re ]]; then
        echo "skipped a listing with an unusual name: $owner/$name" >&2
        continue
    fi
    latest="$(gh api "repos/$owner/$name/releases/latest" --jq '.tag_name' 2>/dev/null || true)"
    for tag in $(printf '%s\n%s\n' "$latest" "$vetted" | sort -u); do
        if ! [[ "$tag" =~ $name_re ]]; then
            [ -n "$tag" ] && echo "skipped $owner/$name tag with an unusual name: $tag" >&2
            continue
        fi
        asset="${owner}__${name}__${tag}.zip"
        if grep -qxF "$asset" "$existing"; then
            continue
        fi
        if [ -n "$dry" ]; then
            echo "would mirror $owner/$name@$tag as $asset"
            continue
        fi
        # The API's zipball, as Studio downloads it (GitHubConfig.archiveUrl), so the copy unpacks the same way.
        if ! curl -fsSL -H "Authorization: Bearer ${GH_TOKEN:-}" -o "$work/$asset" \
                "https://api.github.com/repos/$owner/$name/zipball/refs/tags/$tag"; then
            echo "could not download $owner/$name@$tag; the next run tries again" >&2
            continue
        fi
        gh release upload "$release" "$work/$asset" --repo "$repo"
        rm -f "$work/$asset"
        echo "mirrored $owner/$name@$tag"
    done
done
