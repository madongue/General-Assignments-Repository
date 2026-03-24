pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "General-Assignments-Repository"

// Include main assignments app
include(":app")

// Include FocusFlow module
include(":FocusFlow:app")
project(":FocusFlow:app").projectDir = file("FocusFlow/app")
