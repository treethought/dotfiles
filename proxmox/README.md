# Proxmox

Two scripts: one builds the VM on the node, one configures the guest inside.

| Script | Runs on | Does |
| --- | --- | --- |
| `create-devbox.sh` | the node, as root | downloads the Fedora cloud image, checks it, creates the VM, imports the disk, attaches cloud-init, starts it, then pipes the bootstrap into the guest over SSH |
| `bootstrap-devbox.sh` | inside the guest, as your user | installs Nix, clones the repo, applies the Home Manager target, links the configs, joins the tailnet |

## Whole flow

```sh
./proxmox/create-devbox.sh
```

From the laptop, without copying anything to the node:

```sh
ssh root@pve 'bash -s' < proxmox/create-devbox.sh
```

That path fetches the bootstrap from `main`, so push the repo before using it.

## Running them separately

```sh
BOOTSTRAP=0 ./proxmox/create-devbox.sh          # VM only
ssh treethought@<guest-ip> 'bash -s' < proxmox/bootstrap-devbox.sh   # guest only
```

Re-running the bootstrap is how a guest is updated: it pulls, re-applies the target, and only
repeats steps that are already done.

## Options

`create-devbox.sh`: `VMID` (201), `NAME` (devbox), `IP` (default DHCP), `MEMORY` (8192),
`CORES` (4), `DISK` (48G), `STORE` (local-lvm), `BRIDGE` (vmbr0), `RELEASE`/`BUILD` (Fedora
version), `CIUSER`, `SSHKEYS`, `BOOTSTRAP` (0 to stop after the VM).

`bootstrap-devbox.sh`: `TARGET` (devbox), `REPO`, `DIR`, `TS_AUTHKEY` (skip the browser login),
`SKIP_TAILSCALE` (leave the guest off the tailnet), `SSH_KEY` (use an existing private key
instead of generating one), `SETUP_GH` (`1` to register the key without asking, `0` never).

Run on the guest, the three optional steps are questions: SSH key (default yes), join the
tailnet (default yes), register the key with GitHub (default no). Piped in over SSH there is
no tty, so those defaults apply silently and the variables above are how you change them. Over SSH these belong inside the remote
command, as above, because a prefix before `ssh` never reaches the guest.

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

## Several devboxes

Bootstrap one guest, clean it, then treat it as a template:

```sh
ssh treethought@<guest-ip> 'SKIP_TAILSCALE=1 bash -s' < proxmox/bootstrap-devbox.sh
```

Then inside it:

```sh
sudo cloud-init clean --logs --seed
sudo rm -f /etc/machine-id /etc/ssh/ssh_host_*
rm -rf ~/.zsh_history ~/.bash_history
sudo poweroff
```

And on the node:

```sh
qm template 201
qm clone 201 202 --name devbox2 --full
```

Clones keep the Nix store, so they skip the download and the `argocd` build entirely. Each clone
gets its own lease and should join the tailnet itself.

Details, host facts, and the backup/open items live in `docs/proxmox.md`.
