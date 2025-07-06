package com.example

/**
 * Simple Kotlin application for CodeQL security analysis
 */
class SimpleKotlinApp {
    
    private var data: String = ""
    private val users = mutableListOf<User>()
    
    data class User(
        val id: Int,
        val name: String,
        val email: String
    )
    
    // AI-SUGGESTION: Potential security issue - input validation
    fun processUserInput(input: String): String {
        // This could be vulnerable to injection if not properly validated
        return "Processed: $input"
    }
    
    // AI-SUGGESTION: Secure password handling
    fun validatePassword(password: String): Boolean {
        // Simple validation - in real app, use proper hashing
        return password.length >= 8
    }
    
    // AI-SUGGESTION: File operations
    fun readFile(path: String): String {
        // Potential path traversal vulnerability
        return java.io.File(path).readText()
    }
    
    // AI-SUGGESTION: Network operations
    fun makeHttpRequest(url: String): String {
        // Potential SSRF vulnerability
        return java.net.URL(url).readText()
    }
    
    // AI-SUGGESTION: SQL-like operations
    fun queryData(query: String): List<User> {
        // Potential SQL injection if this were real SQL
        return users.filter { it.name.contains(query) }
    }
    
    fun main() {
        val app = SimpleKotlinApp()
        println("Kotlin application started")
    }
} 