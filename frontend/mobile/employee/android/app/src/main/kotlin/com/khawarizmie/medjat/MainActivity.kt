package com.khawarizmie.medjat

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth shows the system
// biometric prompt through AndroidX BiometricPrompt, which needs a
// FragmentActivity host. Under plain FlutterActivity the prompt never appears
// and authenticate() fails at runtime with no_fragment_activity.
class MainActivity : FlutterFragmentActivity()
