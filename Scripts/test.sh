#!/bin/bash
EXTRA_ARGS="--traits VeinFilter"
if [ -n "$TEST_SCUI" ]; then
  EXTRA_ARGS+=",VeinSCUI"
fi
SHOULD_DISABLE_ENCRYPTION=1 swift test --enable-experimental-prebuilts $EXTRA_ARGS
