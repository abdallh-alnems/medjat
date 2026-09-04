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
// subprojects like tflite_flutter that otherwise mix Java 1.8 with Kotlin 21
// and fail the build outright.
//
// Lifted from permedjat_app, which hit exactly this and solved it the same way.
// It belongs here rather than in app/build.gradle.kts because the failing task
// is the PLUGIN's own compile, which app-level compileOptions never reach.
subprojects {
    // afterEvaluate so it overrides compileOptions a plugin sets inline. The
    // :app module is excluded: it already targets 17 and is evaluated eagerly
    // by evaluationDependsOn above, so afterEvaluate would throw.
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
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
