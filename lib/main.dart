import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as audio_record;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TemptationsApp());
}

class TemptationsApp extends StatelessWidget {
  const TemptationsApp({super.key});

  static const Color maroon = Color(0xFF6E1228);
  static const Color deepMaroon = Color(0xFF3B0716);
  static const Color ivory = Color(0xFFFFFBF8);
  static const Color champagne = Color(0xFFF7E6D6);
  static const Color ink = Color(0xFF241317);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: maroon,
      brightness: Brightness.light,
      primary: maroon,
      secondary: const Color(0xFFB9824D),
      surface: ivory,
      onSurface: ink,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Temptations',
      builder: (context, child) {
        return stream.StreamChatTheme(
          data: stream.StreamChatThemeData.fromTheme(Theme.of(context)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: ivory,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          foregroundColor: ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE7D4C8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE7D4C8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: maroon, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: maroon,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      home: const TemptationsHome(),
    );
  }
}

class TemptationsHome extends StatefulWidget {
  const TemptationsHome({super.key});

  @override
  State<TemptationsHome> createState() => _TemptationsHomeState();
}

class _TemptationsHomeState extends State<TemptationsHome> {
  bool _signedIn = false;
  AppUser? _currentUser;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreUser();
  }

  Future<void> _restoreUser() async {
    final user = await LocalSessionStore.loadUser();
    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _signedIn = user != null;
      _restoring = false;
    });
  }

  Future<void> _enterApp(AppUser user) async {
    await LocalSessionStore.saveUser(user);
    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _signedIn = true;
    });
  }

  Future<void> _signOut() async {
    await LocalSessionStore.clear();
    if (!mounted) return;

    setState(() {
      _currentUser = null;
      _signedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: TemptationsApp.maroon),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _signedIn
          ? SignedInExperience(
              key: const ValueKey('signed-in'),
              user: _currentUser ?? AppUser.guest(),
              onSignOut: _signOut,
            )
          : LandingScreen(key: const ValueKey('landing'), onContinue: _enterApp),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.onContinue});

  final ValueChanged<AppUser> onContinue;

  @override
  Widget build(BuildContext context) {
    return _LandingFlow(onContinue: onContinue);
  }
}

enum AuthIntent { signUp, signIn }

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.idToken,
    required this.tokenType,
    required this.expiresIn,
    this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      idToken: json['id_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      refreshToken: json['refresh_token'] as String?,
    );
  }

  final String accessToken;
  final String idToken;
  final String tokenType;
  final int expiresIn;
  final String? refreshToken;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.username,
    this.phoneNumber,
    this.auth0Subject,
    this.isGuest = false,
  });

  factory AppUser.guest() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return AppUser(
      id: 'guest_$timestamp',
      displayName: 'Guest',
      isGuest: true,
    );
  }

  factory AppUser.fromJson(Map<String, Object?> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Temptations User',
      username: json['username'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      auth0Subject: json['auth0Subject'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  factory AppUser.fromAuth({
    required AuthSession session,
    required String phoneNumber,
    String? username,
    String? displayName,
  }) {
    final claims = _decodeJwtPayload(session.idToken);
    final subject = claims['sub'] as String?;
    final trimmedUsername = username?.trim();
    final fallbackId = trimmedUsername?.isNotEmpty == true
        ? trimmedUsername!
        : subject ?? phoneNumber;

    return AppUser(
      id: _sanitizeStreamUserId(fallbackId),
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : trimmedUsername?.isNotEmpty == true
              ? trimmedUsername!
              : 'Temptations User',
      username: trimmedUsername?.isEmpty == true ? null : trimmedUsername,
      phoneNumber: phoneNumber,
      auth0Subject: subject,
    );
  }

  final String id;
  final String displayName;
  final String? username;
  final String? phoneNumber;
  final String? auth0Subject;
  final bool isGuest;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'phoneNumber': phoneNumber,
      'auth0Subject': auth0Subject,
      'isGuest': isGuest,
    };
  }
}

class LocalSessionStore {
  static const _userKey = 'temptations_user';

  static Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<AppUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_userKey);
    if (rawUser == null || rawUser.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawUser) as Map<String, dynamic>;
      final user = AppUser.fromJson(decoded);
      if (user.id.isEmpty) return null;

      return user;
    } catch (_) {
      await prefs.remove(_userKey);
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}

Map<String, dynamic> _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return {};

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));

    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

String _sanitizeStreamUserId(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9@_\-=.]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  if (sanitized.isEmpty) {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  return sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
}

class Auth0Config {
  static const domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'dev-82360je2mhru6r5g.us.auth0.com',
  );
  static const clientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'C2VwE85hpREb1N5ZaWUsNyn0PRvgP5tM',
  );

  static bool get isConfigured => domain.isNotEmpty && clientId.isNotEmpty;
}

class StreamConfig {
  static const apiKey = String.fromEnvironment(
    'STREAM_API_KEY',
    defaultValue: 'gzz768b4bqtu',
  );
  static const userToken = String.fromEnvironment('STREAM_USER_TOKEN');

  static bool get isConfigured => apiKey.isNotEmpty;
}

class Auth0Exception implements Exception {
  const Auth0Exception(this.message);

  final String message;

  @override
  String toString() => message;
}

class Auth0PasswordlessClient {
  const Auth0PasswordlessClient();

  Uri _endpoint(String path) {
    final normalizedDomain = Auth0Config.domain.replaceFirst(
      RegExp(r'^https?://'),
      '',
    );

    return Uri.https(normalizedDomain, path);
  }

  Future<void> sendSmsCode(String phoneNumber) async {
    _ensureConfigured();

    await _post(
      _endpoint('/passwordless/start'),
      {
        'client_id': Auth0Config.clientId,
        'connection': 'sms',
        'phone_number': phoneNumber,
        'send': 'code',
        'authParams': {
          'scope': 'openid profile email offline_access',
        },
      },
    );
  }

  Future<AuthSession> verifySmsCode({
    required String phoneNumber,
    required String code,
  }) async {
    _ensureConfigured();

    final response = await _post(
      _endpoint('/oauth/token'),
      {
        'grant_type': 'http://auth0.com/oauth/grant-type/passwordless/otp',
        'client_id': Auth0Config.clientId,
        'username': phoneNumber,
        'otp': code,
        'realm': 'sms',
        'scope': 'openid profile email offline_access',
      },
    );

    return AuthSession.fromJson(response);
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            decoded['error_description'] as String? ??
            decoded['message'] as String? ??
            decoded['error'] as String? ??
            'Auth0 request failed. Please try again.';
        throw Auth0Exception(message);
      }

