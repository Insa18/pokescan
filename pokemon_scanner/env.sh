#!/usr/bin/env bash
# Source ce fichier pour avoir Flutter + Android SDK + JDK dans le PATH :
#   source env.sh
export JAVA_HOME="$HOME/jdk"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$HOME/.local/bin:$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
echo "Env prêt : flutter $(flutter --version 2>/dev/null | head -1)"
