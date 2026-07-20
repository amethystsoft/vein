#!/bin/bash
EXTRA_ARGS=""
if [ -n "$TEST_SCUI" ]; then
  EXTRA_ARGS="--traits VeinSCUI"
fi
TSAN_OPTIONS="suppressions=tsan_suppressions.txt" SHOULD_DISABLE_ENCRYPTION=1 swift test --enable-experimental-prebuilts --sanitize=thread -c release $EXTRA_ARGS
