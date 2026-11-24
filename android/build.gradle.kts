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
        // The threshold must be 37, not 36: shared_preferences_android declares
        // exactly 36 and depends on androidx.jni, which requires its consumers
        // to compile against API 37 or later. A `< 36` guard let it through and
        // failed :shared_preferences_android:checkReleaseAarMetadata on the
        // v1.1.0 release build while Linux and Windows went green.
        extensions.findByType(LibraryExtension::class.java)?.apply {
            if (compileSdk == null || (compileSdk ?: 0) < 37) {
                compileSdk = 37
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
