#!/bin/sh
echo -ne '\033c\033]0;Plane With Legs\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/pwl.x86_64" "$@"
