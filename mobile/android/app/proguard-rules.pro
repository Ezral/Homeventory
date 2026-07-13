# Keep ML Kit barcode scanning (bundled model) for release R8.
# Without these, mobile_scanner start() NPEs with an obfuscated message like:
#   Attempt to invoke virtual method 'h6.c h6.b.a(d6.b)' on a null object reference
# Plugin consumer rules use single-segment wildcards that miss nested packages.

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.photos.** { *; }

-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode.**
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode_bundled.**
