plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}
import java.io.File

val flutterTargetAbiFilters = mapOf(
    "android-arm" to "armeabi-v7a",
    "android-arm64" to "arm64-v8a",
    "android-x64" to "x86_64",
)
    .let { targetMap ->
        (findProperty("target-platform") as String?)
            ?.split(",")
            ?.mapNotNull { targetMap[it.trim()] }
            ?.distinct()
            ?: emptyList()
    }

val nativeLibRoot = File(projectDir, "../../libclash/android")
val availableNativeAbis = nativeLibRoot
    .listFiles()
    ?.filter { it.isDirectory() }
    ?.map { it.name }
    ?.toSet()
    ?: emptySet()

val effectiveAbiFilters = if (flutterTargetAbiFilters.isNotEmpty()) {
    flutterTargetAbiFilters.filter { it in availableNativeAbis }
} else {
    availableNativeAbis.toList()
}

android {
    namespace = "com.fastcat.app.core"
    compileSdk = 36
    ndkVersion = "28.0.13004108"

    defaultConfig {
        minSdk = 21
        if (effectiveAbiFilters.isNotEmpty()) {
            ndk {
                abiFilters += effectiveAbiFilters
            }
        }
    }

    buildTypes {
        release {
            isJniDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    externalNativeBuild {
        cmake {
            path("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    implementation("androidx.annotation:annotation-jvm:1.9.1")
}

val copyNativeLibs by tasks.register<Copy>("copyNativeLibs") {
    doFirst {
        delete("src/main/jniLibs")
    }
    from("../../libclash/android")
    into("src/main/jniLibs")
    if (effectiveAbiFilters.isNotEmpty()) {
        effectiveAbiFilters.forEach { abi ->
            include("$abi/**")
        }
    }
}

afterEvaluate {
    tasks.named("preBuild") {
        dependsOn(copyNativeLibs)
    }
}
