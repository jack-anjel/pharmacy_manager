// File: pharmacy_manager/android/build.gradle.kts

// ———————————————————————————————————————————————————————
// 1) نضيف قسم buildscript في أعلى الملف:
//    هنا نعرف kotlin_version (1.8.10) ونسخّ إصدار Android Gradle Plugin (8.1.1).
//    هذا يضمن أن جميع الموديولات (من ضمنها flutter_native_timezone) 
//    ستُبنى بإصدار Kotlin Gradle Plugin ≥ 1.5.20.
// ———————————————————————————————————————————————————————

buildscript {
    // نعرّف متغيّر kotlin_version في الـ extra modules
    val kotlin_version by extra("1.8.10")

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin (مثال لإصدار حديث متوافق مع Flutter 3.32.0)
        classpath("com.android.tools.build:gradle:8.1.1")
        // Kotlin Gradle Plugin (يجب أن يكون ≥ 1.5.20، وهنا اخترنا 1.8.10)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

// ———————————————————————————————————————————————————————
// 2) نترك هنا قسم allprojects كما هو، ولا ندخل عليه في هذه المرحلة أي تعديل.
// ———————————————————————————————————————————————————————

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ———————————————————————————————————————————————————————
// 3) الكود اللاحق هو ما كان موجودًا لديك في ملفك الأصلي.
//    لاحظ أنّنا لم نغيّر هذه الأقسام (بخلاف رفع نسخ الـ Kotlin و AGP في الأعلى).
//    سنلصق هنا بقية محتوى الملف كما كان لديك، ويُفضَّل أن يتضمّن أقسام البناء المخصصة.
// ———————————————————————————————————————————————————————

// في بعض المشاريع قد تجد تغييرات خاصة بمجلد الـ build (ضبط مكانه مثلاً)
// هذه الأسطر لمستودعك ستبدو مشابهة لما عرضته، فلا تلمسها سوى إذا كنت بحاجة فعلًا:

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ———————————————————————————————————————————————————————
// 4) غالبًا لن تجد هنا في الملف الرئيسي (android/build.gradle.kts) 
//    أقسام مثل `android { … }` أو `dependencies { … }` الخاصة بالتطبيق، 
//    لأنّ هذه تكون في ملف فرعي هو `android/app/build.gradle.kts`. 
//    إذا وجدت لديك أقسام إضافية ضمن هذا الملف، اتركها كما هي.
// ———————————————————————————————————————————————————————
