# TensorFlow Lite — used by face check-in (FaceEmbedder) through tflite_flutter.
#
# The GPU delegate is an optional artifact we do not ship, but the TFLite Java
# classes reference it, so R8 aborts the release build on the dangling
# reference unless it is explicitly ignored.
-dontwarn org.tensorflow.lite.gpu.**

# The rest of the TFLite classes are instantiated from native code over JNI,
# which R8 cannot see — without this they get stripped or renamed and the
# interpreter fails to load at runtime.
-keep class org.tensorflow.lite.** { *; }
