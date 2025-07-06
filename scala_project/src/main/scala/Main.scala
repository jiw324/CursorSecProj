// Main entry point for Scala security scan project
// This file imports all modules to ensure they are compiled and analyzed

object Main {
  def main(args: Array[String]): Unit = {
    println("Scala Security Scan Project")
    println("All modules imported for CodeQL analysis")
    
    // Import all modules to ensure they are compiled
    // This is just for CodeQL analysis - the actual functionality
    // is in the individual files
    
    // The following imports ensure all files are part of the build
    // but don't actually execute any code
    try {
      // These are just to ensure the files are compiled
      val _ = new akka_actor_system.ActorSystemDemo()
      val _ = new cats_zio_effects.EffectsDemo()
      val _ = new cats_zio_functional_effects.FunctionalEffectsDemo()
      val _ = new functional_programming_patterns.FunctionalPatternsDemo()
      val _ = new play_web_application.PlayWebAppDemo()
      val _ = new spark_big_data.SparkBigDataDemo()
      val _ = new spark_data_processing.SparkDataProcessingDemo()
    } catch {
      case _: Exception => 
        // Ignore exceptions - this is just for compilation
        println("Modules loaded for analysis")
    }
  }
} 