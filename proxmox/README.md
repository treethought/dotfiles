# Proxmox

Three scripts: one builds the VM on the node, one configures the guest inside, one re-applies the
committed config to a guest that already exists.

| Script | Runs on | Does |
| --- | --- | --- |
| `create-devbox.sh` | the node, as root | downloads the Fedora cloud image, checks it, creates the VM, imports the disk, attaches cloud-init, starts it, then pipes the bootstrap into the guest over SSH |
| `bootstrap-devbox.sh` | inside the guest, as your user | installs Nix, clones the repo, applies the Home Manager target, links the configs, joins the tailnet |
| `update-devbox.sh` | anywhere with ssh to the guest | answers the first-run questions "no" and re-runs the bootstrap, so a change lands without going through the prompts |
| `destroy-devbox.sh` | anywhere with ssh to the node | logs the guest out of the tailnet, optionally deletes its key from GitHub, then destroys the VM and its disks |

## Whole flow

```sh
./proxmox/create-devbox.sh [name] [vmid]
```

The name defaults to `devbox` and the vmid to the next one above the highest in use. `NODE`
names a host with root SSH access and defaults to `root@pve`, so this works from the laptop; on a
node it is ignored and everything runs locally. The script streams itself to that node, reads the
guest address back from it, then runs `bootstrap-devbox.sh` against the guest directly, so the
node is not involved after the VM exists and the questions are asked where you started.

When it finishes it prints how to reach the guest:

```
connect:
  ssh treethought@192.168.86.53
  ssh treethought@devbox3
```

The tailnet form appears only once MagicDNS resolves it, so a run with `SETUP_TAILSCALE=0` shows
the address alone.

## Updating a guest

```sh
./proxmox/update-devbox.sh                    # the guest named devbox
./proxmox/update-devbox.sh devbox2
./proxmox/update-devbox.sh devbox2 --agents --secrets
```

It runs the bootstrap with every first-run step answered "no", so nothing is asked and only the
steps that are always needed run: pull, `home-manager switch`, `install.sh`, `bin/install-tools.sh`.

The guest can be named three ways:

| Form | Example | How it is found |
| --- | --- | --- |
| tailnet name | `devbox` | MagicDNS, so it resolves from anywhere on the tailnet |
| LAN address | `192.168.86.53` | used as given |
| VM id | `101` | `qm list` on `NODE`, then the address from the guest agent |

A name that does not resolve, or a guest that never joined the tailnet, is looked up on `NODE`
(`root@pve` by default) and its address read from the guest agent there. A bare number is always
read as a VM id, since `getent` would otherwise treat it as the address `0.0.0.<n>`.

Before touching the guest it checks that ssh works, and warns when this checkout has commits that
are not pushed or files that are not committed: the guest pulls from GitHub, so neither would
arrive. `--push` pushes this branch first, which is the one-command version of that.

The flags turn individual first-run steps back on: `--key`, `--gh` (needs `--key`), `--tailnet`,
`--secrets`, `--agents`, `--repos`, `--obsidian`. `TARGET` picks the Home Manager target
(default `devbox`).

## Running them separately

```sh
BOOTSTRAP=0 ./proxmox/create-devbox.sh             # VM only
./proxmox/bootstrap-devbox.sh --remote <guest-ip> # configure an existing guest
```

Re-running the bootstrap is also how a guest is updated, but it asks the first-run questions
again; `update-devbox.sh` is the same path with those answers supplied. `--remote` takes anything
ssh can reach, so a tailnet name works as well as an address; `update-devbox.sh` adds the VM id
and the node lookup.

## Destroying a guest

```sh
./proxmox/destroy-devbox.sh devbox2
./proxmox/destroy-devbox.sh 202
```

The cleanup runs before the VM goes away, because it needs the guest alive: `tailscale logout` and
`ob sync-unlink` inside the guest, then `qm destroy --purge`, which also drops the VM from backup
jobs and replication. Both cleanup steps run without asking; `SETUP_TAILSCALE=0` and
`SETUP_OBSIDIAN=0` skip them. Unlinking only matters if the disks survive (a stopped VM, or a backup
taken first), and the device stays in Obsidian's version history either way.

