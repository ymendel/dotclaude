#!/usr/bin/env python3
"""PermissionRequest hook: approves asking a CLI for its help or version.

No allow rule can cover this. A Bash rule has to start with the command name, so `--help` for every
tool would take one entry per tool. So this parses the command and approves two shapes:

    <name> --help | --version
        for any bare command name.
    <tool> <subcommand…> --help | --version
    <tool> help [topic…]
        for the tools in SUBCOMMAND_TOOLS only.

The split exists because a word before `--help` is not always a subcommand. BSD tools stop reading
options at the first operand, so `rm notes.txt --help` deletes notes.txt and then reports `--help`
as a missing file, and `rm help topic` deletes two files. Only a tool with a real subcommand parser
reads those words as subcommands, and that has to be known rather than inferred.

Either shape may be piped into grep, head or tail, and may carry a `2>&1`. Anything else that makes
the shell do more than run one command is refused: chaining, other redirects, expansion. A path
(`./scripts/x`, `bin/rails`) is refused because a repo script is the likeliest thing to ignore its
arguments and run anyway, and `-h` is refused because too many tools read it as something else.

WRAPPERS are refused anywhere in the command, since `bundle exec x --help` runs x and `npx pkg
--help` downloads pkg. That over-refuses some genuine subcommands (`gh run list --help`), which only
costs a prompt.

Approves or abstains, never denies. Checks live in hooks/test/run-help-version-allow.sh.
"""

import datetime
import json
import os
import re
import shlex
import sys

HELP_FLAGS = {"--help", "--version"}

SUBCOMMAND_TOOLS = {
    "brew", "bundle", "cargo", "claude", "docker", "gem", "gh", "git", "go", "heroku", "log",
    "mise", "npm", "overmind", "rtk", "uv",
}

WRAPPERS = {
    "bash", "bunx", "dlx", "doas", "env", "err", "eval", "exec", "just", "make", "nice", "nohup",
    "npx", "pipx", "pnpx", "proxy", "rake", "run", "sh", "source", "sudo", "task", "test", "time",
    "timeout", "uvx", "watch", "x", "xargs", "zsh",
}

FILTERS = [
    ["grep"], ["rtk", "grep"], ["rtk", "proxy", "grep"],
    ["head"], ["rtk", "head"], ["tail"], ["rtk", "tail"],
]

# A subcommand, topic, or command name: no path, no option, nothing the shell would read.
WORD = re.compile(r"^[A-Za-z0-9][A-Za-z0-9:._-]*$")

# `2>&1` merges stderr into the pipe and writes nothing, so it is dropped before parsing.
STDERR_MERGE = re.compile(r"(?<=\s)2>&1(?=\s|\||$)")

# `$` and backticks expand even inside double quotes, which shlex treats as literal text.
UNSAFE_CHARS = set("$`\n\r")

OPERATOR_CHARS = set("();<>|&")

LOG = os.environ.get(
    "CLAUDE_HELP_VERSION_LOG", os.path.expanduser("~/.claude/.help-version-allow.log")
)


def log_decision(reason, command):
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = " ".join(command.split())[:200] if command else "-"
    try:
        with open(LOG, "a") as log_file:
            log_file.write(f"{timestamp} {reason} {line}\n")
    except OSError:
        pass


def is_word(token):
    return bool(WORD.match(token))


def is_filter(segment):
    return any(segment[: len(prefix)] == prefix for prefix in FILTERS)


def head_reason(head):
    if not head:
        return "shape"

    name, rest = head[0], head[1:]
    if "/" in name:
        return "path"
    if not is_word(name):
        return "shape"
    if any(token in WRAPPERS for token in head):
        return "wrapper"

    if len(rest) == 1 and rest[0] in HELP_FLAGS:
        return "allow"

    if name not in SUBCOMMAND_TOOLS:
        return "unlisted-tool"

    if len(rest) >= 2 and rest[-1] in HELP_FLAGS and all(is_word(token) for token in rest[:-1]):
        return "allow"
    if rest[:1] == ["help"] and all(is_word(token) for token in rest[1:]):
        return "allow"

    return "shape"


def decide(command):
    if any(char in UNSAFE_CHARS for char in command):
        return "unsafe-char"

    lexer = shlex.shlex(STDERR_MERGE.sub("", command), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return "unparsed-command"

    segments = [[]]
    for token in tokens:
        if token == "|":
            segments.append([])
        elif token and set(token) <= OPERATOR_CHARS:
            return "compound"
        else:
            segments[-1].append(token)

    if any(not segment for segment in segments):
        return "compound"
    if not all(is_filter(segment) for segment in segments[1:]):
        return "filter"

    head = segments[0]
    reason = head_reason(head)
    # RTK passes most tools through unprefixed, but a hand-written `rtk <tool> --help` still arrives.
    if reason != "allow" and head[:1] == ["rtk"]:
        unprefixed = head_reason(head[1:])
        if unprefixed == "allow":
            return unprefixed
    return reason


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        log_decision("unparsed", "")
        return

    if payload.get("tool_name") != "Bash":
        log_decision("wrong-tool", "")
        return

    command = (payload.get("tool_input") or {}).get("command") or ""
    reason = decide(command)
    log_decision(reason, command)

    if reason == "allow":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PermissionRequest",
                "decision": {"behavior": "allow"},
            }
        }))


if __name__ == "__main__":
    main()
