# Cloud adapters

`cloud.sh` syncs the personal store's knowledge files — `prefer/*.md`,
`deferred/*.md`, `ignore.md` — with a remote through one of the files in this
directory. The engine (three-way merge, conflict copies, locks, index rebuild)
lives in `cloud.sh`; an adapter only knows how to list, get, put and delete
objects somewhere. To support another storage, add one file here. Nothing
else changes.

Shipped:

| Adapter | Remote | Needs |
|---|---|---|
| `s3` | any S3-compatible bucket: Cloudflare R2, AWS S3, Backblaze B2, MinIO | `curl`, `openssl` (SigV4 is done in bash) |
| `local` | a directory: NFS/SMB mount, a Dropbox or Drive desktop folder, a test fixture | nothing |

## The contract

`cloud.d/<name>.sh` is sourced by `cloud.sh` after `cloud.conf` is loaded. It
defines these functions (all run with `set -u`; return non-zero on failure and
print a one-line reason with `warn`):

| Function | Called | Must do |
|---|---|---|
| `adapter_setup "$@"` | by `cloud.sh setup <name> …` | Turn flags into `CFG[key]` values and `ask` for whatever is still missing. Every key `adapter_init` needs must be set when it returns. |
| `adapter_init` (optional) | after every config load | Derive working variables from `CFG`; `die` on a missing or invalid key. |
| `adapter_check` | by `setup` and `status` | A cheap access test — one list call. On failure, say what to fix. |
| `adapter_list` | at the start of every sync | Print one line per stored object in the synced set: `path<TAB>token<TAB>mtime` — `path` relative to the store (`prefer/<slug>.md`), `token` an opaque string that changes whenever the content changes (ETag, content hash, version id), `mtime` seconds since the epoch or `0` when unknown. Objects outside the set may be printed; the engine ignores them. |
| `adapter_get <path> <localfile>` | to pull | Write the object's content to `<localfile>`. Return 2 when the object does not exist. |
| `adapter_put <path> <localfile>` | to push | Store the file. Print the new token on stdout (print `?` if the backend does not tell you — the next sync repairs it). |
| `adapter_delete <path>` | to propagate a deletion | Remove the object. Return 0 when it was already gone. |

Available inside an adapter: the `CFG` associative array and `cfg <key>
[default]`; `ask <key> <prompt> [default] [secret]` (keeps an existing value,
otherwise prompts on the terminal); `say`, `warn`, `die`; `hash_file <file>`
(sha256) and `mtime_of <file>`; `STORE` (the personal store) and `CLOUD`
(`<store>/.state/cloud`, for scratch state). Append any temporary path you
create to the `CLEANUP` array — `cloud.sh` removes them on exit — rather
than setting an EXIT trap of your own.

What the engine guarantees an adapter:

- Only paths in the synced set are ever passed to `get`, `put`, `delete`.
- One sync at a time per machine (a lock under `.state/cloud/`), and never
  while a consolidation holds the personal store's lock.
- Tokens are compared for equality only. A wrong or unknown token costs one
  extra fetch on the next sync, after which the real token is recorded — it
  cannot cause data loss.
- "Newer wins" on a two-sided change uses the `mtime` you return against the
  local file's mtime; with `0` the local copy wins and the remote copy is
  kept as the conflict file.

## Trying one

```bash
export RATHER_THAN_HOME=/tmp/rt-test            # a scratch store
mkdir -p "$RATHER_THAN_HOME/prefer"; printf -- '---\ntopic: t\n---\n' > "$RATHER_THAN_HOME/prefer/a.md"
bash skills/rather-than/scripts/cloud.sh setup <name> --yes …flags…   # first sync
bash skills/rather-than/scripts/cloud.sh sync                          # must report nothing to do
bash skills/rather-than/scripts/cloud.sh status                        # access ok + empty plan
```

## Where the config lives

`<store>/cloud.conf` — for a store at `~/.claude/rather-than` that is
`~/.claude/rather-than/cloud.conf`. `key = value` per line; lines starting
with `#` are comments; no inline comments (secrets may contain `#`). Keep it
mode 600; `setup` writes it that way. `RATHER_THAN_CLOUD_CONFIG=/path` points
at another file. The file itself is never synced.

### Cloudflare R2

1. Dashboard → **R2 Object Storage** → **Create bucket** → name `rather-than`,
   location Automatic. Free tier: 10 GB, 1M writes and 10M reads a month, no
   egress fees.
2. **Manage R2 API Tokens** → **Create API token** → permission **Object Read
   & Write**, scope it to that one bucket. Copy the **Access Key ID** and
   **Secret Access Key** (shown once).
3. **Overview** → copy the **Account ID**.
4. Write the file:

```ini
# ~/.claude/rather-than/cloud.conf
adapter = s3
provider = r2
account_id = 0123456789abcdef0123456789abcdef
bucket = rather-than
prefix = personal
access_key_id = …
secret_access_key = …
```

Then `chmod 600 ~/.claude/rather-than/cloud.conf`, and run
`bash <plugin>/skills/rather-than/scripts/cloud.sh status` (access check plus
a dry-run plan) followed by `… cloud.sh sync`. Or let `cloud.sh setup s3` ask
for the same values and write the file for you. Same file on the second
machine; its first sync pulls everything.

### MinIO (self-hosted)

```ini
adapter = s3
provider = minio
endpoint = http://minio.local:9000     # or https://…; path-style addressing, which MinIO expects
region = us-east-1                     # MinIO's default; match MINIO_REGION if you set one
bucket = rather-than                   # create it first: mc mb local/rather-than
prefix = personal
access_key_id = …                      # a service account or user key with read/write on the bucket
secret_access_key = …
```

`cloud.sh setup s3 --provider minio --endpoint http://minio.local:9000 --bucket rather-than --prefix personal --access-key … --secret-key …`
does the same non-interactively.

### AWS S3 / Backblaze B2 / anything else S3-compatible

```ini
adapter = s3
provider = aws            # region = eu-west-1 ; addressing = virtual (default for aws)
# provider = other        # endpoint = https://s3.us-west-004.backblazeb2.com ; region = us-west-004
bucket = …
prefix = personal
access_key_id = …
secret_access_key = …
```