The one question is whether to delete the guest's SSH key from GitHub, which defaults to no because
it reaches into the account rather than the guest. `SETUP_GH=1` deletes it without asking,
`SETUP_GH=0` skips it, and `YES=1` confirms both the destroy and the key deletion.

Deleting the GitHub key needs the public-key scope, which `gh auth login` does not request by
default: `gh auth refresh -s admin:public_key`. Without it the script says so and leaves the key
alone, so you can remove it in the web UI.

## Options

`create-devbox.sh`: `VMID` (201), `NAME` (devbox), `IP` (default DHCP), `MEMORY` (8192),
`CORES` (4), `DISK` (48G), `STORE` (local-lvm), `BRIDGE` (vmbr0), `RELEASE`/`BUILD` (Fedora
version), `CIUSER`, `SSHKEYS`, `BOOTSTRAP` (0 to stop after the VM).

`bootstrap-devbox.sh`: `TARGET` (devbox), `REPO`, `DIR`, `TS_AUTHKEY` (skip the browser login),
`SSH_KEY` (path on the machine running the script to an existing private key, also offered
as the prompt's default; its public half is derived or copied alongside), and `SETUP_KEY`,
`SETUP_TAILSCALE`, `SETUP_GH`, `SETUP_SECRETS`, `SETUP_AGENTS`, `SETUP_REPOS`, `SETUP_OBSIDIAN`,
each `1` or `0` to answer a question without asking, plus `SECRETS_FILE`, `AGENTS_DIR`,
`AGENTS_MD`, `REPOS_FILE`, and `REPO_HOME` to point at different paths.

The optional steps are questions: SSH private key (a path, with Tab completion when run from a
terminal; empty generates one; `skip` for none), install Tailscale and join the tailnet
(default yes), copy `private/secrets.zsh` to the guest (default no), clone the repositories
listed in `private/repos.txt` (default yes, asked only when the file has entries), register the
key with GitHub via gh (default no). They are asked before any work starts, on whichever machine
runs the script, and the answers are handed to the guest as variables, so `--remote` needs no
terminal there. Without a terminal the defaults apply.

Subnet and gateway come from the node itself, so nothing here carries a site-specific address.

## Extra repositories

`private/repos.txt` is an ignored file listing repositories to clone on a guest, one
`owner/name` per line; blank lines and `#` comments are ignored. A `dir <path>` line sets the
directory for the lines below it, and a repository without one goes to `REPO_HOME/<name>`, which
defaults to `~/projects`.

```
dir ~/bsky
bluesky-social/indigo

dir ~/projects
treethought/dotfiles
```

A line may still name its own directory, which wins over the group: `owner/name ~/somewhere`.

It lives in `private/` because it names private repositories, and the public repo should not
carry that. The bootstrap copies it to the guest when it answers the question yes, and
`update-devbox.sh --repos` clones anything missing. An existing checkout is never pulled or
modified, and a repository that will not clone is reported without stopping the run. Cloning
tries `gh` first, so `gh auth login` on the guest is what makes a private repository work;
otherwise it falls back to https and ssh.

## Git over SSH from a guest

GitHub does not allow anonymous SSH, so the bootstrap clones over https and then sorts out a key:
it copies `SSH_KEY` if you set one, otherwise generates an Ed25519 key on the guest. Registering
that key is opt-in, since `gh` needs an authenticated account; with `SETUP_GH=1` (or answering
yes) it runs `gh ssh-key add` and, on success, points the remote at SSH. Registration needs an
interactive `gh auth login` on the guest; without it the script prints the key and the command
to add it:

```sh
git -C ~/dotfiles remote set-url origin git@github.com:treethought/dotfiles.git
```

The URL rewrite that sends https GitHub URLs over SSH is machine-local (in
`git/gitconfig.local.private`), so a guest without a key cannot be broken by it.

Details, host facts, and the backup/open items live in `docs/proxmox.md`.
