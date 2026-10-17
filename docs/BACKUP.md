# GitHub source backup

The repository includes original project sources, tests, documentation,
redistributable content and the vendored native WebRTC dependency. Original
GrimTable work is MIT licensed; third-party material keeps its existing licenses.
See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

Caches, player data, local agent configuration, credentials, `node_modules/`,
exported builds and temporary files are excluded by `.gitignore`. The separately
built Windows ZIP can be attached to a GitHub release; it should not be committed
as a large source blob. Native runtime dependencies under `addons/` are included
so a clone can open and export the project.

## Publish

Create an empty repository named `GrimTable` on your GitHub account. Do not
initialize it with a README, license or gitignore, since these already exist here.
With authenticated GitHub CLI, the equivalent is:

```sh
gh repo create GrimTable --public --source . --remote origin --push
git push origin --tags
```

Or use the exact clone URL supplied by your newly created repository:

```sh
git remote add origin https://github.com/YOUR-ACCOUNT/GrimTable.git
git push -u origin main
git push origin --tags
```

If Git reports dubious ownership on a filesystem without ownership information,
use `git -c safe.directory=D:/40k-sim ...` for this workspace rather than disabling
ownership checks globally. Use your actual trusted project directory on other
machines. No token should be committed or embedded in a remote URL.

## Portable snapshot

The initial backup can also be restored from
`builds/GrimTable-0.10.0-source.bundle`:

```sh
git bundle verify builds/GrimTable-0.10.0-source.bundle
git clone builds/GrimTable-0.10.0-source.bundle GrimTable-restored
```

`builds/GrimTable-0.10.0-source.zip` contains the same tracked source without Git
history. These local artifacts are fallback backups; they do not establish that
GitHub received anything. A GitHub upload is complete only after the remote URL
and matching remote branch commit have been verified.
