#!/bin/bash
EXTRA_ARGS="--traits VeinFilter"
if [ -n "$TEST_SCUI" ]; then
  EXTRA_ARGS+=",VeinSCUI"
fi
TSAN_OPTIONS="suppressions=tsan_suppressions.txt" SHOULD_DISABLE_ENCRYPTION=1 swift test --enable-experimental-prebuilts --sanitize=thread $EXTRA_ARGS
