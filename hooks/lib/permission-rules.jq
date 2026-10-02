# Shared judgments about permission allow entries, loaded with `jq -L <dir> 'include "permission-rules"; …'`.
#
# Two callers: hooks/broad-grant-notice.sh asks whether a new entry is broad, and
# scripts/local-allow.sh asks that and whether user settings already cover a project's entry. One
# file, so the two cannot drift into flagging and pruning by different rules.

# `X:*` and `X *` are the same rule (settings.md); compare in one spelling.
def norm: if endswith(":*") then .[:-2] + " *" else . end;

def bash_inner: capture("^Bash\\((?<c>.*)\\)$").c;
def webfetch_domain: capture("^WebFetch\\(domain:(?<d>.*)\\)$").d;

def interpreters: ["python", "python3", "ruby", "node", "bash", "sh", "zsh", "perl", "php", "deno", "bun"];
# rtk's own subcommands, which wrap no command of the same name, so a leading `rtk ` is not looked
# through for them. `rtk env` shows variables, unlike the `env` runner below.
def rtk_natives: ["read", "smart", "json", "deps", "env", "log", "gain", "cc-economics", "config",
                  "discover", "session", "telemetry", "learn", "recall", "pipe", "trust", "untrust",
                  "verify", "hook-audit", "rewrite", "hook", "init", "help"];
def runners: ["rtk proxy", "rtk run", "rtk summary", "rtk test", "rtk err", "bundle exec",
              "bin/rails runner", "rails runner",
              "npx", "uv run", "xargs", "env", "direnv exec", "devenv shell", "nix run", "eval", "exec",
              "sudo", "timeout", "nohup"];

# broad — the entry grants a whole command, an interpreter, or a command runner. Deliberately loose:
#   - the tool-wide `Bash` entry
#   - one command word plus a trailing wildcard: `git *`, `python3:*`, `bin/rails*`
#   - an interpreter with any wildcard: `python3 -c ' *`
#   - a runner followed directly by a wildcard: `rtk proxy *`, `bundle exec *`
# A leading `rtk ` is looked through, so `rtk bundle *` reads as `bundle *`, except before a runner
# or one of rtk's own subcommands: `rtk recall *` is a subcommand grant.
def broad:
  if . == "Bash" then true
  elif test("^Bash\\(.*\\)$") | not then false
  else
    (bash_inner | norm) as $whole
    | (if ($whole | startswith("rtk "))
          and (any(runners[]; . as $r | $whole | startswith($r + " ")) | not)
          and (($whole[4:] | split(" ")[0]) as $sub | any(rtk_natives[]; . == $sub) | not)
       then $whole[4:] else $whole end) as $c
    | ($c | split(" ")[0] | split("/") | last) as $head
    | ($c | test("^[^ ]+ \\*$") or test("^[^ *]+\\*$"))
      or (any(interpreters[]; . == $head) and ($c | contains("*")))
      or any(runners[]; . as $r | $whole == $r + " *" or $c == $r + " *")
  end;

# covered($user) — an entry in $user (an allow array) already permits everything this one does: the
# same command, or a trailing-wildcard pattern (`X:*`, `X *`, `X*`) whose prefix this extends. For
# other tools, an exact match, a `*.domain` WebFetch, or `Skill(*)`.
def covered($user):
  . as $e
  | if startswith("Bash(") then
      (bash_inner | norm) as $c
      | any($user[] | select(startswith("Bash(")) | bash_inner | norm;
          . as $p
          | if endswith(" *") then ($p[:-2]) as $pre | ($c == $pre or $c == $p or ($c | startswith($pre + " ")))
            elif endswith("*") then ($c | startswith($p[:-1]))
            else $c == $p end)
    elif startswith("WebFetch(domain:") then
      webfetch_domain as $d
      | any($user[] | select(startswith("WebFetch(domain:")) | webfetch_domain;
          . as $w | $w == $d or (($w | startswith("*.")) and ($d | endswith($w[1:]))))
    elif startswith("Skill(") then any($user[]; . == "Skill(*)" or . == $e)
    else any($user[]; . == $e) end;

# dead — can never fire: `git status` (rtk rewrites it) and shell loop fragments.
def dead:
  . as $e
  | any(["Bash(git status:*)", "Bash(git status *)", "Bash(for:*)", "Bash(for f:*)",
         "Bash(done)", "Bash(break)", "Bash(exit)"][]; . == $e);

# oneoff — a Bash entry tied to one moment: a .claude/scratch/ path, an absolute home or temp path,
# or a `git -C`. Takes the home directory so the pattern is not the author's.
def oneoff($home):
  startswith("Bash(")
  and (contains(".claude/scratch/") or contains($home + "/")
       or contains("/private/tmp/") or contains("git -C "));
