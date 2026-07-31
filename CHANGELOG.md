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

- kettle-jem-template-20260729-005 - Gemspec metadata now publishes this
  project's RubyForum tag as `mailing_list_uri`, and support docs link to the
  tagged RubyForum community alongside Discord.

### Changed

### Deprecated

### Removed

### Fixed

- kettle-jem-template-20260728-004 - Generated dep-heads workflows now use the
  setup-ruby Bundler install path for direct appraisal Gemfiles, avoiding rv
  lockfile parser failures on Git and path dependencies.
- kettle-jem-template-20260728-005 - VersionGem bootstrap now creates the
  missing canonical version spec when a project only has shim namespace version
  specs.
- kettle-jem-template-20260729-001 - Generated JRuby 9.4 workflows now use the
  legacy manual bundle install path, avoiding setup-time Bundler full-index
  failures against `gem.coop`.
- kettle-jem-template-20260729-002 - VersionGem bootstrap now preserves
  and templates dedicated `version_gem.rb` entrypoints even when the gemspec
  dependency is intentionally omitted, and generated anonymous-loader specs
  cover both `version.rb` and `version_gem.rb`.
- kettle-jem-template-20260729-003 - Old-Ruby gems below the VersionGem runtime
  floor now get managed minimal `version.rb` files and anonymous-loader version
  specs without adding `version_gem`.
- kettle-jem-template-20260730-001 - Gemspec package file enumeration now runs
  relative to the gemspec directory, so release package contents stay correct
  even when the gemspec is loaded from another working directory.

### Security

## [1.0.8] - 2026-07-28

- TAG: [v1.0.8][1.0.8t]
- COVERAGE: 81.02% -- 427/527 lines in 14 files
- BRANCH COVERAGE: 65.84% -- 133/202 branches in 14 files
- 34.95% documented

### Added

- kettle-jem-template-20260726-001 - Projects now include YARD lint
  configuration and documentation dependencies so documentation issues fail
  before generated docs are refreshed.

- kettle-jem-template-20260727-001 - Spec harness documentation now lists the
  RSpec helpers provided by `kettle-test`.

### Changed

- The `kettle-drift` executable startup header is now shown only when
  `--verbose` is passed; `-v` and `--version` still print just the executable
  version and exit.

- kettle-jem-template-20260725-002 - Version specs now use `anonymous_loader` to
  cover `version.rb` without redefining constants, or are removed when version
  specs are not managed for the project.

- kettle-jem-template-20260728-001 - Generated Ruby workflows now use clearer
  setup-ruby-flash planning and can prepare appraisal-only jobs without
  installing the main Gemfile bundle.

### Fixed

- kettle-jem-template-20260726-002 - Generated version files now document their
  version namespace and constants, reducing warning-only YARD lint output.

- kettle-jem-template-20260726-003 - Coverage upload steps now treat Coveralls,
  QLTY, and Codecov as optional, so provider outages do not fail CI when local
  coverage thresholds still pass.
- kettle-jem-template-20260728-002 - Generated RuboCop configs now ignore the
  same `gemfiles/vendor/bundle` tree as `.gitignore`, so vendored dependency
  installs are not reported as project lint debt.
- kettle-jem-template-20260728-003 - Generated dep-heads workflows now run
  TruffleRuby jobs with current RubyGems and Bundler, avoiding setup failures
  before the test suite starts.

## [1.0.7] - 2026-07-25

- TAG: [v1.0.7][1.0.7t]
- COVERAGE: 81.02% -- 427/527 lines in 14 files
- BRANCH COVERAGE: 65.84% -- 133/202 branches in 14 files
- 33.01% documented

### Changed

- The `kettle-drift` executable now supports `-v` / `--version` and prints a
  standard startup header on normal runs.

- kettle-jem-template-20260725-001 - Generated JRuby and TruffleRuby workflow
  files now run when pull request head branches start with `feature/release`,
  so release CI monitoring does not report intentionally skipped engine
  workflows as failures.

### Fixed

- The `kettle-drift` executable now uses normal `require` loading for its version
  file, avoiding `require_relative` lint drift in shipped executables.

## [1.0.6] - 2026-07-21

- TAG: [v1.0.6][1.0.6t]
- COVERAGE: 81.02% -- 427/527 lines in 14 files
- BRANCH COVERAGE: 65.84% -- 133/202 branches in 14 files
- 33.01% documented

### Changed

- kettle-jem-template-20260716-001 - Shim gemspec manifests now include
  `LICENSE.md` instead of nonexistent `LICENSE.txt`.
