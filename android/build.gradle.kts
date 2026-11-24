import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
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
}

subprojects {
    afterEvaluate {
        // Some plugins ship with an older compileSdk, which breaks dependency
        // metadata checks (e.g. file_picker vs flutter_plugin_android_lifecycle).
        //
        // Keep this at 36, and do not raise it without building the APK.
        //
        // bluetooth_low_energy_android 6.2.1 does not compile against API 37:
        // BluetoothLeScanner and BluetoothLeAdvertiser became nullable, so its
        // Kotlin fails to type-check. The app itself is on compileSdk 37 (the
        // app is fine at 37 — the plugin is not), so plugins are held at 36.
        //
        // An earlier attempt raised this floor to 37 to satisfy
        // shared_preferences_android/androidx.jni. That dependency has been
        // removed in favour of a file-backed store (see lib/core/preferences.dart),
        // which is the right fix: the two requirements could never coexist.
        extensions.findByType(LibraryExtension::class.java)?.apply {
            if (compileSdk == null || (compileSdk ?: 0) < 36) {
                compileSdk = 36
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
