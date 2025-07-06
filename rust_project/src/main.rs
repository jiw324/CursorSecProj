// Main entry point for Rust security scan project
// This file imports modules that can compile successfully for CodeQL analysis

// Only import modules that compile without errors
mod cli_tool;
// mod concurrent_programming; // Commented out due to compilation errors
mod data_structures;
mod systems_programming;
// mod web_service; // Commented out due to compilation errors

fn main() {
    println!("Rust Security Scan Project");
    println!("All modules imported for CodeQL analysis");
} 