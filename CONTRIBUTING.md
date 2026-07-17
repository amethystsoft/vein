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

# Contributor License Agreement (CLA)

To keep Vein open and healthy for the ecosystem, contributors must sign a CLA. To respect your contributions, we include a Maintenance Commitment & Fallback Right:

## Why a CLA?

Vein is licensed under the MPL 2.0. To maintain long-term viability and accommodate corporate users whose legal departments cannot work with copyleft licenses, we dual-license Vein. The CLA allows Mia Koring as Amethyst Software to offer alternative commercial licensing terms while keeping the main distribution entirely free and open-source.

## Our Safety Hatch: Maintenance Commitment & Fallback Right

To respect your contributions and protect the community from abandonment, we include a Maintenance Commitment & Fallback Right:

**What we commit to:** We actively maintain Amethyst Vein as the primary maintainer. This means regularly committing code, merging pull requests, closing or resolving issues with explanations, posting reviews or substantive updates, updating documentation—or designating other maintainers to do so on our behalf.

**How it works:** If there is a complete absence of maintenance activity for 6 continuous months, the project is considered unmaintained. We can pause this counter by posting a pinned notice of temporary unavailability (e.g., due to illness or sabbatical) for up to 12 months per year.

**Your protection:** Any contributor can notify us at mia.koring@amethystsoft.de if they suspect maintenance failure. We have 60 days to demonstrate recent maintenance activity or commit to resuming within 14 days. If we don't respond, all contributors automatically gain the right to relicense and redistribute the entire project under any OSI-approved license.

**Want to help?** We are the primary maintainer of Amethyst Vein. If our circumstances change and we need additional designated maintainers, we will consider interested contributors in good faith. Reach out at mia.koring@amethystsoft.de if you'd like to express interest.

### How to Sign
When you open your first Pull Request, CLA assistant will automatically post a comment with instructions to sign the agreement digitally in just a few clicks.

<details>
<summary><b>View Full Fallback Clause</b></summary>

### Maintenance Commitment and Fallback Right

We agree to actively maintain the main distribution of the Amethyst Vein project, regardless of platform or hosting location. The "main distribution" is defined in the project's Contributing.md file; if no such declaration exists, the repository hosted on GitHub under the amethystsoft organization shall be considered the main distribution.

A failure to maintain shall only be triggered if there is a complete absence of maintenance activity by Us or designated maintainers for a continuous period of six (6) months, provided that We have not declared temporary unavailability due to illness, personal emergency, or similar circumstances.

"Maintenance activity" includes at least one of the following actions on the repository within the six-month period:

- Committing code, merging pull requests, or releasing new versions;
- Closing or resolving issues or pull requests with substantive explanations;
- Posting reviews or substantive updates on issues, discussions, or pull requests;
- Updating documentation or project roadmaps.

For the avoidance of doubt:

- We may designate other contributors or maintainers to perform maintenance activities on Our behalf. Designated maintainers shall be publicly listed in a pinned issue. Activity by such designated maintainers shall count as Our maintenance activity.
- The existence of open, unresolved issues or pull requests shall not constitute a failure to maintain, provided We or designated maintainers have engaged in maintenance activities listed above within the preceding six (6) months.
- Repositories explicitly marked as archived, read-only, or in maintenance-freeze status shall not trigger this clause.
- We may declare temporary unavailability (illness, emergency, sabbatical, etc.) by pinning a notice in the repository. During such periods, the six-month clock is paused. This pause shall remain in effect for up to twelve (12) months per calendar year. If a substitute maintainer is designated in such notice, contributors may contact them at the contact information provided.

**Contributor Involvement:**

We are the primary maintainer of Amethyst Vein. If circumstances change such that we require additional designated maintainers (due to workload, availability, or other factors), we will consider interested contributors in good faith. Qualified candidates may reach out at mia.koring@amethystsoft.de to express interest. Accepting a contributor as a designated maintainer constitutes activity under this agreement and demonstrates Our ongoing commitment to maintenance.

**Triggering the Fallback Right:**

Any contributor may provide written notice to Us at mia.koring@amethystsoft.de (or to the substitute contact listed in the temporary unavailability notice, if applicable) reporting suspected maintenance failure. We shall have sixty (60) calendar days from receipt to either: (a) demonstrate maintenance activity within the preceding six months, or (b) commit to resuming maintenance within fourteen (14) days. If neither is satisfied within the specified timeframes, the failure to maintain is automatically confirmed.

Upon confirmation, all contributors automatically acquire a non-exclusive, perpetual, worldwide right to relicense, republish, and distribute the Material (including all Contributions) under any OSI-approved license.
</details>