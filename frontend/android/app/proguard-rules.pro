# Keep ONNX Runtime Java classes used by the native JNI layer.
-keep class ai.onnxruntime.** { *; }

# Keep constructors and members that may be accessed reflectively/JNI.
-keepclassmembers class ai.onnxruntime.** { *; }
