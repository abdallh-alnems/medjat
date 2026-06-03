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
    project.evaluationDependsOn(":app")
}

// Force a consistent JVM target (17) across every module, including plugin
// subprojects like tflite_flutter that otherwise mix Java 1.8 with Kotlin 21.
subprojects {
    // Align Java compatibility on every plugin module. Done in afterEvaluate so it
    // overrides compileOptions the plugin sets inline (e.g. in_app_update -> 1.8).
    // The :app module is excluded: it already targets 17 and is evaluated eagerly
    // above via evaluationDependsOn, so afterEvaluate would throw.
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let {
                (it as com.android.build.gradle.BaseExtension).compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
    // Align Kotlin to the same target.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
