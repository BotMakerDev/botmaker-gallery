# botmaker-gallery

The index of published BotMaker bots. Each entry points at somebody's own GitHub repository. The release
you install comes from *there*, never from here.

## Two tiers

| Tier | How a bot gets it | What it means |
|---|---|---|
| **Community** | A pull request that passes the checks is **merged automatically**. | The entry is well formed, its author owns the repository, and its release downloads. Nobody read the code. |
| **Vetted** | A maintainer writes `vetted/<owner>-<repo>.json`. | A maintainer looked at **one release**, `vettedVersion`, and chose to list it. A newer release is still installable, but it is not the vetted one. |

Neither tier is a security review. A bot is a Java program you build and run.

## Layout

```
bots/<owner>-<repo>.json      the source of truth, one entry per bot, owned by its author
vetted/<owner>-<repo>.json    maintainer-only: which release of that bot is vetted
catalog.json                  GENERATED: every listing and its tier. What Studio reads
index.json                    GENERATED: Vetted listings only, in the old array shape
tools/botmaker-cli.version    the botmaker-cli release whose rules the workflows run
```

**Every rule lives in `botmaker-cli`, not here**, in `com.botmaker.cli.gallery`. The workflows resolve that
library at the pinned version and call it. `botmaker bot publish` runs the same checks on your machine
before it opens a pull request, so a refusal here is one you could already have seen.

**`index.json` never moves, and it holds only Vetted bots.** Every Studio released before 2026-09-16 reads it
from `raw.githubusercontent.com/BotMakerDev/botmaker-gallery/main/index.json` — spelled `LiQiyeDev` in the
Studios built before the repository moved into the organization on 2026-09-18 — and cannot show a tier. So it
gets only the bots a maintainer looked at. Newer Studios read `catalog.json`. One cost: an older Studio
installs a Vetted bot's *newest* release, because it never learned what `vettedVersion` is.

## What happens to a pull request

1. **`validate.yml` runs the gate** (`GalleryGate`). It refuses:
   - an edit to `catalog.json` or `index.json`;
   - any change to `vetted/` by anyone but a maintainer;
   - a filename that is not the entry's `owner-repo`;
   - a `schemaVersion` newer than the gate knows;
   - a change to, or removal of, **somebody else's** listing. Ownership is read from the gallery's current
     copy, not from the pull request's;
   - a repository with no release, or whose release archive does not download.

   Two things are warnings: a new entry for a repository the author is not (an organisation's bot, say), and
   a `requires` naming a plugin the registry does not list.
2. **`automerge.yml` decides** (`ListingPolicy`), after every validation and once an hour:
   - **merged**: listed as Community, then `index.yml` runs;
   - **`waiting`**: the author has had **3 new bots** listed in the last 24 hours. A comment says when it
     merges, and the hourly run merges it then. Updating your own listing never counts;
   - **`needs-maintainer`**: the pull request touches anything outside `bots/<file>.json`, names a repository
     the author cannot be shown to own, or adds more than 3 bots at once.
3. **`index.yml` regenerates** `catalog.json` and `index.json` (`CatalogBuilder`) and commits them.

The auto-merge job never checks out a pull request's code. It reads everything through the API, as data.
The rule that sends every pull request touching a path outside `bots/` to a maintainer is what makes a green
check trustworthy: a pull request that edits a workflow could otherwise give itself one.

**Repository settings this needs:** *Settings ▸ Actions ▸ General ▸ Workflow permissions* must allow read
and write, and must allow GitHub Actions to create and approve pull requests. If `main` is protected, the
protection must let the Actions bot merge.

## An entry

```json
{
  "schemaVersion": 2,
  "name": "gamebot",
  "owner": "BotMakerDev",
  "repo": "botmaker-gamebot",
  "description": "A game bot to start from.",
  "tags": ["game", "template"],
  "launchTargets": ["heroic"],
  "requires": [{"id": "com.botmaker.sdk", "version": "1.1.6"}]
}
```

- **No release version.** The release to install is fetched live from the author's repository, so a new
  release never needs an edit here.
- **`launchTargets`** is what the author says their bot was tested on. An entry without it reads as "the
  author never said", never "works on nothing".
- **`requires`** names the plugins the bot's pom declares, by plugin-registry id.
- **`schemaVersion`** is the migration seam. An entry without it is version 1, the shape of every entry
  written before 2026-09-16. It is read as it stands and never rewritten. Version 2 only added fields.

## Vetting

A maintainer adds `vetted/<owner>-<repo>.json`, from the dashboard or by hand:

```json
{
  "schemaVersion": 1,
  "owner": "BotMakerDev",
  "repo": "botmaker-gamebot",
  "vettedVersion": "v0.1.0",
  "vettedAt": "2026-09-16",
  "vettedBy": "LiQiyeDev"
}
```

The flag is a separate file rather than a field in the entry because the entry is the author's, and an
author re-publishes whenever they like. A field would be something every submission can set. A directory
only a maintainer may change is a rule the gate states in one line. Revoking is deleting the file.

## `"template"` is a reserved tag

An entry whose `tags` contain `template` is a **starting template**, not a bot to install. Studio's
**New Project** lists those, Vetted ones first. **Browse Bots** lists everything else.

A template is an ordinary published bot: same repository, same release, same kind of entry. That is the
whole point. A new starting point needs no Studio release, and the people who write bots are the people who
write the templates. Studio composes exactly one starting point of its own (a blank project, so New Project
works with no network). Every richer one lives here.

The one extra thing a template needs is a `botmaker-template.properties` at its repository root:

```properties
package=com.botmaker.gamebot
```

That prefix is replaced with the user's own when they start from it (`com.myfarmer`, say), and the
directories move with it. **Nothing else is renamed**: the entry class and everything else keep the names
their author gave them, so the copy is the project that demonstrably built for them.

## Submitting

Publish from Studio (**Project ▸ Publish…**) or run `botmaker bot publish --repo <owner>/<name>`. Both write
your entry file and open the pull request. By hand, add `bots/<owner>-<repo>.json` with the shape above, from
the account that owns the repository.
