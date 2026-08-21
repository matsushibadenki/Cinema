# Software Updates

Cinema uses [Sparkle](https://sparkle-project.org/) to check the signed update feed automatically and install a new version when one is available. The application menu also provides **Check for Software Updates...**.

## Release requirements

- Build, sign, notarize, and staple a release with `CODE_SIGN_IDENTITY="Developer ID Application: <name> (<team-id>)" script/notarize_release.sh <version>`. The default development build uses an ad-hoc signature only.
- Increase `CFBundleShortVersionString` and `CFBundleVersion` in `Sources/Cinema/Resources/Info.plist` for every release.
- Archive the signed `Cinema.app` as `Cinema-<version>.zip` using `ditto -c -k --sequesterRsrc --keepParent`.
- Place the archive in `releases/`, then run `DOWNLOAD_URL_PREFIX=https://github.com/matsushibadenki/Cinema/releases/download/v<version>/ script/create_update_feed.sh releases` on the Mac that owns Cinema's Sparkle private key.
- Commit the generated `appcast.xml`, create the matching GitHub Release, and attach the `.zip` archive.

`generate_appcast` reads the private EdDSA key from the login Keychain. The private key must never be committed or included in the app. The public key embedded in the app verifies every update.

## First public release

The first public release cannot update an older build that did not include Sparkle. Once a Sparkle-enabled Cinema version is installed, later signed releases are detected and installed automatically.

## GitHub Actions

The release feed can be published from GitHub Actions once a separate release signing workflow is configured. That workflow needs the Developer ID certificate, notarization credentials, and Sparkle private key stored as GitHub Actions secrets. Do not add any of those values to this repository.
