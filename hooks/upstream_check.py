#!/usr/bin/env python3
# Print the newest OpenIndiana hipster release with a published ISO, e.g.
# "202604". Empty output means "nothing detected" and is not an error; a
# non-zero exit means detection itself is broken (network error, HTTP
# error, or a page that no longer matches the expected shape) and must be
# reported by the caller, never swallowed. A failure must NEVER print a
# plausible-but-wrong version -- the version is only printed after every
# step below has succeeded.
#
# Source of truth: https://dlc.openindiana.org/isos/hipster/
# Fetched and confirmed by hand (2026-07-26): the directory is a plain
# autoindex with relative hrefs, one row per line, e.g.
#   <td><a href="./20260430/">20260430/</a></td>
# The directory name is a full 8-digit build date (YYYYMMDD); it is NOT
# the VM_RELEASE form the confs use. The confs (openindiana-202604.conf,
# openindiana-202510.conf) use the 6-digit YYYYMM prefix of that date --
# e.g. dir "20260430" -> VM_RELEASE "202604", dir "20251026" ->
# VM_RELEASE "202510" -- and the ISO itself lives at
# .../hipster/20260430/OI-hipster-text-20260430.iso (the full 8-digit date
# appears in both the path and filename, so this truncation matters only
# for the printed VM_RELEASE, not for locating the image).
# There is also a non-dated "./test/" directory that must never be picked
# up; anchoring on exactly 8 digits excludes it.
#
# Not every dated directory is a release. 20261107/ holds only
# supplemental cloud and Vagrant images; its build-info.json says
# "installation ISOs remain the October 30 snapshot". Reporting it as
# "202611" made watch.py derive .../20261130/OI-hipster-text-20261130.iso,
# which 404s, and the watcher failed every night from 2026-11-07. So the
# directories are walked newest first and the first one whose own listing
# links its text ISO (checked 2026-11-09: href="./OI-hipster-text-
# 20261030.iso" in 20261030/) is the release.
#
# stdlib only (urllib.request, re, sys, os) -- no external dependencies.

import os
import re
import sys
import urllib.request

URL = "https://dlc.openindiana.org/isos/hipster/"
TIMEOUT = 60
USER_AGENT = "anyvm-org-upstream-watcher/1.0"

PATTERN = re.compile(r'href="\./(\d{8})/"')


def resolve_natural_key():
    """Return the engine's own natural_key, or fail loudly.

    watch.yml clones base-builder INTO the builder repo root, so at
    detection time it sits at "base-builder/" (relative to this hook's
    cwd, the builder repo root). A local checkout instead has it as a
    sibling, "../base-builder". Try both, in that order.

    There is deliberately NO local fallback copy. Ordering must be the
    single rule the engine uses -- a per-hook duplicate would have to be
    kept in sync by hand across every builder and would drift silently,
    and a hook that ranks versions differently from watch.py is worse
    than one that refuses to run. Both real contexts (CI and a local
    sibling checkout) always provide base-builder, so an ImportError here
    means the environment is wrong: report it as broken detection rather
    than guessing an order.
    """
    for candidate in ("base-builder", os.path.join("..", "base-builder")):
        if not os.path.isdir(candidate):
            continue
        path = os.path.abspath(candidate)
        if path not in sys.path:
            sys.path.insert(0, path)
        try:
            import gendata
            return gendata.natural_key
        except ImportError:
            continue
    raise ImportError(
        "base-builder/gendata.py not importable from %s; expected it at "
        "./base-builder (CI) or ../base-builder (local checkout)"
        % os.getcwd())


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", "replace")


def main():
    try:
        key = resolve_natural_key()
    except ImportError as e:
        sys.stderr.write("upstream_check: %s\n" % e)
        return 1
    try:
        html = fetch(URL)
    except Exception as e:
        sys.stderr.write("upstream_check: fetch of %s failed: %s\n"
                         % (URL, e))
        return 1
    dates = PATTERN.findall(html)
    if not dates:
        sys.stderr.write("upstream_check: no YYYYMMDD directory found in "
                         "%s; page shape may have changed\n" % URL)
        return 1
    for date in sorted(set(dates), key=key, reverse=True):
        dir_url = "%s%s/" % (URL, date)
        try:
            listing = fetch(dir_url)
        except Exception as e:
            sys.stderr.write("upstream_check: fetch of %s failed: %s\n"
                             % (dir_url, e))
            return 1
        if 'href="./OI-hipster-text-%s.iso"' % date in listing:
            print(date[:6])
            return 0
    sys.stderr.write("upstream_check: no directory under %s links an "
                     "OI-hipster-text-<date>.iso; page shape may have "
                     "changed\n" % URL)
    return 1


if __name__ == "__main__":
    sys.exit(main())
