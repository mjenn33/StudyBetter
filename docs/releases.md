# Release builds

The release workflow builds Windows and signed Android artifacts on every push
to `main`. Tags beginning with `v` also create a GitHub release and attach the
Windows ZIP, APK and AAB. Windows integration tests must pass before packaging.
The Windows ZIP contains the executable, plugins and data directory together.
Extract the entire ZIP before running StudyBetter.exe.

Pull requests get test builds from the CI workflow: a Windows ZIP and a
debug-signed APK, attached to the run as artifacts for 14 days. They need no
secrets and are not for distribution.

Configure these repository Actions secrets before Android release builds:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded JKS upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: signing key alias.
- `ANDROID_KEY_PASSWORD`: key password.

The workflow decodes the keystore into runner temporary storage and deletes it
even on failure. Signing material never enters source control. Release builds
never fall back to debug signing. Keep an offline backup of your signing key.

Android application ID: `com.studybetter.study_better`. Product name:
StudyBetter on Android and Windows. Increment `app/pubspec.yaml` version/build
number before a store upload. Configure a reachable HTTPS API URL in Settings;
localhost refers to the device itself. Accounts are optional for offline study.
