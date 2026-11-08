#!/usr/bin/env bash
# PreToolUse hook for bash. Three tiers, mirroring ~/.claude/settings.json:
#   exit 2            -> block (destructive deny list)
#   {"decision":"allow"} -> auto-approve (safe read-only allow list)
#   exit 0 (silent)   -> no opinion, Crush prompts the user
# Crush has no per-command allow/deny in config, so it lives here.

cmd="${CRUSH_TOOL_INPUT_COMMAND:-}"
[ -z "$cmd" ] && exit 0

deny() { echo "blocked by deny-dangerous hook: $1" >&2; exit 2; }
allow() { echo '{"decision":"allow"}'; exit 0; }
rewrite() {
  printf '{"decision":"allow","updated_input":{"command":"%s"}}\n' "$1"
  exit 0
}

# --- Tier 1: deny (scans anywhere in the command) ---
case "$cmd" in
  *sudo\ *)                              deny "sudo" ;;
  *rm\ -rf\ /*|*rm\ -rf\ ~*)             deny "rm -rf of / or ~" ;;
  *pulumi\ stack\ rm*)                   deny "pulumi stack rm" ;;
  *pulumi\ destroy*)                     deny "pulumi destroy" ;;
  *pulumi\ up\ --yes*)                   deny "pulumi up --yes" ;;
  *ansible-playbook\ *--check*)           ;;
  *ansible-playbook\ *)                   deny "non-read-only ansible-playbook command" ;;
  *git\ push\ --force*|*git\ push\ -f*)  deny "git force push" ;;
  *git\ push*)                           deny "git push" ;;
  *git\ reset\ --hard*)                  deny "git reset --hard" ;;
  *git\ clean\ -fd*)                     deny "git clean -fd" ;;
  *aws\ s3\ rb*)                         deny "aws s3 rb" ;;
  *aws\ s3\ rm*--recursive*)             deny "aws s3 rm --recursive" ;;
  *aws\ ec2\ terminate-instances*)       deny "aws ec2 terminate-instances" ;;
  *aws\ rds\ delete-db-instance*)        deny "aws rds delete-db-instance" ;;
  *--profile\ admin*|*AWS_PROFILE=admin*) deny "AWS admin profile" ;;
  *kubectl\ delete*)                     deny "kubectl delete" ;;
  *dropdb*)                              deny "dropdb" ;;
  *brew\ install*)                       deny "brew install" ;;
  *gh\ pr\ merge*)                       deny "gh pr merge" ;;
  *gh\ pr\ close*)                       deny "gh pr close" ;;
  *gh\ release\ create*)                 deny "gh release create" ;;
  *gh\ release\ delete*)                 deny "gh release delete" ;;
  *gh\ repo\ delete*)                    deny "gh repo delete" ;;
esac

# --- Guard: don't auto-allow chained/redirected/substituted commands.
# A safe prefix could otherwise smuggle a second command past the allow tier.
# Pipes are fine: the deny tier already scanned the whole string.
case "$cmd" in
  gcx\ logs\ query\ *) allow ;;
  gcx\ metrics\ query\ *) allow ;;
  *";"*|*"&&"*|*"||"*|*">"*|*"<"*|*'$('*|*'`'*) exit 0 ;;
esac

# Strip a single leading VAR=val assignment (e.g. KAFKA_PROVIDER=x go test ...).
probe="$cmd"
case "$probe" in
  [A-Za-z_]*=*\ *) probe="${probe#* }" ;;
esac

# AWS commands always use the Engineer role, even if Crush inherited another
# profile from its parent shell.
case "$cmd" in
  AWS_PROFILE=engineer\ aws\ *) ;;
  aws\ *) rewrite "AWS_PROFILE=engineer $cmd" ;;
esac

# --- Tier 2: allow (safe, read-only; matched at command start) ---
case "$probe" in
  # file / text inspection
  ls\ *|ls|cat\ *|head\ *|tail\ *|wc\ *|file\ *|stat\ *|du\ *) allow ;;
  basename\ *|dirname\ *|realpath\ *|shasum\ *|diff\ *) allow ;;
  grep\ *|rg\ *|sort\ *|uniq\ *|cut\ *|tr\ *|awk\ *|jq\ *|find\ *) allow ;;
  ast-grep\ *|sg\ *|shellcheck\ *|pdftotext\ *) allow ;;
  # host / net info (read-only)
  which\ *|whoami|id|hostname|uname\ *|date\ *|ps\ *|df\ *|top\ *) allow ;;
  dig\ *|host\ *|nslookup\ *|ping\ *|ifconfig\ *|whois\ *|tailscale\ status*) allow ;;
  # git (read-only)
  git\ status*|git\ log*|git\ diff*|git\ show*|git\ branch*) allow ;;
  git\ ls-tree*|git\ ls-files*|git\ remote*|git\ rev-parse*) allow ;;
  git\ stash\ list*|git\ check-ignore*|git\ -C\ *) allow ;;
  # go / lint / fmt
  go\ build*|go\ test*|go\ get*|go\ list*|go\ doc*|go\ vet*|go\ mod*) allow ;;
  go\ version*|go\ tool*|go\ fmt*|go\ run*|gofmt\ *|goimports\ *|golangci-lint\ *) allow ;;
  # gh (read-only)
  gh\ run\ list*|gh\ run\ view*|gh\ run\ watch*|gh\ pr\ list*|gh\ pr\ view*) allow ;;
  gh\ pr\ status*|gh\ pr\ diff*|gh\ pr\ checks*|gh\ issue\ list*|gh\ issue\ view*) allow ;;
  gh\ issue\ status*|gh\ repo\ view*|gh\ repo\ list*|gh\ search*|gh\ browse*) allow ;;
  gh\ workflow\ list*|gh\ workflow\ view*|gh\ label\ list*|gh\ auth\ status*|gh\ api\ *) allow ;;
  # kubectl (read-only)
  kubectl\ get*|kubectl\ describe*|kubectl\ logs*|kubectl\ top*|kubectl\ config*) allow ;;
  kubectl\ --*\ get*|kubectl\ --*\ describe*|kubectl\ --*\ logs*|kubectl\ --*\ top*|kubectl\ --*\ config*) allow ;;
  kubectl\ explain*|kubectl\ api-resources*|kubectl\ api-versions*|kubectl\ cluster-info*) allow ;;
  kubectl\ --*\ explain*|kubectl\ --*\ api-resources*|kubectl\ --*\ api-versions*|kubectl\ --*\ cluster-info*) allow ;;
  kubectl\ version*|kubectl\ diff*|kubectl\ rollout\ history*|kubectl\ rollout\ status*|kubectl\ auth\ can-i*) allow ;;
  kubectl\ --*\ version*|kubectl\ --*\ diff*|kubectl\ --*\ rollout\ history*|kubectl\ --*\ rollout\ status*|kubectl\ --*\ auth\ can-i*) allow ;;
  # pulumi (read-only)
  pulumi\ stack\ output*|pulumi\ stack\ ls*|pulumi\ stack\ history*) allow ;;
  pulumi\ stack\ tag\ get*|pulumi\ stack\ tag\ ls*|pulumi\ preview*) allow ;;
  # aws / helm (read-only shapes)
  aws\ *\ describe-*|aws\ *\ list-*|aws\ *\ get-*|aws\ *\ search-*|aws\ s3\ ls*) allow ;;
  helm\ show*|helm\ get*|helm\ list*|helm\ repo\ list*|helm\ dependency\ list*) allow ;;
  # docker (read-only)
  docker\ ps*|docker\ images*|docker\ logs*|docker\ inspect*|docker\ stats*) allow ;;
  docker\ compose\ ps*|docker\ compose\ logs*|docker\ compose\ config*) allow ;;
  # tooling
  just\ test*|linear\ *|obsidian\ search*) allow ;;
  lnx\ describe*|lnx\ list*|lnx\ search*|lnx\ comment\ list*) allow ;;
  lnx\ project\ list*|lnx\ team\ list*|lnx\ state\ list*|lnx\ label\ list*) allow ;;
  lnx\ cycle\ list*|lnx\ member\ list*) allow ;;
  gcx\ commands*|gcx\ help*|gcx\ help-tree*|gcx\ version*|gcx\ config\ view*) allow ;;
  gcx\ config\ current-context*|gcx\ config\ contexts*|gcx\ config\ check*) allow ;;
  gcx\ dashboards\ get*|gcx\ dashboards\ list*|gcx\ dashboards\ search*|gcx\ dashboards\ versions\ list*) allow ;;
  gcx\ datasources\ get*|gcx\ datasources\ list*|gcx\ datasources\ *\ query*|gcx\ datasources\ *\ labels*) allow ;;
  gcx\ datasources\ *\ metadata*|gcx\ datasources\ *\ metrics*|gcx\ datasources\ *\ series*|gcx\ datasources\ *\ get*) allow ;;
  gcx\ logs*|gcx\ metrics*|gcx\ profiles*|gcx\ traces*|gcx\ resources\ get*) allow ;;
  gcx\ slo\ definitions\ list*|gcx\ slo\ definitions\ status*|gcx\ slo\ definitions\ timeline*) allow ;;
  gcx\ slo\ reports\ status*|gcx\ slo\ reports\ timeline*|gcx\ synthetic-monitoring\ checks\ status*) allow ;;
  gcx\ synthetic-monitoring\ checks\ timeline*|gcx\ stacks\ list*|gcx\ stacks\ get*) allow ;;
  gcx\ kg\ diagnose*|gcx\ kg\ entities*|gcx\ kg\ insights*|gcx\ kg\ meta*|gcx\ kg\ summary*) allow ;;
  *\ --help|*\ --version) allow ;;
esac

# Tier 3: no opinion -> Crush prompts.
exit 0
