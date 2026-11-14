# Proxmox host

Proxmox VE 9 on a single x86-64 host. It is headless: it lives next to the router with only
power and ethernet, and everything is driven from the Fedora laptop over SSH and the web UI at
`https://pve:8006`. Root-owned state belongs here rather than in Home Manager, the same
boundary `docs/fedora.md` describes for the laptop.

## Host facts

| Item | Value |
| --- | --- |
| Node name | `pve.lan` |
| Tailnet name | `pve` (MagicDNS) |
| Address | static lease on `vmbr0`; see `ip -4 a show vmbr0` |
| Gateway / DNS | LAN router (`ip -4 route show default`) / `1.1.1.1`, `9.9.9.9` |
| NIC MAC | `ip -br link show vmbr0` |
| Proxmox | `pve-manager 9.2.26`, Debian 13 (trixie) base |
| Kernel | `7.0.14-28-pve` |
| Disk | Samsung SSD 980 PRO 2TB, firmware `5B2QGXA7` |
| Time zone | `America/Los_Angeles`, systemd-timesyncd active |
| Storage | `local` (dir, 94 GiB), `local-lvm` (LVM-thin, 1.7 TiB) |

Access is `ssh root@pve` over the tailnet, which works from the laptop at home or away. The
root password is the one set during install.

## Network

The management interface is the **wired** NIC, `nic0`, bridged as `vmbr0`. A wifi card cannot
be bridged in station mode, so guests would lose their own LAN addresses and mDNS/SSDP
discovery, which breaks media clients and inbound ports such as slskd's. The wireless device
(`wlp0s20f3`) stays down. A later USB ethernet adapter appears as `enx<mac>` instead of
displacing `nic0`, so `vmbr0` keeps its port.

The LAN sits behind a Google/Nest router with a DHCP pool that is not user configurable, so
the host's address is only stable because of a **DHCP reservation for the NIC's MAC** in the
Google Home app (`ip -br link show vmbr0` prints it). Without the reservation the router will
eventually lease that address to something else while Proxmox keeps using it. Verify there is
no duplicate on the wire with:

```sh
arping -D -I nic0 -c 3 <node-ip>
```

Tailscale is installed on the host (`tailscaled` enabled) and is the primary path in: `pve`
resolves through MagicDNS everywhere, so nothing here needs a LAN address. The LAN address
remains the fallback when `tailscaled` is not running, and `qm terminal` or a monitor is the
last resort. The tailnet is a root-equivalent path into the hypervisor, so keep the node out of
any shared tailnet ACL that includes less-trusted devices.

## Repositories

The ISO configures only the enterprise repository, which requires a paid subscription token.
Left alone, `apt update` fails with `401 Unauthorized` and the host never receives kernel,
`pve-manager`, or security updates. The free repo carries the same packages, staged slightly
less. Do not enable both: community packages can outpace the staged enterprise copies.

`/etc/apt/sources.list.d/pve-no-subscription.sources`:

```
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```

`pve-enterprise.sources` and `ceph.sources` stay present but disabled with `Enabled: no`,
which keeps them valid deb822 stanzas; commenting out only the `URIs:` line makes apt fail with
`Malformed entry ... (URI)` because the field is mandatory inside a stanza.

Ceph stays disabled. It needs three nodes plus dedicated OSDs and is pointless on one host.
The free Ceph repo, if it is ever wanted, is `http://download.proxmox.com/debian/ceph-squid`
with component `no-subscription` (note: not `ceph-no-subscription`).

Apply on a new node:

```sh
f=/etc/apt/sources.list.d/pve-no-subscription.sources
echo 'Types: deb' > $f
echo 'URIs: http://download.proxmox.com/debian/pve' >> $f
echo 'Suites: trixie' >> $f
echo 'Components: pve-no-subscription' >> $f
echo 'Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg' >> $f
sed -i '/^URIs:/i Enabled: no' /etc/apt/sources.list.d/pve-enterprise.sources
sed -i '/^URIs:/i Enabled: no' /etc/apt/sources.list.d/ceph.sources
apt update && apt full-upgrade -y
pveversion -v | head -5
```

Long `printf` one-liners get mangled when pasted into a narrow terminal, which is why this
writes one field per short line. The login "no subscription" popup is cosmetic; ignore it
rather than patching `proxmoxlib.js`, which breaks on upgrades.

## Storage

The single NVMe carries a 1 GiB ESP, a 96 GiB ext4 root, 8 GiB of swap, and a 1.7 TiB
LVM-thin pool. `local` holds ISOs, templates, and `vzdump` output; `local-lvm` holds
guest disks. LVM-thin supports snapshots and rollback, needs free pool space to do it, and
offers no checksums or compression.

