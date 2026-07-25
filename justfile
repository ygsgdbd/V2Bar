default:
    @just --list

# Generate the Tuist project and run the complete XCTest suite.
test: check-tuist
    tuist generate --no-open
    xcodebuild test \
        -workspace V2Bar.xcworkspace \
        -scheme V2Bar \
        -destination 'platform=macOS' \
        -skipPackagePluginValidation \
        -skipMacroValidation \
        CODE_SIGN_IDENTITY='' \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO

# Run the checks required by pull requests.
check: test

[private]
check-tuist:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v tuist >/dev/null 2>&1; then
        echo "Tuist is required but is not installed." >&2
        echo "Install it with: brew install tuist" >&2
        exit 1
    fi
