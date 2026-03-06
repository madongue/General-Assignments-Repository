package filtering_and_transforming_with_lambdas

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun FilteringExerciseScreen() {
    val numbers = listOf(1, 4, 7, 3, 9, 2, 8)
    
    val processedNumbers = numbers
        .filter { it > 5 }    
        .map { it * it }      

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Lambda Transformations",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            
            Spacer(modifier = Modifier.height(24.dp))

            DataCard(
                title = "Original Numbers",
                data = numbers,
                color = MaterialTheme.colorScheme.surfaceVariant
            )

            Icon(
                modifier = Modifier.padding(vertical = 8.dp),
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = "Transformation",
                tint = MaterialTheme.colorScheme.secondary
            )

            val filtered = numbers.filter { it > 5 }
            DataCard(
                title = "Filtered (it > 5)",
                data = filtered,
                color = MaterialTheme.colorScheme.secondaryContainer
            )

            Icon(
                modifier = Modifier.padding(vertical = 8.dp),
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = "Transformation",
                tint = MaterialTheme.colorScheme.secondary
            )

            DataCard(
                title = "Final Result (Squared)",
                data = processedNumbers,
                color = MaterialTheme.colorScheme.primaryContainer,
                isHighlight = true
            )

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = "Processed Results:",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.align(Alignment.Start)
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(processedNumbers) { item ->
                    ResultItem(value = item)
                }
            }
        }
    }
}

@Composable
fun DataCard(
    title: String, 
    data: List<Int>, 
    color: Color,
    isHighlight: Boolean = false
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = color),
        elevation = CardDefaults.cardElevation(defaultElevation = if (isHighlight) 4.dp else 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = data.joinToString(", "),
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontSize = 18.sp,
                    letterSpacing = 1.sp
                )
            )
        }
    }
}

@Composable
fun ResultItem(value: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            shape = androidx.compose.foundation.shape.CircleShape,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(8.dp)
        ) {}
        
        Spacer(modifier = Modifier.width(12.dp))
        
        Text(
            text = "Resulting Value: ",
            style = MaterialTheme.typography.bodyMedium
        )
        Text(
            text = value.toString(),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
    }
}
