# Proxmox

Two scripts: one builds the VM on the node, one configures the guest inside.

| Script | Runs on | Does |
| --- | --- | --- |
| `create-devbox.sh` | the node, as root | downloads the Fedora cloud image, checks it, creates the VM, imports the disk, attaches cloud-init, starts it, then pipes the bootstrap into the guest over SSH |
| `bootstrap-devbox.sh` | inside the guest, as your user | installs Nix, clones the repo, applies the Home Manager target, links the configs, joins the tailnet |
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

## Running them separately

```sh
BOOTSTRAP=0 ./proxmox/create-devbox.sh             # VM only
./proxmox/bootstrap-devbox.sh --remote <guest-ip> # configure an existing guest
```

Re-running the bootstrap is how a guest is updated: it pulls, re-applies the target, and only
repeats steps that are already done.

## Destroying a guest

```sh
./proxmox/destroy-devbox.sh devbox2
./proxmox/destroy-devbox.sh 202
```

The cleanup runs before the VM goes away, because both steps need it alive: `tailscale logout`
inside the guest, and deleting the guest's SSH key from GitHub. An optional `ob sync-unlink`
disconnects the Obsidian vault, which only matters if the disks survive (a stopped VM or a backup
taken first); the device itself stays in Obsidian's version history. `SETUP_TAILSCALE=0`,
`SETUP_GH=0`, and `YES=1` answer the questions up front; `qm destroy --purge` also drops the VM
from backup jobs and replication.

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
`SETUP_TAILSCALE`, `SETUP_GH`, `SETUP_SECRETS`, `SETUP_OBSIDIAN`, each `1` or `0` to answer a
question without asking, plus `SECRETS_FILE` to point at a different file.

The optional steps are questions: SSH private key (a path, with Tab completion when run from a
terminal; empty generates one; `skip` for none), install Tailscale and join the tailnet
(default yes), copy `private/secrets.zsh` to the guest (default no), register the key with
GitHub via gh (default no). They are asked before any work starts, on whichever machine runs the
script, and the answers are handed to the guest as variables, so `--remote` needs no terminal
there. Without a terminal the defaults apply.

Subnet and gateway come from the node itself, so nothing here carries a site-specific address.

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
