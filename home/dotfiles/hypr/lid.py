#!/usr/bin/env python3
import os
import subprocess
import json
import sys

os.chdir(os.path.expanduser("~/.config/hypr"))
cachePath = "/tmp/.cache"


def find_integrated_screen(json):
    for j in json:
        if j["name"] == "eDP-1":
            return j


def json_screen_to_string(s):
    return f'{s["name"]},{s["width"]}x{s["height"]}@{s["refreshRate"]},{s["x"]}x{s["y"]},{s["scale"]},transform,{s["transform"]}'


if not len(sys.argv) == 2:
    print("Please provide either open or close param")
    exit(1)

action = sys.argv[1]
if not action == "open" and not action == "close":
    print(f'Please set "open" or "close" not "{action}"')
    exit(1)

if action == "open":
    f = open(cachePath, "r")
    string = f.read()
    f.close()
    os.system(f'hyprctl keyword monitor "{string}"')
elif action == "close":
    raw = subprocess.check_output(["hyprctl", "monitors", "-j"]).decode("utf-8")
    print(raw)
    parsed = json.loads(raw)

    if len(parsed) <= 1:
        #subprocess.check_output(["systemctl", "hibernate"]).decode("utf-8")
        exit(0)

    main = find_integrated_screen(parsed)

    string = json_screen_to_string(main)
    f = open(cachePath, "w")
    f.write(string)
    f.close()
    os.system('hyprctl keyword monitor "eDP-1, disable"')
