# Preserve Google ML Kit component registrars and bundled barcode scanning classes in R8 release builds.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keepnames class com.google.firebase.components.ComponentRegistrar
