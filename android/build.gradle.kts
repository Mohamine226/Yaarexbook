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

// Force compileSdk 36 pour tous les plugins (file_picker est compilé avec 34).
subprojects {
    val forceCompileSdk: Project.() -> Unit = {
        val ext = extensions.findByName("android")
        if (ext != null) {
            try {
                ext.javaClass.getMethod("setCompileSdk", Integer::class.java).invoke(ext, 36)
            } catch (e: Exception) {
                println("compileSdk non modifié pour ${name}: ${e.message}")
            }
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}