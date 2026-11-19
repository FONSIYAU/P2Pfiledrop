allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Pin compileSdk & NDK for all Android plugin subprojects (e.g. package:jni,
    // open_filex, pasteboard) to locally installed SDK 36 & NDK 27.2.12479018
    // so AGP never invokes sdkmanager to download older SDK platforms at build time.
    project.afterEvaluate {
        val ext = project.extensions.findByName("android")
        if (ext != null) {
            try {
                ext.javaClass.getMethod("setNdkVersion", String::class.java)
                    .invoke(ext, "27.2.12479018")
            } catch (_: Throwable) {
            }
            try {
                ext.javaClass.getMethod("setBuildToolsVersion", String::class.java)
                    .invoke(ext, "36.0.0")
            } catch (_: Throwable) {
            }
            var sdkPinned = false
            for (paramType in listOf(java.lang.Integer::class.java, Int::class.javaPrimitiveType!!)) {
                if (sdkPinned) break
                try {
                    ext.javaClass.getMethod("setCompileSdk", paramType).invoke(ext, 36)
                    sdkPinned = true
                } catch (_: Throwable) {
                }
            }
            if (!sdkPinned) {
                try {
                    ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType!!)
                        .invoke(ext, 36)
                } catch (_: Throwable) {
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
