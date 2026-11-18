#!/usr/bin/env python3
"""Connect a Yandex Disk rclone remote through your own Yandex OAuth app.

Yandex blocks rclone's built-in OAuth app (every file call returns 410 GoneError),
and an app of the "API access or debugging" type has its redirect URI fixed to
https://oauth.yandex.ru/verification_code, so `rclone config` cannot catch the
login. This script opens the consent page, takes the code Yandex shows, exchanges
it for a token and writes client_id, client_secret and token into the remote.
rclone then refreshes the token through your app on its own.

Usage: ./script/connect_yandex.py [--config PATH] [--remote NAME]
"""
import argparse
import configparser
import datetime
import getpass
import json
import os
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_CONFIG = "~/Library/Application Support/MacYaD/rclone/rclone.conf"


def ask(prompt):
    value = getpass.getpass(prompt + " (input hidden): ").strip()
    if not value:
        raise SystemExit(f"{prompt} is required")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--config", default=DEFAULT_CONFIG, help=f"rclone config file (default: {DEFAULT_CONFIG})")
    parser.add_argument("--remote", default="macyad-yandex", help="remote name (default: macyad-yandex)")
    args = parser.parse_args()
    config_path = os.path.abspath(os.path.expanduser(args.config))

    client_id = ask("ClientID")
    client_secret = ask("Client secret")

    url = "https://oauth.yandex.ru/authorize?" + urllib.parse.urlencode(
        {"response_type": "code", "client_id": client_id, "force_confirm": "yes"})
    subprocess.run(["open", url], check=False)
    print(f"Opened the Yandex consent page. If no browser appeared, open:\n  {url}")
    print("Allow access, then copy the confirmation code Yandex shows. It expires in about 10 minutes.")
    code = ask("Confirmation code")

    body = urllib.parse.urlencode({"grant_type": "authorization_code", "code": code,
                                   "client_id": client_id, "client_secret": client_secret}).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request("https://oauth.yandex.ru/token", data=body), timeout=30) as response:
            token = json.load(response)
    except urllib.error.HTTPError as error:
        try:
            reason = json.loads(error.read()).get("error_description") or ""
        except ValueError:
            reason = ""
        raise SystemExit(f"Yandex refused the code: HTTP {error.code} {reason}\n"
                         "Check ClientID and Client secret, then run again with a fresh code.")
    if not token.get("access_token") or not token.get("refresh_token"):
        raise SystemExit("Yandex returned no refresh token; nothing was written.")

    expiry = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=int(token.get("expires_in", 0)))
    # Read only now, right before writing, so a token rclone refreshed meanwhile is kept.
    config = configparser.RawConfigParser()
    config.optionxform = str  # rclone keys are case-sensitive
    config.read(config_path)
    if not config.has_section(args.remote):
        config.add_section(args.remote)
    section = config[args.remote]
    section["type"] = "yandex"
    section["client_id"] = client_id
    section["client_secret"] = client_secret
    section["token"] = json.dumps({"access_token": token["access_token"], "token_type": "OAuth",
                                   "refresh_token": token["refresh_token"], "expiry": expiry.isoformat()},
                                  separators=(",", ":"))

    # Write a sibling temp file and swap it in: an interrupted write must not wipe the other remotes.
    directory = os.path.dirname(config_path)
    os.makedirs(directory, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(dir=directory, prefix=".rclone.conf.")
    try:
        with os.fdopen(fd, "w") as handle:
            config.write(handle)
        os.replace(temp_path, config_path)
    except BaseException:
        os.unlink(temp_path)
        raise
    print(f"Done: remote '{args.remote}' now uses your app. Check it with:\n"
          f"  rclone --config \"{config_path}\" lsd {args.remote}:/")


if __name__ == "__main__":
    main()
