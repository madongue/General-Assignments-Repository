package exercise_1_higher_order_function

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Exercise 1: Higher-Order Function
 * 
 * Task:
 * Write a function processList that takes a list of integers and a lambda (Int) -> Boolean,
 * and returns a new list containing only the elements that satisfy the predicate.
 */

/**
 * My implementation of the higher-order function
 */
fun processList(
    numbers: List<Int>,
    predicate: (Int) -> Boolean
): List<Int> {
    val result = mutableListOf<Int>()
    for (num in numbers) {
        if (predicate(num)) {
            result.add(num)
        }
    }
    return result
}

@Composable
fun HigherOrderFunctionScreen() {
    val nums = listOf(1, 2, 3, 4, 5, 6)
    
    // Testing the function with an "even numbers" predicate
    val evenNumbers = remember { processList(nums) { it % 2 == 0 } }
    
    // Testing with another predicate just for variety in UI
    val greaterThanThree = remember { processList(nums) { it > 3 } }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Higher-Order Functions",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = "Custom implementation of a filter-like function",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.outline
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Original Data
            InfoSection(title = "Input Data", content = nums.joinToString(", "))

            Spacer(modifier = Modifier.height(16.dp))

            // Even Numbers Test
            ResultCard(
                title = "Predicate: { it % 2 == 0 }",
                description = "Extracting even numbers",
                results = evenNumbers,
                accentColor = Color(0xFF4CAF50) // Green
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Greater Than 3 Test
            ResultCard(
                title = "Predicate: { it > 3 }",
                description = "Numbers greater than 3",
                results = greaterThanThree,
                accentColor = Color(0xFF2196F3) // Blue
            )
        }
    }
}

@Composable
fun InfoSection(title: String, content: String) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.secondary,
            fontWeight = FontWeight.Bold
        )
        Card(
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Text(
                text = content,
                modifier = Modifier.padding(16.dp),
                style = MaterialTheme.typography.titleLarge,
                letterSpacing = 2.sp
            )
        }
    }
}

@Composable
fun ResultCard(
    title: String,
    description: String,
    results: List<Int>,
    accentColor: Color
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(accentColor, RoundedCornerShape(2.dp))
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
            }
            
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            Divider(modifier = Modifier.padding(vertical = 12.dp))
            
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                results.forEach { num ->
                    ResultBadge(num, accentColor)
                }
            }
        }
    }
}

@Composable
fun ResultBadge(number: Int, color: Color) {
    Surface(
        color = color.copy(alpha = 0.1f),
        shape = RoundedCornerShape(8.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, color.copy(alpha = 0.5f))
    ) {
        Text(
            text = number.toString(),
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Bold,
            color = color
        )
    }
}

@Preview(showBackground = true)
@Composable
fun HigherOrderPreview() {
    MaterialTheme {
        HigherOrderFunctionScreen()
    }
}
