# Contributing to Biome.jl

🌱 *Thanks for your interest in contributing!*

Biome.jl welcomes bug reports, feature requests, documentation fixes, and crucially: new **PFT (Plant Functional Type)** definitions for our community-maintained PFT database.

This page explains the different ways you can help, how to open Issues and Pull Requests (PRs), our development workflow, and how to contribute PFTs.

---

## Ways to contribute

- **Report bugs** and propose enhancements via [Issues].
- **Improve documentation** (typos, examples, tutorials).
- **Add or refine tests** to increase reliability.
- **Performance**: profiling and optimizing hot paths.
- **Add PFTs** to our shared **PFT database** (see below).
- **Add new biome schemes** or improve plotting/IO utilities.


---

## Community guidelines

- Be respectful and constructive.
- Prefer public discussions (Issues / PRs) so others can learn too.
- Ask questions: early—maintainers are happy to help with scope and design.

---

## Opening an Issue

Before filing a new [issue](https://github.com/clechartre/Biome.jl/issues), please:

1. **Search existing issues** to avoid duplicates.
2. Include:
   - A clear title and minimal reproducible example (if applicable).
   - Expected vs. actual behavior.
   - Environment details (Julia version, OS, package versions).
   - For performance issues: timing info, data sizes, and a short profile if possible.
---

## Pull Request (PR) workflow

1. **Fork** the repo and create a **feature branch**:
   ```bash
   git checkout -b yourname/short-feature-name
   ````
2. Make focused changes and add tests. Keep PRs small if possible.
3. Run tests locally.
4. Document any new user-facing features in the docs.
5. Open the PR
6. Check the CI status and address review comments.
