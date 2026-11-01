# Zenvora Android project

This is a Flutter Android shell that opens the supplied customer HTML storefront and admin HTML panel in Android WebView. The HTML files are kept as local assets so their existing HTML/CSS/JS design is retained rather than redrawn in Flutter.

## Build APK through GitHub Actions
1. Create a new GitHub repository and upload the contents of this folder (not the parent folder).
2. Open **Settings → Actions → General** and allow workflows if required.
3. Push to the `main` branch, or open **Actions → Build Android APK → Run workflow**.
4. Open the completed workflow run and download the `zenvora-release-apk` artifact. Extract the ZIP to get `app-release.apk`.

## Supabase configuration
Edit `assets/web/config.js` and set `supabaseUrl` and `supabaseAnonKey` to your Supabase project URL and anon/public key. Do not use a service-role key in a mobile app. Commit and run the workflow again.

## Important integration note
The uploaded Dart files (`core.dart`, `services.dart`, `state.dart`, `ui.dart`) are included in `lib/` as supplied, but the uploaded set did not include their matching `config.dart`, `data.dart`, or a Dart entry point. This project uses the original HTML pages in WebView as the working UI, so those incomplete Dart modules are not imported by `main.dart`.

The HTML pages reference `config.js`; a safe empty template is provided. Until Supabase credentials are configured, cloud-backed features will not connect. Admin panel is opened from the shield/admin icon in the app bar. Customer/admin share the same WebView local storage origin only if the WebView asset origin supports it on the target WebView; verify persistence on device.
