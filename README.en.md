# github-desktop-remote-hosts

[Русский](README.md) | **English**

A patch for an installed GitHub Desktop (Windows) that enables menu items for repositories hosted outside GitHub — GitLab (including self-hosted), Bitbucket, Gitea/Codeberg/Forgejo:

| Menu item | GitLab | Bitbucket | Gitea |
|---|---|---|---|
| Repository → View on … | `<repo>` | `<repo>` | `<repo>` |
| Repository → Create issue on … | `/-/issues/new` | `/issues/new` | `/issues/new` |
| Branch → View branch on … | `/-/tree/<branch>` | `/src/<branch>` | `/src/branch/<branch>` |
| Branch → Compare on … | `/-/compare/<default>...<branch>` | `/branches/compare/<branch>%0D<default>` | `/compare/<default>...<branch>` |
| History → commit → View on … | `/-/commit/<sha>` | `/commits/<sha>` | `/commit/<sha>` |
| History → file in a commit → View on … | `/-/commit/<sha>#<SHA-1 of the file path>` | `/commits/<sha>` | `/commit/<sha>` |
| Repository list → View on … (selected repository only) | `<repo>` | `<repo>` | `<repo>` |

The page address is built from the remote URL (`https://…`, `git@host:…`, `ssh://…:port/…`), and the name shown in the menu comes from the host (GitLab, Bitbucket, …). For any other host, GitHub Desktop asks the server's `/api/v1/version` once in the background: if it answers as Gitea/Forgejo (including "Only signed in user is allowed…" on a private server), it is treated as Gitea, otherwise as GitLab. The answer is remembered; until the server replies the host is treated as GitLab (the menu label updates the next time the repository state refreshes). The "No local changes" screen gets an "Open the repository page on … in your browser" card. Nothing changes for GitHub repositories.

The Branch → … items are enabled only for a published branch; if the default branch is unknown, Compare uses `main`.

"Create pull request" is left alone — it works through the GitHub API.

## Installation

Unpack the archive, close GitHub Desktop and run `patch.bat`. Nothing needs to be installed — it is a PowerShell script, and PowerShell ships with Windows 10/11.

The newest `%LOCALAPPDATA%\GitHubDesktop\app-x.y.z` folder is patched; you can pass a path explicitly:

```
patch.bat C:\Users\<user>\AppData\Local\GitHubDesktop\app-3.6.11
```

**Re-apply the patch after every GitHub Desktop update** — an update installs a new `app-x.y.z` folder. Running it again (and installing a newer version of the patch over an older one) is safe: the original from `.orig` is always the one being patched.

## Uninstall

```
patch.bat -Restore
```

The originals are kept next to the patched files as `main.js.orig` / `renderer.js.orig`.

## How it works

Everything is in one file, `patch.ps1` (`patch.bat` only launches it):

1. `$helpers` — plain JavaScript: parsing the remote URL and building GitLab/Bitbucket/Gitea links. It is prepended to `resources/app/renderer.js` as `window.remoteHosts`.
2. `$mainChanges` / `$rendererChanges` — "before → after" pairs for the minified `main.js` (menu item labels) and `renderer.js` (enabling the items, building links).

Minified names (`Mo`, `Vo`, `Lo`, …) differ between GitHub Desktop versions, so in "before" they are written as `%Repository%`, `%CloningRepository%` and so on — the script finds what they are called in the installed version and substitutes them into "after".

Every "before" must be found exactly once — otherwise the script changes nothing and reports what was not found. That means the code itself changed in this GitHub Desktop version and the pair needs to be updated.

Tested on GitHub Desktop 3.6.6, 3.6.7, 3.6.10 and 3.6.11.
