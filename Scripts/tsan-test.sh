#!/bin/bash
TSAN_OPTIONS="suppressions=tsan_suppressions.txt" SHOULD_DISABLE_ENCRYPTION=1 swift test --enable-experimental-prebuilts --sanitize=thread