      return decoded;
    } on SocketException {
      throw const Auth0Exception('Network unavailable. Check your connection.');
    } on TimeoutException {
      throw const Auth0Exception('Auth0 took too long to respond.');
    } finally {
      client.close(force: true);
    }
  }

  void _ensureConfigured() {
    if (!Auth0Config.isConfigured) {
      throw const Auth0Exception(
        'Auth0 is not configured. Run with AUTH0_DOMAIN and AUTH0_CLIENT_ID.',
      );
    }
  }
}

class _LandingFlow extends StatefulWidget {
  const _LandingFlow({required this.onContinue});

  final ValueChanged<AppUser> onContinue;

  @override
  State<_LandingFlow> createState() => _LandingFlowState();
}

class _LandingFlowState extends State<_LandingFlow> {
  AuthIntent? _intent;

  void _selectIntent(AuthIntent intent) {
    setState(() => _intent = intent);
  }

  void _goBack() {
    setState(() => _intent = null);
  }

  @override
  Widget build(BuildContext context) {
    final intent = _intent;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 46).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: intent == null
                          ? EntryFrame(
                              key: const ValueKey('entry'),
                              isWide: isWide,
                              onSignUp: () => _selectIntent(AuthIntent.signUp),
                              onSignIn: () => _selectIntent(AuthIntent.signIn),
                            )
                          : FormFrame(
                              key: ValueKey(intent),
                              isWide: isWide,
                              intent: intent,
                              onBack: _goBack,
                              onContinue: widget.onContinue,
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EntryFrame extends StatelessWidget {
  const EntryFrame({
    super.key,
    required this.isWide,
    required this.onSignUp,
    required this.onSignIn,
  });

  final bool isWide;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: BrandPanel()),
          const SizedBox(width: 36),
          Expanded(child: WelcomePanel(onSignUp: onSignUp, onSignIn: onSignIn)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BrandPanel(),
        const SizedBox(height: 24),
        WelcomePanel(onSignUp: onSignUp, onSignIn: onSignIn),
      ],
    );
  }
}

class FormFrame extends StatelessWidget {
  const FormFrame({
    super.key,
    required this.isWide,
    required this.intent,
    required this.onBack,
    required this.onContinue,
  });

  final bool isWide;
  final AuthIntent intent;
  final VoidCallback onBack;
  final ValueChanged<AppUser> onContinue;

  @override
  Widget build(BuildContext context) {
    final form = LoginPanel(
      intent: intent,
      onBack: onBack,
      onContinue: onContinue,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: form,
      ),
    );
  }
}

class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TemptationsApp.deepMaroon,
            TemptationsApp.maroon,
            Color(0xFF9C243E),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x336E1228),
            blurRadius: 36,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const _AppLogo(height: 84, width: 108),
              const SizedBox(width: 14),
              const Text(
                'Temptations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 42),
          const Text(
            'Premium private chat, designed for real connection.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Phone-first sign in, verified profiles, and a calm messaging space with a rich maroon and white identity.',
            style: TextStyle(
              color: Color(0xFFFFE9DF),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 34),
        ],
      ),
    );
  }
}