ZFS was the alternative: cheap snapshots, `lz4` compression, checksums, and `zfs send`
replication to a NAS, at the cost of ARC RAM and slower writes. Switching means reinstalling
with ZFS selected, so it is only worth deciding at install time.

There is one disk and therefore no redundancy. The protection comes from backups to the NAS
plus notification mail, not from the drive.

## Drive health

```sh
smartctl -a /dev/nvme0n1 | grep -iE 'self-assessment|firmware|percentage used|available spare|data units written|power on hours'
```

Expected results: `PASSED`, 100% available spare, and a slow rise in percentage used. The
firmware must be `5B2QGXA7` or newer: earlier 980 PRO 2TB revisions had a defect that caused
rapid wear and sometimes a permanently read-only drive. Do not flash back to an older
revision, and check the percentage periodically so a trend is visible while it can still be
acted on.

## Adding a node later

Nothing about the repo setup changes for a cluster; install each node with a unique hostname
and address, apply the same two source files, then join from the new node:

```sh
pvecm create <cluster-name>     # on the first node
pvecm add <first-node-ip>        # on each additional node
```

Keep nodes on the same package versions, since the free repo has no staging delay and
independent upgrades can desynchronise `pve-manager` and the kernel across a cluster.
Two nodes is an awkward quorum; three is the point where Ceph and HA become sensible.

## Headless dev VM (`devbox`)

The first permanent guest is a headless Fedora VM used as the shared place to write code, run
agents, and keep long-lived zellij sessions that survive moving between laptops. It uses the
`devbox` Home Manager target, which composes `nix/common.nix` plus `nix/fedora.nix`: the same
CLI tooling and shell as the laptop, without `nix/desktop.nix` and the audio, Flatpak, and font
modules it pulls in. `nix/README.md` explains the layout.

Create it with `proxmox/create-devbox.sh <name> [vmid]`, run from the laptop with `NODE=pve`. It
streams itself
to the node, downloads the Fedora Cloud Base Generic qcow2 if needed, verifies its checksum,
creates the VM, imports the disk as `scsi0`, attaches a cloud-init drive, starts it, reads the
guest address from the agent, and then runs the bootstrap against the guest from here:

```sh
./proxmox/create-devbox.sh            # 201, devbox, DHCP lease
VMID=202 IP=192.0.2.50 ./proxmox/create-devbox.sh   # optional: pin a static address
```

After `qm start` it waits for the guest agent to report a lease and pipes
`bootstrap-devbox.sh` into the guest over SSH, so one command takes a new VM all the way to a
working devbox. `BOOTSTRAP=0` stops after the VM exists. When the script itself is being
streamed, it fetches the bootstrap from `main` instead of the neighbouring file, so the copy in
the repo must be pushed for that path to work.

The node-side script can also be run directly when it is already there, and `BOOTSTRAP=0` stops
after the VM exists, reporting its address as `GUEST_IP`.

The `qm` calls themselves only exist on the node, so this has to run there; a remote
invocation is just a wrapper around root SSH. Driving it from the REST API instead would mean
an API token plus polling the `importdisk` task, which is not worth it for a personal script.
The image download is skipped when the qcow2 is already in `/var/lib/vz/template/iso/`; the
checksum is re-verified on every run.

The guest address is not configured anywhere: the script reads the subnet prefix from the
bridge and the gateway from the node's default route, then leaves the guest on DHCP. Pass
`IP=<addr>` for a fixed address instead.

Everything else is overridable by environment: `VMID NAME IP DNS BRIDGE STORE MEMORY CORES
DISK CIUSER RELEASE BUILD SSHKEYS`. It refuses to run if the VM ID already exists, so
re-running never half-rebuilds a guest.

The steps it performs, if it ever needs doing by hand:

```sh
qm create 201 --name devbox --memory 8192 --cores 4 --ostype l26 --cpu host \
  --scsihw virtio-scsi-pci --net0 virtio,bridge=vmbr0 \
  --agent enabled=1 --serial0 socket --onboot 1
qm importdisk 201 Fedora-Cloud-Base-Generic-45-1.4.x86_64.qcow2 local-lvm   # from /var/lib/vz/template/iso
qm set 201 --scsi0 local-lvm:vm-201-disk-0 --boot order=scsi0               # read unused0 from qm config
qm set 201 --ide2 local-lvm:cloudinit
qm set 201 --ciuser treethought --sshkeys /root/.ssh/authorized_keys \
  --ipconfig0 ip=dhcp --nameserver 1.1.1.1
qm resize 201 scsi0 48G
qm start 201
```

