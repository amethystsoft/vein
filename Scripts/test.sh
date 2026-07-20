#!/bin/bash
EXTRA_ARGS=""
if [ -n "$TEST_SCUI" ]; then
  EXTRA_ARGS="--traits VeinSCUI"
fi
SHOULD_DISABLE_ENCRYPTION=1 swift test --enable-experimental-prebuilts $EXTRA_ARGS
