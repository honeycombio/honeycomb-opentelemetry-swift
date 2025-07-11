# Releasing

- Update `honeycombLibraryVersion` in `Sources/Honeycomb/HoneycombVersion.swift`.
- Update `README.md` and `honeycomb-opentelemetry-swift.podspec` with the new version.
- Update `CHANGELOG.md` with the changes since the last release.
- Commit changes, push, and open a release preparation pull request for review.
- Once the pull request is merged, fetch the updated `main` branch.
- Apply a tag for the new version on the merged commit (e.g. `git tag -a 1.2.3 -m "1.2.3"`) The tag **must** be just the version number (ie. should not start with a `v`) in order for Xcode to pick it up
- Push the tag upstream e.g. `git push origin 1.2.3`
- Create a new GitHub release
  - Make sure to "generate release notes" in GitHub for full changelog notes and any new contributors
  - Cross reference the generated notes with the entries in the `CHANGELOG.md`
- Publish the GitHub release.
