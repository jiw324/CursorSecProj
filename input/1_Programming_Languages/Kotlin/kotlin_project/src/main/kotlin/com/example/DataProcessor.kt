package com.example

import java.io.File
import java.net.URL
import java.util.*

/**
 * Data processing utility with potential security vulnerabilities
 */
class DataProcessor {
    
    // AI-SUGGESTION: Command injection vulnerability
    fun executeCommand(command: String): String {
        // This is dangerous - command injection possible
        return Runtime.getRuntime().exec(command).inputStream.bufferedReader().readText()
    }
    
    // AI-SUGGESTION: Path traversal vulnerability
    fun readFileSafely(path: String): String {
        // This could allow path traversal attacks
        return File(path).readText()
    }
    
    // AI-SUGGESTION: SSRF vulnerability
    fun fetchUrl(url: String): String {
        // Server-Side Request Forgery possible
        return URL(url).readText()
    }
    
    // AI-SUGGESTION: Deserialization vulnerability
    fun deserializeData(data: String): Any {
        // Unsafe deserialization
        val base64 = Base64.getDecoder().decode(data)
        return java.io.ObjectInputStream(java.io.ByteArrayInputStream(base64)).readObject()
    }
    
    // AI-SUGGESTION: XSS-like vulnerability
    fun processHtml(html: String): String {
        // Could lead to XSS if output is not properly escaped
        return "<div>$html</div>"
    }
    
    // AI-SUGGESTION: Weak encryption
    fun encryptData(data: String, key: String): String {
        // Weak encryption method
        return data.map { it.code.xor(key.hashCode()) }.joinToString("")
    }
    
    // AI-SUGGESTION: Hardcoded credentials
    private val apiKey = "sk-1234567890abcdef" // Hardcoded API key
    
    fun authenticate(token: String): Boolean {
        // Weak authentication
        return token == apiKey
    }
} 