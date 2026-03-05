// MainActivity.kt — Android 12+ SplashScreen API
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()

        // Optional: keep splash visible while loading
        splashScreen.setKeepOnScreenCondition { isLoading }

        super.onCreate(savedInstanceState)
        // ...
    }
}

// AndroidManifest.xml — set theme on activity
// <activity
//     android:name=".MainActivity"
//     android:theme="@style/Theme.App.Splash"
//     ... />

// build.gradle — add dependency
// implementation("androidx.core:core-splashscreen:1.0.1")