Cloud-init gives the user passwordless sudo and the host's `authorized_keys`, so it is
reachable on whatever lease the router hands out, or through the console with
`qm terminal 201`. Read the lease from the host with
`qm guest cmd 201 network-get-interfaces`, then reserve that address in the Google Home app so
the name and address stay put.

Each new guest is a new host key. An interactive `ssh` asks once and records it, but anything
non-interactive (`ssh -o BatchMode=yes` from a script, or the create/verify steps run without
a TTY) has no way to answer that prompt and fails with `Host key verification failed`. Trust
it explicitly in that case:

```sh
ssh-keyscan -t ed25519 <guest-ip> >> ~/.ssh/known_hosts
```

`create-devbox.sh` itself does not SSH to the guest, so this is only needed by later
automation. It does need the *node's* key trusted, which is already true for the
`ssh root@pve 'bash -s'` invocation. A guest created before its lease is reserved
will change address on reboot, which breaks `known_hosts` again; reserve first, then trust.

Bootstrap the user environment with `proxmox/bootstrap-devbox.sh`: it installs Nix, clones the
repo, applies the `devbox` target, runs `install.sh`, and joins the tailnet when `TS_AUTHKEY`
is set. Re-running it only repeats the switch.

```sh
./proxmox/bootstrap-devbox.sh --remote devbox                 # stream it to the guest
TS_AUTHKEY=tskey-auth-... ./proxmox/bootstrap-devbox.sh --remote devbox
```

The optional steps are questions, asked before any work starts on whichever machine runs the
script: SSH private key (a path, with Tab completion; empty to generate one; `skip` for none), install Tailscale and
join the tailnet (default yes),
register the key with gh (default no). The answers are handed to the guest as variables, so `--remote` needs no terminal there,
and `bash -s < script` applies the defaults.

Fedora needs `git` and `curl` first (`sudo dnf install -y git curl`); the script checks and
stops with that message. It uses the Determinate Nix installer because the upstream one aborts
on SELinux (nix#2374), which Fedora enforces, and because the laptop runs the same one.

### Zero-touch first boot

To remove the manual step, let cloud-init run the same script:

```sh
pvesm set local --content backup,iso,vztmpl,snippets
```

`/var/lib/vz/snippets/devbox.yaml`:

```yaml
#cloud-config
users:
  - name: treethought
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /usr/bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... you@laptop
runcmd:
  - curl -fsSL https://raw.githubusercontent.com/treethought/dotfiles/main/proxmox/bootstrap-devbox.sh -o /tmp/bootstrap-devbox.sh
  - chmod 755 /tmp/bootstrap-devbox.sh
  - runuser -u treethought -- /tmp/bootstrap-devbox.sh
```

```sh
qm set 201 --cicustom user=local:snippets/devbox.yaml
```

Two constraints: overriding `user` replaces the user-data PVE generates, so the snippet has to
carry the account and key that `--ciuser`/`--sshkeys` would write (network config is separate
and unaffected), and `runcmd` runs as root, which is why it drops to the user with `runuser`.
Passing `TS_AUTHKEY` here means storing the key in the snippet on the host; leave it out and run
`tailscale up` once by hand instead.

Confirm the target evaluates from the laptop before relying on it:

```sh
nix build -o /tmp/devbox-check .#homeConfigurations.devbox.activationPackage
```

Notes:

- `mosh` is part of the target, so `mosh devbox` survives wifi drops and network changes
  instead of dropping the zellij session. Sessions persist anyway; mosh removes the reconnect
  friction.
- Because this guest is permanent, it is the first thing worth a `vzdump` job. Until the NAS
  storage exists, back it up to `local` so a bad `dnf` or `nix` upgrade is recoverable.
- Snapshots before upgrades: `qm snapshot 201 pre-upgrade`, roll back with `qm rollback`.

## Operational notes

- Proxmox autostarts guests flagged `onboot`, so a power cut recovers without a login. Set
  that on anything meant to be always up.
- BIOS: enable "power on after AC loss" and disable "halt on keyboard error", since there is
  no keyboard attached. Business-class vPro machines expose Intel AMT for remote KVM;
  consumer hardware does not.
- Guests stay on the LAN with their own addresses, which is what makes media discovery and
  inbound ports work. Remote access is a Tailscale node on the host or inside individual
  guests, not a port forward.
