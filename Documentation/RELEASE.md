## Release Process

To bump up package version, please follow the below steps:

1. Bump version in `Sources/CartonHelpers/Version.swift`
2. Update `CHANGELOG.md`
3. `git commit`
4. `git tag <version>`
5. `git push origin <version>`
6. Create a new GitHub Release
