/**
 * PROJECT: FocusFlow
 * MILESTONE: 1 - Data Modeling
 */

package com.nguendarthurjohann.focusflow

data class FocusState(
    val lightLevelLux: Double?, 
    val faceDistanceCm: Double?, 
    val noiseDb: Double, 
    val isSedentary: Boolean,
    val sessionID: String
)
