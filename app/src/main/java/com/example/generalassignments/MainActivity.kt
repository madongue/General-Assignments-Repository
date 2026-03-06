package com.example.generalassignments

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import exercise_1_higher_order_function.HigherOrderFunctionScreen
import exercise_2_transforming_between_collection_types.TransformingCollectionsScreen
import exercise_3_complex_data_processing.ComplexDataProcessingScreen
import filtering_and_transforming_with_lambdas.FilteringExerciseScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                var currentScreen by remember { mutableStateOf(0) }

                if (currentScreen == 0) {
                    MenuScreen(onNavigate = { currentScreen = it })
                } else {
                    Box {
                        when (currentScreen) {
                            1 -> FilteringExerciseScreen()
                            2 -> HigherOrderFunctionScreen()
                            3 -> TransformingCollectionsScreen()
                            4 -> ComplexDataProcessingScreen()
                        }
                        
                        Button(
                            onClick = { currentScreen = 0 },
                            modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp)
                        ) {
                            Text("Back to Menu")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MenuScreen(onNavigate: (Int) -> Unit) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                "Kotlin Exercises",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(32.dp))
            
            ExerciseButton("Filtering & Transforming", 1, onNavigate)
            ExerciseButton("Exercise 1: Higher Order", 2, onNavigate)
            ExerciseButton("Exercise 2: Transforming Map", 3, onNavigate)
            ExerciseButton("Exercise 3: Complex Processing", 4, onNavigate)
        }
    }
}

@Composable
fun ExerciseButton(text: String, id: Int, onClick: (Int) -> Unit) {
    Button(
        onClick = { onClick(id) },
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
    ) {
        Text(text)
    }
}
