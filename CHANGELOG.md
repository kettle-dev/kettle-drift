# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Prevented the Rakefile template hook from adding a second trailing newline
  when refreshing the kettle-drift task block.
- Inserted the kettle-drift Rakefile task block after the complete guarded
  `kettle-dev` block so templating does not corrupt destination Rakefiles.

### Security

## [1.0.0] - 2026-05-24

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 81.57% -- 394/483 lines in 13 files
- BRANCH COVERAGE: 60.11% -- 107/178 branches in 13 files
- 30.93% documented

### Added

- Initial release

[Unreleased]: https://github.com/kettle-rb/kettle-drift/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kettle-rb/kettle-drift/compare/bd038cd14dc083203b58f8fee359e63d6feeaaca...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/kettle-drift/releases/tag/v1.0.0
