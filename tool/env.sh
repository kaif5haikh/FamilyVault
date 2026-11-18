#!/usr/bin/env bash
# Source from any working directory. All writable SDK/build caches stay in this repo.
FAMILYVAULT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export FAMILYVAULT_ROOT
export PUB_CACHE="$FAMILYVAULT_ROOT/.cache/pub"
export GRADLE_USER_HOME="$FAMILYVAULT_ROOT/.cache/gradle"
export ANDROID_HOME="$FAMILYVAULT_ROOT/.tools/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$FAMILYVAULT_ROOT/.cache/android"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$FAMILYVAULT_ROOT/.cache/android/avd"
# Keep this project's ADB daemon separate from an existing user daemon.
export ANDROID_ADB_SERVER_PORT=5039
export ADB_SERVER_SOCKET=tcp:localhost:5039
export TMPDIR="$FAMILYVAULT_ROOT/.cache/tmp"
mkdir -p "$TMPDIR"
export XDG_CACHE_HOME="$FAMILYVAULT_ROOT/.cache/xdg"
export XDG_CONFIG_HOME="$FAMILYVAULT_ROOT/.cache/config"
export FLUTTER_CONFIG_DIR="$FAMILYVAULT_ROOT/.cache/flutter-config"
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
export DENO_DIR="$FAMILYVAULT_ROOT/.cache/deno"
export CI=true
for familyvault_jdk in "$FAMILYVAULT_ROOT"/.tools/jdk-21*; do
  if [[ -x "$familyvault_jdk/bin/javac" ]]; then
    export JAVA_HOME="$familyvault_jdk"
    break
  fi
done
unset familyvault_jdk
export PATH="$FAMILYVAULT_ROOT/.tools/flutter/bin:${JAVA_HOME:+$JAVA_HOME/bin:}$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
for familyvault_deno in "$FAMILYVAULT_ROOT"/.tools/deno-*; do
  if [[ -x "$familyvault_deno/deno" ]]; then
    export PATH="$familyvault_deno:$PATH"
    break
  fi
done
unset familyvault_deno
# The PDF native-asset hook also compiles a small host library during tests.
if [[ "$(uname -sm)" = 'Linux x86_64' ]] && ! command -v clang >/dev/null; then
  for familyvault_llvm in "$ANDROID_HOME"/ndk/*/toolchains/llvm/prebuilt/linux-x86_64/bin; do
    if [[ -x "$familyvault_llvm/clang" ]]; then
      export PATH="$PATH:$familyvault_llvm"
      break
    fi
  done
  unset familyvault_llvm
fi
