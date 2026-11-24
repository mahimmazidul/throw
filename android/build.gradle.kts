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
        // The floor is deliberately 37, not 36: bluetooth_low_energy_android's
        // Kotlin does not type-check against API 37 (nullable scanner and
        // advertiser), so pinning plugins *up* is what keeps this build green.
        // Anything that needs a different SDK is a dependency-level decision,
        // not something to paper over here.
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