- kettle-jem-template-20260716-002 - Generated gemspec manifests now ship fewer
  repository-only files by default to reduce downstream distro packaging churn.

- kettle-jem-template-20260720-001 - Generated READMEs can now render
  template-managed corporate sponsor logos from project or family config.
- kettle-jem-template-20260720-002 - Generated development Gemfiles now use the
  released `tree_sitter_language_pack` gem 1.13.3 or newer by default.
- kettle-jem-template-20260720-003 - Generated StructuredMerge Git diff driver
  config now uses the installed `smorg-rb` Ruby driver name.
- kettle-jem-template-20260720-004 - Generated multi-engine workflow files now
  omit JRuby and TruffleRuby jobs when project config declares MRI-only engines.
- kettle-jem-template-20260720-005 - Generated README Support & Community rows
  now include a RubyForum help badge.

## [1.0.5] - 2026-07-01

- TAG: [v1.0.5][1.0.5t]
- COVERAGE: 81.02% -- 427/527 lines in 14 files
- BRANCH COVERAGE: 63.94% -- 133/208 branches in 14 files
- 33.01% documented

### Fixed

- Package configured license files in gem release file lists.
- Corrected the generated stdlib modular Gemfile selector so Ruby 3.1 uses the
  existing Ruby 3 stdlib bundle instead of a missing `r3.1` file.

## [1.0.4] - 2026-06-22

- TAG: [v1.0.4][1.0.4t]
- COVERAGE: 81.02% -- 427/527 lines in 14 files
- BRANCH COVERAGE: 63.94% -- 133/208 branches in 14 files
- 33.01% documented

### Added

- Added support for JRuby 10.1 and TruffleRuby 34.0.

### Changed

- Retemplated project metadata and CI/development automation with `kettle-jem` v7.0.0.

### Fixed

- Corrected RubyGems homepage metadata to point at the gem documentation site.
- Corrected persisted Open Collective metadata to use the `kettle-dev`
  collective.

## [1.0.3] - 2026-06-10

- TAG: [v1.0.3][1.0.3t]
- COVERAGE: 83.89% -- 427/509 lines in 13 files
- BRANCH COVERAGE: 65.84% -- 133/202 branches in 13 files
- 33.01% documented

### Fixed

- Updated generated project metadata links to use the migrated `kettle-dev`
  GitHub organization.
- Restored `docs/CNAME` so the generated documentation site keeps its custom domain.

## [1.0.2] - 2026-06-03

- TAG: [v1.0.2][1.0.2t]
- COVERAGE: 83.98% -- 430/512 lines in 13 files
- BRANCH COVERAGE: 65.84% -- 133/202 branches in 13 files
- 33.01% documented

### Fixed

- Suppressed warning/report output when current duplicate drift exactly matches
  the checked-in lockfile baseline.

## [1.0.1] - 2026-05-28

- TAG: [v1.0.1][1.0.1t]
- COVERAGE: 84.12% -- 429/510 lines in 13 files
- BRANCH COVERAGE: 65.84% -- 133/202 branches in 13 files
- 32.35% documented

### Fixed

- Prevented the Rakefile template hook from adding a second trailing newline
  when refreshing the kettle-drift task block.
- Inserted the kettle-drift Rakefile task block after the complete guarded
  `kettle-dev` block so templating does not corrupt destination Rakefiles.

## [1.0.0] - 2026-05-24

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 81.57% -- 394/483 lines in 13 files
- BRANCH COVERAGE: 60.11% -- 107/178 branches in 13 files
- 30.93% documented

### Added

- Initial release

[Unreleased]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.8...HEAD
[1.0.8]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.7...v1.0.8
[1.0.8t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.8
[1.0.7]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.6...v1.0.7
[1.0.7t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.7
[1.0.6]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.5...v1.0.6
[1.0.6t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.6
[1.0.5]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.4...v1.0.5
[1.0.5t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.5
[1.0.4]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.3...v1.0.4
[1.0.4t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.4
[1.0.3]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.2...v1.0.3
[1.0.3t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.3
[1.0.2]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.1...v1.0.2
[1.0.2t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.2
[1.0.1]: https://github.com/kettle-dev/kettle-drift/compare/v1.0.0...v1.0.1
[1.0.1t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.1
[1.0.0]: https://github.com/kettle-dev/kettle-drift/compare/bd038cd14dc083203b58f8fee359e63d6feeaaca...v1.0.0
[1.0.0t]: https://github.com/kettle-dev/kettle-drift/releases/tag/v1.0.0
