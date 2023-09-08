# FireStorage

A description of this package.

# Changleog
All notable changes to this project will be documented in this section.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [v0.0.2] - 2023.09.08

### Added
- File caching has been integrated into the Firestore implementation. This integration automatically caches the data pulled down from the Firestore database to the device. To properly integrate caching into your app, you must add a "public" collection to your Firestore database that has a single document. When the database is updated, the "lastUpdate" property on this document should be updated to a new Timestamp object. This will cause a fetch to happen.

## [v0.0.1] - 2023.08.03

### Added
- Initial implementation