class WelcomePanel extends StatelessWidget {
  const WelcomePanel({super.key, required this.onSignUp, required this.onSignIn});

  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Start your experience',
            style: TextStyle(
              color: TemptationsApp.ink,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your path first. The phone verification step opens next.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 26),
          ElevatedButton.icon(
            onPressed: onSignUp,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Sign up'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSignIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign in'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TemptationsApp.maroon,
              minimumSize: const Size.fromHeight(56),
              side: const BorderSide(color: TemptationsApp.maroon, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPanel extends StatefulWidget {
  const LoginPanel({
    super.key,
    required this.intent,
    required this.onBack,
    required this.onContinue,
  });

  final AuthIntent intent;
  final VoidCallback onBack;
  final ValueChanged<AppUser> onContinue;

  @override
  State<LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<LoginPanel> {
  final _auth0 = const Auth0PasswordlessClient();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _status;
  String? _error;

  bool get _isSignUp => widget.intent == AuthIntent.signUp;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final phoneNumber = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (_isSignUp) {
      final username = _usernameController.text.trim();
      final displayName = _displayNameController.text.trim();

      if (username.isEmpty || displayName.isEmpty) {
        _showFormError('Enter username and display name.');
        return;
      }
    }

    if (phoneNumber.isEmpty) {
      _showFormError('Enter your phone number.');
      return;
    }

    if (!_codeSent) {
      await _runAuthAction(() async {
        await _auth0.sendSmsCode(phoneNumber);
        setState(() {
          _codeSent = true;
          _status = 'OTP sent. Enter the code to continue.';
        });
      });
      return;
    }

    if (otp.isEmpty) {
      _showFormError('Enter the OTP from your SMS.');
      return;
    }

    await _runAuthAction(() async {
      final session = await _auth0.verifySmsCode(
        phoneNumber: phoneNumber,
        code: otp,
      );
      widget.onContinue(
        AppUser.fromAuth(
          session: session,
          phoneNumber: phoneNumber,
          username: _usernameController.text,
          displayName: _displayNameController.text,
        ),
      );
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });

    try {
      await action();
    } on Auth0Exception catch (error) {
      _showFormError(error.message);
    } catch (_) {
      _showFormError('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showFormError(String message) {
    if (!mounted) return;

    setState(() {
      _error = message;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final submitText = !_codeSent
        ? 'Send OTP'
        : _isSignUp
            ? 'Create and verify'
            : 'Sign in securely';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: TemptationsApp.champagne,
                foregroundColor: TemptationsApp.maroon,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(child: _CompactBrandMark()),
          const SizedBox(height: 22),
          Text(
            _isSignUp ? 'Create account' : 'Welcome back',
            style: const TextStyle(
                color: TemptationsApp.ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp
                ? 'Use your phone number to create a secure Temptations profile.'
                : 'Use your phone number to sign in to your Temptations profile.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 26),
          if (_isSignUp) ...[
            TextField(
              controller: _usernameController,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.alternate_email_rounded),
                labelText: 'Username',
                hintText: 'temptations_royal',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _displayNameController,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge_rounded),
                labelText: 'Display name',
                hintText: 'Riya Sharma',
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _phoneController,
            enabled: !_busy && !_codeSent,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              labelText: 'Phone number',
              hintText: '+1 555 012 4598',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _otpController,
            enabled: !_busy && _codeSent,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.password_rounded),
              labelText: 'SMS code',
              hintText: '6 digit code',
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            _FormNotice(text: _status!, error: false),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _FormNotice(text: _error!, error: true),
          ],
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_codeSent ? Icons.verified_rounded : Icons.sms_rounded),
            label: Text(_busy ? 'Please wait' : submitText),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _busy ? null : () => widget.onContinue(AppUser.guest()),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Skip for now'),
            style: TextButton.styleFrom(
              foregroundColor: TemptationsApp.maroon,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormNotice extends StatelessWidget {
  const _FormNotice({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFE9E9) : const Color(0xFFEFF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error ? const Color(0xFFE7B2B2) : const Color(0xFFB7DDBD),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? const Color(0xFF8A1C1C) : const Color(0xFF245C2D),
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}

class _CompactBrandMark extends StatelessWidget {
  const _CompactBrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppLogo(height: 138, width: 192),
        const SizedBox(height: 12),
        const Text(
          'Temptations',
          style: TextStyle(
            color: TemptationsApp.maroon,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class SignedInExperience extends StatefulWidget {
  const SignedInExperience({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<SignedInExperience> createState() => _SignedInExperienceState();
}

class _SignedInExperienceState extends State<SignedInExperience> {
  stream.StreamChatClient? _client;
  Future<void>? _connection;
  String? _error;
  stream.Channel? _activeHeaderChannel;
  VoidCallback? _closeActiveConversation;

  @override
  void initState() {
    super.initState();
    _connection = _connectStream();
  }

  @override
  void dispose() {
    final client = _client;
    _client = null;
    unawaited(client?.disconnectUser());
    unawaited(client?.dispose());
    super.dispose();
  }

  Future<void> _connectStream() async {
    if (!StreamConfig.isConfigured) {
      setState(() {
        _error =
            'Stream is not configured. Add STREAM_API_KEY to run args or lib/main.dart.';
      });
      return;
    }

    final client = stream.StreamChatClient(
      StreamConfig.apiKey,
      logLevel: stream.Level.INFO,
    );

    final token = StreamConfig.userToken.isNotEmpty
        ? StreamConfig.userToken
        : client.devToken(widget.user.id).rawValue;

    try {
      await client.connectUser(
        stream.User(
          id: widget.user.id,
          extraData: {
            'name': widget.user.displayName,
            if (widget.user.username != null) 'username': widget.user.username,
            if (widget.user.phoneNumber != null) 'phone': widget.user.phoneNumber,
            'image': 'https://getstream.io/random_png/?name=${widget.user.id}',
          },
        ),
        token,
      );

      if (!mounted) {
        await client.disconnectUser();
        await client.dispose();
        return;
      }

      setState(() {
        _client = client;
      });
    } catch (error) {
      await client.disconnectUser();
      await client.dispose();

      final message = error.toString();
      if (message.contains('development tokens are not allowed')) {
        setState(() {
          _error =
              'Stream rejected the development token. In Stream Dashboard, enable Disable Auth Checks for development, or provide a backend-generated STREAM_USER_TOKEN.';
        });
        return;
      }

      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _connection,
      builder: (context, snapshot) {
        if (_error != null) {
          return Scaffold(
            body: SafeArea(
              child: _DashboardNotice(
                title: 'Stream setup needed',
                message: _error!,
                icon: Icons.key_rounded,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: _DashboardNotice(
                title: 'Stream connection failed',
                message: '${snapshot.error}',
                icon: Icons.cloud_off_rounded,
              ),
            ),
          );
        }

        final client = _client;
        if (client == null) {
          return const Scaffold(
            body: SafeArea(
              child: _DashboardNotice(
                title: 'Connecting chat',
                message: 'Opening your Temptations message space.',
                icon: Icons.forum_rounded,
                loading: true,
              ),
            ),
          );
        }

        return stream.StreamChat(
          client: client,
          streamChatThemeData: stream.StreamChatThemeData.fromTheme(
            Theme.of(context),
          ),
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _AnimatedMessagesHeader(
                          channel: _activeHeaderChannel,
                          user: widget.user,
                          onSignOut: widget.onSignOut,
                          onBack: () {
                            _closeActiveConversation?.call();
                            setState(() => _activeHeaderChannel = null);
                          },
                        ),
                        Expanded(
                          child: _WhatsAppChatShell(
                            user: widget.user,
                            onActiveChannelChanged: (channel) {
                              setState(() => _activeHeaderChannel = channel);
                            },
                            onCloseHandlerChanged: (handler) {
                              _closeActiveConversation = handler;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _activeHeaderChannel == null
                        ? const _MessagesFooter(key: ValueKey('footer'))
                        : const SizedBox.shrink(key: ValueKey('no-footer')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WhatsAppChatShell extends StatefulWidget {
  const _WhatsAppChatShell({
    required this.user,
    required this.onActiveChannelChanged,
    required this.onCloseHandlerChanged,
  });

  final AppUser user;
  final ValueChanged<stream.Channel?> onActiveChannelChanged;
  final ValueChanged<VoidCallback?> onCloseHandlerChanged;

  @override
  State<_WhatsAppChatShell> createState() => _WhatsAppChatShellState();
}

class _WhatsAppChatShellState extends State<_WhatsAppChatShell> {
  stream.StreamChannelListController? _listController;
  stream.Channel? _selectedChannel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listController != null) return;

    final client = stream.StreamChat.of(context).client;
    _listController = stream.StreamChannelListController(
      client: client,
      filter: stream.Filter.in_('members', [widget.user.id]),
      channelStateSort: const [stream.SortOption.desc('last_message_at')],
      limit: 30,
    );
  }

  @override
  void dispose() {
    widget.onActiveChannelChanged(null);
    widget.onCloseHandlerChanged(null);
    _listController?.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    final result = await showDialog<_NewChatResult>(
      context: context,
      builder: (context) => const _NewChatDialog(),
    );

    if (result == null || !mounted) return;

    final otherUserId = _sanitizeStreamUserId(result.userId);
    if (otherUserId == widget.user.id) {
      _showSnack('Enter another user id.');
      return;
    }

    final client = stream.StreamChat.of(context).client;

    try {
      final channelId = _directChannelId(widget.user.id, otherUserId);
      final channel = client.channel(
        'messaging',
        id: channelId,
        extraData: {
          'member_names': {
            widget.user.id: widget.user.displayName,
            otherUserId: result.displayName,
          },
          'members': [widget.user.id, otherUserId],
        },
      );

      await channel.watch();
      await _listController?.refresh();

      if (!mounted) return;
      setState(() => _selectedChannel = channel);
      widget.onActiveChannelChanged(channel);
      widget.onCloseHandlerChanged(_closeConversation);
    } catch (error) {
      _showSnack('Could not start chat: $error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = _selectedChannel;
    final listController = _listController;

    if (listController == null) {
      return const Center(
        child: CircularProgressIndicator(color: TemptationsApp.maroon),
      );
    }

    if (selectedChannel != null) {
      return stream.StreamChannel(
        channel: selectedChannel,
        child: _StreamMessagePane(
          onBack: _closeConversation,
        ),
      );
    }

    return _ChatListPane(
      controller: listController,
      currentUserId: widget.user.id,
      onStartChat: _startChat,
      onChannelTap: (channel) {
        setState(() => _selectedChannel = channel);
        widget.onActiveChannelChanged(channel);
        widget.onCloseHandlerChanged(_closeConversation);
      },
    );
  }

  void _closeConversation() {
    setState(() => _selectedChannel = null);
    widget.onActiveChannelChanged(null);
    widget.onCloseHandlerChanged(null);
  }
}

class _ChatListPane extends StatelessWidget {
  const _ChatListPane({
    required this.controller,
    required this.currentUserId,
    required this.onStartChat,
    required this.onChannelTap,
  });

  final stream.StreamChannelListController controller;
  final String currentUserId;
  final VoidCallback onStartChat;
  final ValueChanged<stream.Channel> onChannelTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chats',
                    style: TextStyle(
                      color: TemptationsApp.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onStartChat,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('New chat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: TemptationsApp.maroon,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0DED5)),
          Expanded(
            child: stream.StreamChannelListView(
              controller: controller,
              onChannelTap: onChannelTap,
              itemBuilder: (context, channels, index, defaultWidget) {
                final channel = channels[index];

                return _TemptationsChannelTile(
                  channel: channel,
                  currentUserId: currentUserId,
                  onTap: () => onChannelTap(channel),
                );
              },
              emptyBuilder: (context) => _EmptyChats(onStartChat: onStartChat),
              loadingBuilder: (context) => const Center(
                child: CircularProgressIndicator(color: TemptationsApp.maroon),
              ),
              errorBuilder: (context, error) => _DashboardNotice(
                title: 'Could not load chats',
                message: '$error',
                icon: Icons.error_outline_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AppLogo(height: 118, width: 166),
            const SizedBox(height: 22),
            const Text(
              'No chats yet',
              style: TextStyle(
                color: TemptationsApp.ink,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a private chat by entering another user id.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onStartChat,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Start chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemptationsChannelTile extends StatelessWidget {
  const _TemptationsChannelTile({
    required this.channel,
    required this.currentUserId,
    required this.onTap,
  });

  final stream.Channel channel;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _peerDisplayName(channel, currentUserId);
    final lastMessage = _lastMessageText(channel);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: TemptationsApp.champagne,
              child: Text(
                initial,
                style: const TextStyle(
                  color: TemptationsApp.maroon,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TemptationsApp.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB9824D),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamMessagePane extends StatelessWidget {
  const _StreamMessagePane({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: stream.StreamMessageListView(
              messageBuilder: (context, details, messages, defaultWidget) {
                final memeAttachment = _firstMemeAttachment(details.message);
                if (memeAttachment != null) {
                  return _MemeStickerBubble(
                    message: details.message,
                    attachment: memeAttachment,
                    isMine: details.isMyMessage,
                  );
                }

                final audioAttachment = _firstPlayableAudioAttachment(
                  details.message,
                );

                if (audioAttachment == null) {
                  return defaultWidget;
                }

                return _VoiceMessageBubble(
                  message: details.message,
                  attachment: audioAttachment,
                  isMine: details.isMyMessage,
                );
              },
            ),
          ),
          const _TemptationsMessageComposer(),
        ],
      ),
    );
  }
}

class _TemptationsMessageComposer extends StatefulWidget {
  const _TemptationsMessageComposer();

  @override
  State<_TemptationsMessageComposer> createState() =>
      _TemptationsMessageComposerState();
}

class MemeSticker {
  const MemeSticker({
    required this.id,
    required this.title,
    required this.stickerUrl,
    required this.audioUrl,
  });

  factory MemeSticker.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return MemeSticker(
      id: doc.id,
      title: data['title'] as String? ?? 'Meme',
      stickerUrl: data['stickerUrl'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String stickerUrl;
  final String audioUrl;
}

class FirebaseMemeRepository {
  const FirebaseMemeRepository();

  static bool _initializing = false;
  static bool _initialized = false;
  static Object? _initializationError;
  static List<MemeSticker>? _cachedMemes;
  static Future<List<MemeSticker>>? _pendingMemes;

  Future<List<MemeSticker>> loadMemes({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedMemes != null) {
      return _cachedMemes!;
    }

    if (!forceRefresh && _pendingMemes != null) {
      return _pendingMemes!;
    }

    final pending = _loadMemesFromFirestore();
    _pendingMemes = pending;

    try {
      return await pending;
    } finally {
      if (identical(_pendingMemes, pending)) {
        _pendingMemes = null;
      }
    }
  }

  Future<List<MemeSticker>> _loadMemesFromFirestore() async {
    await _ensureFirebase();

    final snapshot = await FirebaseFirestore.instance
        .collection('memes')
        .where('enabled', isEqualTo: true)
        .limit(80)
        .get();

    final memes = snapshot.docs
        .map(MemeSticker.fromFirestore)
        .where((meme) => meme.stickerUrl.isNotEmpty && meme.audioUrl.isNotEmpty)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    _cachedMemes = memes;
    return memes;
  }

  Future<void> _ensureFirebase() async {
    if (_initialized) return;
    if (_initializationError != null) throw _initializationError!;

    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (_initialized) return;
      if (_initializationError != null) throw _initializationError!;
    }

    _initializing = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
    } catch (error) {
      _initializationError = error;
      rethrow;
    } finally {
      _initializing = false;
    }
  }
}

class _MemePickerSheet extends StatefulWidget {
  const _MemePickerSheet({
    required this.repository,
    required this.initialQuery,
  });

  final FirebaseMemeRepository repository;
  final String initialQuery;

  @override
  State<_MemePickerSheet> createState() => _MemePickerSheetState();
}

class _MemePickerSheetState extends State<_MemePickerSheet> {
  late final TextEditingController _searchController;
  late Future<List<MemeSticker>> _memesFuture;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _memesFuture = widget.repository.loadMemes();
    unawaited(_precacheStarterStickers());
  }

  Future<void> _precacheStarterStickers() async {
    final memes = await _memesFuture;
    if (!mounted) return;

    for (final meme in memes.take(18)) {
      unawaited(precacheImage(NetworkImage(meme.stickerUrl), context));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.68,
          child: Column(
            children: [
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7D4C8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search memes',
                  hintText: 'laugh, angry, wow',
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<MemeSticker>>(
                  future: _memesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: TemptationsApp.maroon,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _MemePickerNotice(
                        title: 'Firebase setup needed',
                        message:
                            'Add Firebase config and Firestore memes collection. Error: ${snapshot.error}',
                      );
                    }

                    final query = _searchController.text.trim().toLowerCase();
                    final memes = (snapshot.data ?? [])
                        .where(
                          (meme) =>
                              query.isEmpty ||
                              meme.title.toLowerCase().contains(query),
                        )
                        .toList();

                    if (memes.isEmpty) {
                      return const _MemePickerNotice(
                        title: 'No memes found',
                        message: 'Add more docs in Firestore or change search.',
                      );
                    }

                    return GridView.builder(
                      itemCount: memes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, index) {
                        final meme = memes[index];

                        return _MemePickerTile(
                          meme: meme,
                          onTap: () => Navigator.of(context).pop(meme),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemePickerTile extends StatelessWidget {
  const _MemePickerTile({required this.meme, required this.onTap});

  final MemeSticker meme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0DED5)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                meme.stickerUrl,
                fit: BoxFit.contain,
                cacheWidth: 260,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;

                  return const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TemptationsApp.maroon,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: TemptationsApp.maroon,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.volume_up_rounded,
                  color: TemptationsApp.maroon,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    meme.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TemptationsApp.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemePickerNotice extends StatelessWidget {
  const _MemePickerNotice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sticky_note_2_rounded,
              color: TemptationsApp.maroon,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TemptationsApp.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemptationsMessageComposerState
    extends State<_TemptationsMessageComposer> {
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  final _memeRepository = const FirebaseMemeRepository();
  final _recorder = audio_record.AudioRecorder();
  Timer? _recordTimer;
  StreamSubscription<audio_record.Amplitude>? _amplitudeSubscription;
  Duration _recordDuration = Duration.zero;
  String? _recordingPath;
  List<double> _voiceLevels = List.filled(22, 0.16);
  bool _recording = false;
  bool _sending = false;
  bool _memePickerOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_memeRepository.loadMemes());
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    unawaited(_amplitudeSubscription?.cancel());
    unawaited(_recorder.dispose());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (text.toLowerCase().startsWith('/meme')) {
      final query = text.length > 5 ? text.substring(5).trim() : '';
      await _showMemePicker(query: query);
      return;
    }

    final channel = stream.StreamChannel.of(context).channel;
    await _sendMessageWithoutBlockingComposer(
      channel: channel,
      message: stream.Message(text: text),
      failurePrefix: 'Could not send message',
      onQueued: _controller.clear,
    );
  }

  void _handleTextChanged(String value) {
    setState(() {});

    if (value.trim().toLowerCase() != '/meme' || _memePickerOpen) {
      return;
    }

    _controller.clear();
    setState(() {});
    unawaited(_showMemePicker());
  }

  Future<void> _showMemePicker({String query = ''}) async {
    if (_memePickerOpen) return;

    final channel = stream.StreamChannel.of(context).channel;
    final messenger = ScaffoldMessenger.of(context);

    _memePickerOpen = true;
    MemeSticker? selectedMeme;
    try {
      selectedMeme = await showModalBottomSheet<MemeSticker>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (context) {
          return _MemePickerSheet(
            repository: _memeRepository,
            initialQuery: query,
          );
        },
      );
    } finally {
      _memePickerOpen = false;
    }

    if (selectedMeme == null || !mounted) return;

    await _sendMessageWithoutBlockingComposer(
      channel: channel,
      message: stream.Message(
        attachments: [
          stream.Attachment(
            type: stream.AttachmentType.image,
            title: selectedMeme.title,
            imageUrl: selectedMeme.stickerUrl,
            thumbUrl: selectedMeme.stickerUrl,
            extraData: {
              'meme_message': true,
              'meme_id': selectedMeme.id,
              'meme_title': selectedMeme.title,
              'meme_audio_url': selectedMeme.audioUrl,
            },
          ),
        ],
      ),
      failurePrefix: 'Could not send meme',
      onQueued: _controller.clear,
      messenger: messenger,
    );
  }

  Future<void> _sendMessageWithoutBlockingComposer({
    required stream.Channel channel,
    required stream.Message message,
    required String failurePrefix,
    required VoidCallback onQueued,
    ScaffoldMessengerState? messenger,
  }) async {
    final scaffoldMessenger = messenger ?? ScaffoldMessenger.of(context);

    setState(() => _sending = true);

    try {
      final sendFuture = channel.sendMessage(message);
      onQueued();

      await Future.any<void>([
        sendFuture.then<void>((_) {}),
        Future<void>.delayed(const Duration(milliseconds: 650)),
      ]);

      unawaited(
        sendFuture.then<void>((_) {}).catchError((Object error) {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('$failurePrefix: $error')),
          );
        }),
      );
    } catch (error) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('$failurePrefix: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickAndSendAttachment(_AttachmentKind kind) async {
    final channel = stream.StreamChannel.of(context).channel;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    try {
      final picked = await _pickAttachment(kind);
      if (picked == null) return;
      if (!mounted) return;

      setState(() => _sending = true);

      await channel.sendMessage(
        stream.Message(
          attachments: [
            stream.Attachment(
              type: picked.type,
              title: picked.name,
              file: stream.AttachmentFile(
                path: picked.path,
                name: picked.name,
                size: picked.size,
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send attachment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<_PickedAttachment?> _pickAttachment(_AttachmentKind kind) async {
    switch (kind) {
      case _AttachmentKind.image:
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (image == null) return null;

        final file = File(image.path);
        final stat = await file.stat();
        return _PickedAttachment(
          path: image.path,
          name: image.name,
          size: stat.size,
          type: stream.AttachmentType.image,
        );

      case _AttachmentKind.video:
        final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video == null) return null;

        final file = File(video.path);
        final stat = await file.stat();
        return _PickedAttachment(
          path: video.path,
          name: video.name,
          size: stat.size,
          type: stream.AttachmentType.video,
        );

      case _AttachmentKind.audio:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          withData: false,
        );
        return _pickedFileFromResult(result, stream.AttachmentType.audio);

      case _AttachmentKind.file:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: false,
        );
        return _pickedFileFromResult(result, stream.AttachmentType.file);
    }
  }

  _PickedAttachment? _pickedFileFromResult(
    FilePickerResult? result,
    stream.AttachmentType type,
  ) {
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return null;

    return _PickedAttachment(
      path: path,
      name: file.name,
      size: file.size,
      type: type,
    );
  }

  Future<void> _startVoiceRecording() async {
    if (_recording || _sending) return;

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const audio_record.RecordConfig(
        encoder: audio_record.AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        noiseSuppress: true,
        echoCancel: true,
      ),
      path: path,
    );

    HapticFeedback.mediumImpact();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amplitude) {
      final db = amplitude.current.isFinite ? amplitude.current : amplitude.max;
      final normalized = ((db + 55) / 45).clamp(0.10, 1.0).toDouble();
      if (mounted) {
        setState(() {
          _voiceLevels = [
            ..._voiceLevels.skip(1),
            normalized,
          ];
        });
      }
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    });

    if (!mounted) return;
    setState(() {
      _recording = true;
      _recordingPath = path;
      _recordDuration = Duration.zero;
      _voiceLevels = List.filled(22, 0.16);
    });
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recording) return;

    _recordTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    await _recorder.cancel();

    final path = _recordingPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _recording = false;
      _recordingPath = null;
      _recordDuration = Duration.zero;
      _voiceLevels = List.filled(22, 0.16);
    });
  }

  Future<void> _sendVoiceRecording() async {
    if (!_recording || _sending) return;

    final channel = stream.StreamChannel.of(context).channel;
    final messenger = ScaffoldMessenger.of(context);
    _recordTimer?.cancel();
    await _amplitudeSubscription?.cancel();

    try {
      final path = await _recorder.stop();
      final effectivePath = path ?? _recordingPath;
      if (effectivePath == null) return;

      final file = File(effectivePath);
      if (!await file.exists()) return;

      final stat = await file.stat();
      if (!mounted) return;

      setState(() {
        _sending = true;
        _recording = false;
        _recordingPath = null;
      });

      await channel.sendMessage(
        stream.Message(
          attachments: [
            stream.Attachment(
              type: stream.AttachmentType.audio,
              title: 'Voice message',
              file: stream.AttachmentFile(
                path: effectivePath,
                name: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
                size: stat.size,
              ),
              extraData: {
                'duration': _recordDuration.inSeconds,
                'voice_message': true,
              },
            ),
          ],
        ),
      );

      HapticFeedback.selectionClick();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send voice message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _recording = false;
          _recordingPath = null;
          _recordDuration = Duration.zero;
          _voiceLevels = List.filled(22, 0.16);
        });
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7D4C8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  children: [
                    _AttachmentOption(
                      icon: Icons.image_rounded,
                      label: 'Image',
                      onTap: () => _pickAndSendAttachment(_AttachmentKind.image),
                    ),
                    _AttachmentOption(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      onTap: () => _pickAndSendAttachment(_AttachmentKind.video),
                    ),
                    _AttachmentOption(
                      icon: Icons.mic_rounded,
                      label: 'Audio',
                      onTap: () => _pickAndSendAttachment(_AttachmentKind.audio),
                    ),
                    _AttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Files',
                      onTap: () => _pickAndSendAttachment(_AttachmentKind.file),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      return _VoiceRecordingBar(
        duration: _recordDuration,
        levels: _voiceLevels,
        sending: _sending,
        onCancel: _cancelVoiceRecording,
        onSend: _sendVoiceRecording,
      );
    }

    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0DED5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F3),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFF0DED5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach',
                    onPressed: _showAttachmentMenu,
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: TemptationsApp.maroon,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: _handleTextChanged,
                    ),
                  ),
                  GestureDetector(
                    onLongPress: _sending || hasText ? null : _startVoiceRecording,
                    child: IconButton.filled(
                      tooltip: hasText ? 'Send' : 'Record voice',
                      onPressed: _sending
                          ? null
                          : hasText
                              ? _send
                              : _startVoiceRecording,
                      style: IconButton.styleFrom(
                        backgroundColor: TemptationsApp.maroon,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE7D4C8),
                        disabledForegroundColor: Colors.white,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              hasText ? Icons.send_rounded : Icons.mic_rounded,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceRecordingBar extends StatelessWidget {
  const _VoiceRecordingBar({
    required this.duration,
    required this.levels,
    required this.sending,
    required this.onCancel,
    required this.onSend,
  });

  final Duration duration;
  final List<double> levels;
  final bool sending;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0DED5))),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: TemptationsApp.maroon,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x226E1228),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cancel voice message',
              onPressed: sending ? null : onCancel,
              icon: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            Container(
              height: 10,
              width: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD9CB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatRecordingDuration(duration),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _VoiceLevelBars(levels: levels)),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send voice message',
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: TemptationsApp.maroon,
                disabledBackgroundColor: const Color(0xFFE7D4C8),
              ),
              icon: sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TemptationsApp.maroon,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceLevelBars extends StatelessWidget {
  const _VoiceLevelBars({required this.levels});

  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barCount = levels.length;
        final width = constraints.maxWidth / barCount;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(barCount, (index) {
            final wave = ((index % 5) + 3) / 7;
            final height = 8 + (34 * levels[index] * wave);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: (width - 3).clamp(2, 5).toDouble(),
              height: height.clamp(8, 38).toDouble(),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}

String _formatRecordingDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

stream.Attachment? _firstMemeAttachment(stream.Message message) {
  for (final attachment in message.attachments) {
    final isMeme = attachment.extraData['meme_message'] == true;
    final audioUrl = attachment.extraData['meme_audio_url'];
    final stickerUrl = attachment.imageUrl ?? attachment.thumbUrl;

    if (isMeme &&
        audioUrl is String &&
        audioUrl.isNotEmpty &&
        stickerUrl != null &&
        stickerUrl.isNotEmpty) {
      return attachment;
    }
  }

  return null;
}

class _MemeStickerBubble extends StatefulWidget {
  const _MemeStickerBubble({
    required this.message,
    required this.attachment,
    required this.isMine,
  });

  final stream.Message message;
  final stream.Attachment attachment;
  final bool isMine;

  @override
  State<_MemeStickerBubble> createState() => _MemeStickerBubbleState();
}

class _MemeStickerBubbleState extends State<_MemeStickerBubble> {
  late final just_audio.AudioPlayer _player;
  StreamSubscription<just_audio.PlayerState>? _stateSubscription;
  Future<void>? _loadFuture;
  bool _loading = false;
  bool _playing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _player = just_audio.AudioPlayer();
    _stateSubscription = _player.playerStateStream.listen((state) async {
      if (!mounted) return;

      if (state.processingState == just_audio.ProcessingState.completed) {
        if (_playing) {
          setState(() => _playing = false);
        }
        unawaited(_player.seek(Duration.zero));
        unawaited(_player.pause());
        return;
      }

      final isPlaying = state.playing;
      if (mounted && _playing != isPlaying) {
        setState(() => _playing = isPlaying);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_preloadSound());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _ensureSoundLoaded({bool showLoading = false}) async {
    if (_loaded) return;
    final audioUrl = widget.attachment.extraData['meme_audio_url'];
    if (audioUrl is! String || audioUrl.isEmpty) return;

    _loadFuture ??= _player.setUrl(audioUrl).then((_) {
      _loaded = true;
    }).whenComplete(() {
      _loadFuture = null;
    });

    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      await _loadFuture;
    } finally {
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _preloadSound() async {
    try {
      await _ensureSoundLoaded();
    } catch (_) {
      // The tap handler reports playback errors; background preload stays silent.
    }
  }

  Future<void> _toggleSound() async {
    if (_loading) return;

    try {
      await _ensureSoundLoaded(showLoading: !_loaded);

      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.seek(Duration.zero);
        await _player.play();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play meme sound: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.attachment.extraData['meme_title'] as String? ??
            widget.attachment.title ??
            'Meme';
    final stickerUrl = widget.attachment.imageUrl ?? widget.attachment.thumbUrl;

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                stickerUrl == null
                    ? const Center(child: Icon(Icons.image_not_supported))
                    : Image.network(
                        stickerUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: 520,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded),
                        ),
                      ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: IconButton.filled(
                    tooltip: 'Play $title sound',
                    onPressed: _toggleSound,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: TemptationsApp.maroon,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      elevation: 3,
                      minimumSize: const Size.square(42),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TemptationsApp.maroon,
                            ),
                          )
                        : Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

stream.Attachment? _firstPlayableAudioAttachment(stream.Message message) {
  for (final attachment in message.attachments) {
    final isAudio = attachment.type == stream.AttachmentType.audio ||
        attachment.type == stream.AttachmentType.voiceRecording ||
        attachment.extraData['voice_message'] == true;

    if (!isAudio) continue;

    final hasSource = attachment.assetUrl != null ||
        attachment.localUri != null ||
        attachment.file?.path != null;
    if (hasSource) return attachment;
  }

  return null;
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.message,
    required this.attachment,
    required this.isMine,
  });

  final stream.Message message;
  final stream.Attachment attachment;
  final bool isMine;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  late final just_audio.AudioPlayer _player;
  StreamSubscription<just_audio.PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = false;
  bool _playing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _player = just_audio.AudioPlayer();
    _stateSubscription = _player.playerStateStream.listen((state) async {
      if (!mounted) return;

      if (state.processingState == just_audio.ProcessingState.completed) {
        await _player.seek(Duration.zero);
        await _player.pause();
      }

      if (mounted) {
        setState(() => _playing = state.playing);
      }
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _duration = duration);
      }
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;

    try {
      if (!_loaded) {
        setState(() => _loading = true);
        final source = _audioSource(widget.attachment);
        if (source == null) {
          throw const FormatException('Audio source is not ready yet.');
        }

        if (source.startsWith('http')) {
          await _player.setUrl(source);
        } else {
          await _player.setFilePath(source);
        }
        _loaded = true;
      }

      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play voice message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration == Duration.zero
        ? Duration(
            seconds:
                (widget.attachment.extraData['duration'] as num?)?.round() ?? 0,
          )
        : _duration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final background =
        widget.isMine ? TemptationsApp.maroon : const Color(0xFFFFF7F3);
    final foreground = widget.isMine ? Colors.white : TemptationsApp.ink;
    final soft =
        widget.isMine ? const Color(0xFFFFD9CB) : TemptationsApp.maroon;

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.isMine ? TemptationsApp.maroon : const Color(0xFFF0DED5),
          ),
        ),
        child: Row(
          children: [
            IconButton.filled(
              onPressed: _toggle,
              style: IconButton.styleFrom(
                backgroundColor: widget.isMine ? Colors.white : TemptationsApp.maroon,
                foregroundColor: widget.isMine ? TemptationsApp.maroon : Colors.white,
              ),
              icon: _loading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMine ? TemptationsApp.maroon : Colors.white,
                      ),
                    )
                  : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VoicePlaybackBars(
                    progress: progress,
                    activeColor: soft,
                    inactiveColor: foreground.withValues(alpha: 0.34),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRecordingDuration(duration == Duration.zero ? _position : duration),
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePlaybackBars extends StatelessWidget {
  const _VoicePlaybackBars({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    const count = 28;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (index) {
        final active = index / count <= progress;
        final height = 8 + (((index * 7) % 19) / 19) * 22;

        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

String? _audioSource(stream.Attachment attachment) {
  if (attachment.assetUrl != null && attachment.assetUrl!.isNotEmpty) {
    return attachment.assetUrl;
  }

  if (attachment.localUri != null) {
    final uri = attachment.localUri!;
    if (uri.scheme == 'file') return uri.toFilePath();
    if (uri.scheme.isEmpty) return uri.path;
  }

  final path = attachment.file?.path;
  if (path != null && path.isNotEmpty) return path;

  return null;
}

enum _AttachmentKind { image, video, audio, file }

class _PickedAttachment {
  const _PickedAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.type,
  });

  final String path;
  final String name;
  final int size;
  final stream.AttachmentType type;
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: TemptationsApp.champagne,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: TemptationsApp.maroon, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TemptationsApp.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMessagesHeader extends StatelessWidget {
  const _AnimatedMessagesHeader({
    required this.channel,
    required this.user,
    required this.onSignOut,
    required this.onBack,
  });

  final stream.Channel? channel;
  final AppUser user;
  final VoidCallback onSignOut;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final selectedChannel = channel;

    return Container(
      decoration: const BoxDecoration(
        color: TemptationsApp.maroon,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: selectedChannel == null
            ? _MessagesListHeader(
                key: const ValueKey('list-header'),
                user: user,
                onSignOut: onSignOut,
              )
            : _ConversationTopHeader(
                key: ValueKey('chat-header-${selectedChannel.cid}'),
                channel: selectedChannel,
                currentUserId: user.id,
                onBack: onBack,
              ),
      ),
    );
  }
}

class _MessagesListHeader extends StatelessWidget {
  const _MessagesListHeader({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          const _AppLogo(height: 54, width: 78),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temptations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Messages',
                  style: TextStyle(
                    color: Color(0xFFFFE9DF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => _showProfileSheet(context, user, onSignOut),
            icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

void _showProfileSheet(
  BuildContext context,
  AppUser user,
  VoidCallback onSignOut,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _AppLogo(height: 94, width: 132)),
              const SizedBox(height: 16),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TemptationsApp.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.username == null ? user.id : '@${user.username}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onSignOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TemptationsApp.maroon,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: TemptationsApp.maroon),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ConversationTopHeader extends StatelessWidget {
  const _ConversationTopHeader({
    super.key,
    required this.channel,
    required this.currentUserId,
    required this.onBack,
  });

  final stream.Channel channel;
  final String currentUserId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final name = _peerDisplayName(channel, currentUserId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person_rounded, color: TemptationsApp.maroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Tap to view chat info',
                  style: TextStyle(
                    color: Color(0xFFFFE9DF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Call',
            onPressed: () {},
            icon: const Icon(Icons.call_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _NewChatResult {
  const _NewChatResult({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _userIdController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _userIdController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _submit() {
    final userId = _userIdController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (userId.isEmpty) return;

    Navigator.of(context).pop(
      _NewChatResult(
        userId: userId,
        displayName: displayName.isEmpty ? userId : displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'New chat',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _userIdController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.alternate_email_rounded),
              labelText: 'User id',
              hintText: 'auth0 user id or username',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_rounded),
              labelText: 'Display name',
              hintText: 'Optional',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: TemptationsApp.maroon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

String _directChannelId(String a, String b) {
  final ids = [a, b]..sort();
  return 'dm_${ids.join('_')}'.replaceAll(RegExp(r'[^A-Za-z0-9_\-=]'), '_');
}

String _peerDisplayName(stream.Channel channel, String currentUserId) {
  stream.Member? peer;

  try {
    for (final member in channel.state?.members ?? <stream.Member>[]) {
      if (member.userId != null && member.userId != currentUserId) {
        peer = member;
        break;
      }
    }
  } catch (_) {
    peer = null;
  }

  final peerId = peer?.userId;
  final memberNames = channel.extraData['member_names'];

  if (memberNames is Map && peerId != null) {
    final storedName = memberNames[peerId];
    if (storedName is String && storedName.trim().isNotEmpty) {
      return storedName.trim();
    }
  }

  final userName = peer?.user?.name;
  if (userName != null && userName.trim().isNotEmpty) {
    return userName.trim();
  }

  if (peerId != null && peerId.trim().isNotEmpty) {
    return peerId.trim();
  }

  final channelName = channel.name;
  if (channelName != null && channelName.trim().isNotEmpty) {
    return channelName.trim();
  }

  return 'Chat';
}

String _lastMessageText(stream.Channel channel) {
  try {
    final message = channel.state?.lastMessage?.text;
    if (message != null && message.trim().isNotEmpty) {
      return message.trim();
    }
  } catch (_) {
    return 'Tap to open chat';
  }

  return 'Tap to open chat';
}

class _DashboardNotice extends StatelessWidget {
  const _DashboardNotice({
    required this.title,
    required this.message,
    required this.icon,
    this.loading = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.all(22),
          padding: const EdgeInsets.all(28),
          decoration: _panelDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AppLogo(height: 138, width: 192),
              const SizedBox(height: 22),
              if (loading)
                const CircularProgressIndicator(color: TemptationsApp.maroon)
              else
                Icon(icon, color: TemptationsApp.maroon, size: 34),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TemptationsApp.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesFooter extends StatelessWidget {
  const _MessagesFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: TemptationsApp.maroon,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FooterItem(icon: Icons.chat_rounded, label: 'Chats', active: true),
          _FooterItem(icon: Icons.note_alt_rounded, label: 'Notes'),
          _FooterItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: active ? Colors.white : const Color(0xFFFFD9CB),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFFFD9CB),
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({
    required this.height,
    required this.width,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Image.asset(
        'assets/images/temptations_logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class ChannelList extends StatelessWidget {
  const ChannelList({super.key});

  @override
  Widget build(BuildContext context) {
    const channels = [
      ('Aarav', 'Dinner plans are confirmed.', '2m', true),
      ('Mira', 'That maroon theme looks elite.', '18m', false),
      ('Temptations Concierge', 'Your profile boost is live.', '1h', false),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded),
                label: const Text('New'),
                style: FilledButton.styleFrom(
                  backgroundColor: TemptationsApp.champagne,
                  foregroundColor: TemptationsApp.maroon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final channel in channels) ...[
            _ChannelTile(
              name: channel.$1,
              message: channel.$2,
              time: channel.$3,
              active: channel.$4,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class ConversationPane extends StatelessWidget {
  const ConversationPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: TemptationsApp.maroon,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded, color: TemptationsApp.maroon),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aarav',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Verified and online',
                        style: TextStyle(color: Color(0xFFFFE9DF)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: Colors.white),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Bubble(
                    text: 'Your profile feels premium now.',
                    alignRight: false,
                  ),
                  _Bubble(
                    text: 'Good. Keep the app clean, rich, and easy to trust.',
                    alignRight: true,
                  ),
                  _Bubble(
                    text: 'Done. Maroon, white, and polished.',
                    alignRight: false,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Write a message',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  width: 56,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: TemptationsApp.maroon,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.name,
    required this.message,
    required this.time,
    required this.active,
  });

  final String name;
  final String message;
  final String time;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? TemptationsApp.maroon : const Color(0xFFFFF7F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? TemptationsApp.maroon : const Color(0xFFF1DED5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: active ? Colors.white : TemptationsApp.champagne,
            child: Text(
              name.characters.first,
              style: TextStyle(
                color: active ? TemptationsApp.maroon : TemptationsApp.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: active ? Colors.white : TemptationsApp.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? Colors.white.withValues(alpha: 0.78)
                        : Colors.black.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: active
                  ? Colors.white.withValues(alpha: 0.78)
                  : Colors.black.withValues(alpha: 0.46),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.alignRight});

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: alignRight ? TemptationsApp.maroon : const Color(0xFFFFF7F3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: alignRight ? TemptationsApp.maroon : const Color(0xFFF1DED5),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: alignRight ? Colors.white : TemptationsApp.ink,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: const Color(0xFFF0DED5)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x10000000),
        blurRadius: 24,
        offset: Offset(0, 14),
      ),
    ],
  );
}
