# Temptations

Flutter Android app with maroon/white branding and Auth0 passwordless SMS OTP.

## Auth0 SMS OTP

This project has the current Auth0 Native Application values configured in
`lib/main.dart`. You can still override them at run time:

```powershell
flutter run --dart-define=AUTH0_DOMAIN=your-tenant.auth0.com --dart-define=AUTH0_CLIENT_ID=your_native_app_client_id
```

Auth0 Dashboard requirements:

- Enable the Passwordless SMS connection.
- Enable the connection for your Native Application.
- Enable the `http://auth0.com/oauth/grant-type/passwordless/otp` grant type for the application.
- Configure a phone provider such as Twilio or a custom phone provider.

## Stream Chat

The app uses the official `stream_chat_flutter` SDK. The current Stream API key is
configured in `lib/main.dart`. You can still override it when running the app:

```powershell
flutter run --dart-define=STREAM_API_KEY=your_stream_api_key
```

For local development with no backend token service, enable **Disable Auth Checks**
in the Stream dashboard and the app will use `client.devToken(userId)`. For
production, generate user tokens on your backend and pass one with:

```powershell
flutter run --dart-define=STREAM_API_KEY=your_stream_api_key --dart-define=STREAM_USER_TOKEN=server_generated_user_token
```

Never put the Stream secret key in the Flutter app. It belongs only on a backend
that generates user tokens.

## Firebase Memes

The `/meme` chat command reads meme stickers from Firestore collection `memes`.
Each document should use this shape:

```json
{
  "title": "Laugh",
  "stickerUrl": "https://.../laugh.webp",
  "audioUrl": "https://.../laugh.mp3",
  "enabled": true
}
```

Put the sticker and audio files in Firebase Storage, copy their download URLs,
and save those URLs in Firestore. Add Android Firebase config with
`android/app/google-services.json`. The Android Google Services Gradle plugin is
already wired in this project, so the app will not build until that file is
present after enabling Firebase. Then run:

```powershell
flutter pub get
flutter run
```

To prepare a meme sticker with transparent background through remove.bg and
upload both sticker/audio to Firebase Storage:

```powershell
$env:REMOVE_BG_API_KEY='your_remove_bg_api_key'
.\tools\upload_meme.ps1 -Title "Laugh" -StickerPath "C:\memes\laugh.jpg" -AudioPath "C:\memes\laugh.mp3"
```

The script outputs a JSON file. Create a Firestore document in collection
`memes` using that JSON. The sticker and audio URLs are sent together when a
user picks the meme through `/meme`.
