# Contributing to Vein

Thank you for your interest in contributing to Vein! Please take a moment to review these guidelines before getting started.

## Communication & Language

- **Self-written:** All issues, PR descriptions, discussions and comments must be written by the contributing author. LLM generated text is not permitted.
- **Language:** English or German is preferred. If you do not feel fluent enough, please write in your native language rather than using AI translation.

## Ways to Contribute

### 1. Bug Reports
All bug reports must contain:
- A detailed description of the issue.
- A **minimal reproducible example** (reproducer).

### 2. Feature Requests
- Do not open issues for feature requests. Issues are reserved for actionable tasks. Please open a **Discussion** instead.
- Include a detailed description, the intended use case and proposed API design ideas.

### 3. Code Contributions (Pull Requests)
To prevent maintainer burnout, we limit the scope of accepted PRs:
- **Bug fixes & Documentation:** Always welcome.
- **Feature Expansions:** Only accepted if they target an existing issue labeled both `feature` and `open for everyone`.
- **Linked Issues:** All PRs (except those by the maintainer) must link to an existing issue or reference previous communication with the maintainer.

## Development & Code Style

- **Naming:** Use highly descriptive names for types, functions, and variables. The only exception is simple loop counters (e.g., `for i in range`).
- **Documentation:**
  - All public-facing APIs must contain DocC comments explaining their usage.
  - If internal code is complex you might be asked to add a comment explaining it too.
  - If a new feature warrants a guide, please include a comprehensive DocC tutorial.
- **File Headers:** Every Swift source file must start with the standard header. This is automatically appended by the formatting script.
- **No Attribution:** To keep the codebase clean, do not add your name, initials, or personal copyright notes inside source files. Using your name inside a unit test string you wrote is allowed if you want to leave a little easter egg ;).
- **Test Easter Eggs:** Fun references to pop culture, memes, or games are highly welcome within test targets. Please explain these references in your PR description, and ensure they fully align with our Code of Conduct and don't impact the comprehensiveness of the test negatively.

The required header:
```swift
// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) {Year} Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===
```

## Testing Requirements

All bug fixes and new features must include comprehensive and covering unit tests. These tests must validate your changes and prevent regressions. You can run tests via:
```bash
./Scripts/tsan-test.sh
# SwiftUI
TEST_SWIFTUI=1 ./Scripts/tsan-test.sh
# SwiftCrossUI
TEST_SCUI=1 ./Scripts/tsan-test.sh
```

Before opening the pull request, please also run tests in release mode once:

```bash
./Scripts/tsan-test-release.sh
# SwiftUI
TEST_SWIFTUI=1 ./Scripts/tsan-test-release.sh
# SwiftCrossUI
TEST_SCUI=1 ./Scripts/tsan-test-release.sh
```

We understand that you might not want to set up SwiftCrossUI just for contributing to Vein. If you don't have SwiftCrossUI set up, it's okay to leave that to CI. The same applies should you not own a Mac to test SwiftUI.

## Pull Request Guidelines

To keep the review process manageable and quick, we ask that you follow these practices:

1. **Keep it Focused:** A PR should address exactly one thing.
2. **Explain Your Work:** Provide a natural language description and your reasoning in the PR, written by you. You must fully understand your contributed changes to the point of being able to explain them yourself if asked.
3. **Keep it Small:** If you anticipate a large package of changes, please split your work into multiple smaller PRs. If necessary, we can set up an intermediate development branch to merge your changes step-by-step.
4. **Format & Lint:** Run the formatting script locally before submitting:
   ```bash
   ./Scripts/format_and_lint.sh
   ```

## Contributor License Agreement (CLA)

To keep Vein open and healthy for the ecosystem, contributors must sign a CLA. To respect your contributions, we include a **Maintenance Commitment & Fallback Right**:

### Why a CLA?
Vein is licensed under the MPL 2.0. To maintain long-term viability and accommodate corporate users whose legal departments cannot work with copyleft licenses, we dual-license Vein. The CLA allows Mia Koring as **Amethyst Software** to offer alternative commercial licensing terms while keeping the main distribution entirely free and open-source.

To respect your contributions and protect the community from "licensing rug-pulls," we include a **Maintenance Commitment & Fallback Right** (our Safety Hatch):

> **Summary:** We commit to actively maintaining this project. If an issue or PR is left completely unaddressed for a continuous period of 6 months, Vein is considered unmaintained. In this unlikely event, all contributors immediately gain the right to relicense and redistribute the project under any OSI-approved license.

### How to Sign
When you open your first Pull Request, CLA assistant will automatically post a comment with instructions to sign the agreement digitally in just a few clicks.

<details>
<summary><b>View Full Fallback Clause</b></summary>

### Maintenance Commitment and Fallback Right

We agree to actively maintain the Material. A failure to maintain shall only be triggered if one or more open issues or pull requests remain completely unaddressed by Us for a continuous period of six (6) months.

An issue or pull request is considered "addressed" (and will not trigger a failure to maintain) if We have done any of the following:
- Closed, merged, or resolved it;
- Added a comment, review, or question to it; or
- Applied a label indicating it is under review or awaiting feedback.

If We have requested information or action from a contributor, that issue or pull request cannot trigger a failure to maintain unless the contributor has fully responded and We fail to react for six (6) months following their response.

In the event of a failure to maintain, You and all other contributors shall automatically acquire a non-exclusive, perpetual, worldwide right to relicense, republish, and distribute the Material (including all Contributions) under any license approved by the Open Source Initiative (OSI).
</details>