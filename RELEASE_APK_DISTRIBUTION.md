# Release APK (Website Distribution)

This project can be distributed **outside Google Play** by uploading a **signed release APK** to your website.

## 1) Understand the limits (important)

- Google Play does **not** need to scan your APK if you’re not publishing on Play.
- Android will still protect users:
  - Users must allow **“Install unknown apps”** for the browser/file-manager they used to download the APK (Android 8+).
  - **Play Protect** may still scan/warn after download. You cannot fully disable this for all users.

The best way to reduce scary warnings is to ship a **properly signed release APK** over **HTTPS**.

## 2) Create a release keystore (one-time)

From the repo root, run (example):

```powershell
keytool -genkeypair -v `
  -keystore Flutter_Frontend\android\upload-keystore.jks -storetype JKS `
  -alias upload -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass YOUR_PASSWORD -keypass YOUR_PASSWORD `
  -dname "CN=Catuc Portal, OU=IT, O=CATUC, L=Yaounde, ST=Centre, C=CM"
```

Notes:
- Keep the `.jks` file **private**. If you lose it, you can’t ship updates that install over the old app.
- The keystore is ignored by Git (`Flutter_Frontend/android/.gitignore`).

## 3) Configure `android/key.properties`

Create `Flutter_Frontend/android/key.properties`:

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

## 4) Build a signed release APK

```powershell
cd Flutter_Frontend
flutter build apk --release
```

Output:

`Flutter_Frontend/build/app/outputs/flutter-apk/app-release.apk`

Optional (smaller downloads):

```powershell
flutter build apk --release --split-per-abi
```

## 5) Upload to your website (recommended setup)

- Use **HTTPS**
- Keep the filename simple, e.g. `catuc-portal.apk`
- Serve it with the correct content-type:
  - `application/vnd.android.package-archive`

## 6) User install steps (what to tell users)

1. Download the APK from your website.
2. Open it.
3. If prompted, enable **Install unknown apps** for the app they used (Chrome / Files).
4. Tap **Install**.

