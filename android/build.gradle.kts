allprojects {
    repositories {
        maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
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

// Force all Android plugins to compileSdk 36.
// Must run in afterEvaluate (after each plugin's own `android { compileSdk ... }` executes),
// and must be registered BEFORE evaluationDependsOn(":app") evaluates any subproject.
// afterEvaluate callbacks run in registration order: this one is registered at root-configuration
// time, so it runs before AGP's own variant-creation callback reads compileSdk.
subprojects {
    afterEvaluate {
        when (val androidExt = extensions.findByName("android")) {
            is com.android.build.api.dsl.LibraryExtension -> androidExt.compileSdk = 36
            is com.android.build.api.dsl.ApplicationExtension -> androidExt.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
