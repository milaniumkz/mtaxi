#!/usr/bin/env bash
set -euo pipefail
umask 077
incoming_dir="${1:?Specify the completed private upload directory}"
downloads_dir="${2:?Specify the public downloads directory}"
install -d -m 755 "$downloads_dir"
exec 9>"$downloads_dir/.publish.lock"
flock -w 300 9
read -r expected_sha _ < "$incoming_dir/mtaxi-staging.apk.sha256"
[[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]]
actual_sha="$(sha256sum "$incoming_dir/mtaxi-staging.apk")"
[[ "${actual_sha%% *}" == "$expected_sha" ]]
apk_tmp="$(mktemp "$downloads_dir/.apk-upload.XXXXXX")"
checksum_tmp="$(mktemp "$downloads_dir/.apk-checksum.XXXXXX")"
metadata_tmp="$(mktemp "$downloads_dir/.apk-metadata.XXXXXX")"
trap 'rm -f -- "$apk_tmp" "$checksum_tmp" "$metadata_tmp"' EXIT
install -m 644 "$incoming_dir/mtaxi-staging.apk" "$apk_tmp"
install -m 644 "$incoming_dir/mtaxi-staging.apk.sha256" "$checksum_tmp"
install -m 644 "$incoming_dir/test-build.json" "$metadata_tmp"
actual_sha="$(sha256sum "$apk_tmp")"
[[ "${actual_sha%% *}" == "$expected_sha" ]]
# Each rename is on the destination filesystem. Publish metadata last.
mv -f -- "$apk_tmp" "$downloads_dir/mtaxi-staging.apk"
mv -f -- "$checksum_tmp" "$downloads_dir/mtaxi-staging.apk.sha256"
mv -f -- "$metadata_tmp" "$downloads_dir/test-build.json"
printf 'APK published atomically; SHA256 %s\n' "$expected_sha"
