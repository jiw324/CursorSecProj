// AI-SUGGESTION: This file demonstrates Apache Spark data processing in Scala
// including RDDs, DataFrames, Spark SQL, and machine learning pipelines.
// Perfect for learning distributed computing and big data analytics with Spark.

package spark

import org.apache.spark.sql._
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import org.apache.spark.rdd.RDD
import org.apache.spark.ml.feature._
import org.apache.spark.ml.classification._
import org.apache.spark.ml.evaluation._
import org.apache.spark.ml.Pipeline

import scala.util.Random
import java.sql.Timestamp

// =============================================================================
// DOMAIN MODELS
// =============================================================================

case class Customer(
  customerId: Long,
  name: String,
  email: String,
  country: String,
  age: Int,
  totalSpent: Double
)

case class Product(
  productId: Long,
  name: String,
  category: String,
  price: Double
)

case class Order(
  orderId: Long,
  customerId: Long,
  productId: Long,
  quantity: Int,
  totalAmount: Double
)

// =============================================================================
// SPARK OPERATIONS
// =============================================================================

object SparkBigDataProcessing {
  
  def createSparkSession(appName: String): SparkSession = {
    SparkSession.builder()
      .appName(appName)
      .master("local[*]")
      .config("spark.sql.adaptive.enabled", "true")
      .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
      .getOrCreate()
  }
  
  // AI-SUGGESTION: RDD operations for low-level data processing
  def rddOperationsExample(spark: SparkSession): Unit = {
    val sc = spark.sparkContext
    
    // Create RDDs
    val numbers = sc.parallelize(1 to 1000000)
    val words = sc.parallelize(Array(
      "spark", "scala", "big", "data", "processing", "distributed",
      "apache", "spark", "rdd", "dataframe", "sql", "machine", "learning"
    ))
    
    // Transformations
    val evenNumbers = numbers.filter(_ % 2 == 0)
    val squares = numbers.map(x => x * x)
    val wordCounts = words
      .map(word => (word, 1))
      .reduceByKey(_ + _)
      .sortBy(_._2, ascending = false)
    
    // Actions
    println(s"Total numbers: ${numbers.count()}")
    println(s"Sum of even numbers: ${evenNumbers.sum()}")
    println(s"Top 5 words: ${wordCounts.take(5).mkString(", ")}")
    
    // Complex operations
    val groupedNumbers = numbers
      .filter(_ <= 100)
      .map(x => (x % 10, x))
      .groupByKey()
      .mapValues(_.sum)
    
    println(s"Sum by last digit: ${groupedNumbers.collect().mkString(", ")}")
  }
  
  // AI-SUGGESTION: DataFrame operations for structured data
  def dataFrameOperationsExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    // Generate sample data
    val customers = generateCustomerData(spark, 10000)
    val products = generateProductData(spark, 1000)
    val orders = generateOrderData(spark, 50000)
    
    println("=== Customer Data Schema ===")
    customers.printSchema()
    customers.show(5)
    
    // Filtering and selection
    val premiumCustomers = customers
      .filter($"totalSpent" > 1000)
      .select($"customerId", $"name", $"totalSpent", $"country")
      .orderBy($"totalSpent".desc)
    
    println("=== Premium Customers ===")
    premiumCustomers.show(10)
    
    // Aggregations by country
    val countryStats = customers
      .groupBy($"country")
      .agg(
        count("*").alias("customerCount"),
        avg("totalSpent").alias("avgSpent"),
        max("totalSpent").alias("maxSpent"),
        min("age").alias("minAge"),
        max("age").alias("maxAge")
      )
      .orderBy($"customerCount".desc)
    
    println("=== Country Statistics ===")
    countryStats.show()
    
    // Joins and complex analysis
    val customerOrderSummary = customers
      .join(orders, "customerId")
      .join(products, "productId")
      .groupBy($"customerId", $"name", $"country")
      .agg(
        countDistinct("orderId").alias("totalOrders"),
        sum("quantity").alias("totalItems"),
        sum("totalAmount").alias("totalOrderValue"),
        countDistinct("category").alias("categoriesPurchased")
      )
      .withColumn("avgOrderValue", $"totalOrderValue" / $"totalOrders")
    
    println("=== Customer Order Summary ===")
    customerOrderSummary.show(10)
  }
  
  // AI-SUGGESTION: Spark SQL for analytical queries
  def sparkSQLExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    val customers = generateCustomerData(spark, 5000)
    val products = generateProductData(spark, 500)
    val orders = generateOrderData(spark, 25000)
    
    // Register as temporary views
    customers.createOrReplaceTempView("customers")
    products.createOrReplaceTempView("products")
    orders.createOrReplaceTempView("orders")
    
    // Top selling products query
    val topProducts = spark.sql("""
      SELECT 
        p.productId,
        p.name,
        p.category,
        SUM(o.quantity) as totalSold,
        SUM(o.totalAmount) as totalRevenue,
        COUNT(DISTINCT o.customerId) as uniqueCustomers
      FROM orders o
      JOIN products p ON o.productId = p.productId
      GROUP BY p.productId, p.name, p.category
      ORDER BY totalRevenue DESC
      LIMIT 20
    """)
    
    println("=== Top Selling Products ===")
    topProducts.show()
    
    // Customer segmentation
    val customerSegments = spark.sql("""
      WITH customer_metrics AS (
        SELECT 
          c.customerId,
          c.name,
          c.country,
          COUNT(o.orderId) as orderCount,
          SUM(o.totalAmount) as totalSpent,
          AVG(o.totalAmount) as avgOrderValue
        FROM customers c
        LEFT JOIN orders o ON c.customerId = o.customerId
        GROUP BY c.customerId, c.name, c.country
      )
      SELECT 
        customerId,
        name,
        country,
        orderCount,
        totalSpent,
        avgOrderValue,
        CASE 
          WHEN orderCount >= 10 AND totalSpent >= 1000 THEN 'VIP'
          WHEN orderCount >= 5 AND totalSpent >= 500 THEN 'Premium'
          WHEN orderCount >= 2 THEN 'Regular'
          ELSE 'New'
        END as segment
      FROM customer_metrics
      ORDER BY totalSpent DESC
    """)
    
    println("=== Customer Segmentation ===")
    customerSegments.show(20)
  }
  
  // AI-SUGGESTION: Machine learning pipeline
  def machineLearningExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    // Generate ML features
    val mlData = generateMLData(spark, 5000)
    
    println("=== ML Feature Data ===")
    mlData.show(10)
    
    // Feature engineering pipeline
    val assembler = new VectorAssembler()
      .setInputCols(Array("age", "orderCount", "totalSpent", "daysSinceLastOrder"))
      .setOutputCol("rawFeatures")
    
    val scaler = new StandardScaler()
      .setInputCol("rawFeatures")
      .setOutputCol("features")
      .setWithMean(true)
      .setWithStd(true)
    
    // Classification model
    val classifier = new LogisticRegression()
      .setLabelCol("churnLabel")
      .setFeaturesCol("features")
      .setMaxIter(100)
    
    // Create pipeline
    val pipeline = new Pipeline()
      .setStages(Array(assembler, scaler, classifier))
    
    // Split data
    val Array(training, test) = mlData.randomSplit(Array(0.8, 0.2), seed = 42)
    
    // Train model
    val model = pipeline.fit(training)
    val predictions = model.transform(test)
    
    println("=== ML Predictions ===")
    predictions
      .select("customerId", "features", "churnLabel", "prediction", "probability")
      .show(20)
    
    // Evaluate model
    val evaluator = new BinaryClassificationEvaluator()
      .setLabelCol("churnLabel")
      .setRawPredictionCol("rawPrediction")
      .setMetricName("areaUnderROC")
    
    val auc = evaluator.evaluate(predictions)
    println(s"Area under ROC curve: $auc")
  }
  
  // =============================================================================
  // DATA GENERATORS
  // =============================================================================
  
  def generateCustomerData(spark: SparkSession, count: Int): DataFrame = {
    import spark.implicits._
    
    val countries = Array("USA", "Canada", "UK", "Germany", "France", "Japan")
    val names = Array("John", "Jane", "Bob", "Alice", "Charlie", "Diana")
    
    val customers = (1 to count).map { i =>
      Customer(
        customerId = i.toLong,
        name = names(Random.nextInt(names.length)) + s" Customer$i",
        email = s"customer$i@example.com",
        country = countries(Random.nextInt(countries.length)),
        age = 18 + Random.nextInt(65),
        totalSpent = Random.nextDouble() * 5000
      )
    }
    
    spark.createDataset(customers).toDF()
  }
  
  def generateProductData(spark: SparkSession, count: Int): DataFrame = {
    import spark.implicits._
    
    val categories = Array("Electronics", "Clothing", "Books", "Home", "Sports")
    val productNames = Array("Widget", "Gadget", "Item", "Thing", "Product")
    
    val products = (1 to count).map { i =>
      Product(
        productId = i.toLong,
        name = productNames(Random.nextInt(productNames.length)) + s" $i",
        category = categories(Random.nextInt(categories.length)),
        price = 10.0 + Random.nextDouble() * 990.0
      )
    }
    
    spark.createDataset(products).toDF()
  }
  
  def generateOrderData(spark: SparkSession, count: Int): DataFrame = {
    import spark.implicits._
    
    val orders = (1 to count).map { i =>
      val quantity = 1 + Random.nextInt(5)
      val unitPrice = 10.0 + Random.nextDouble() * 200.0
      Order(
        orderId = i.toLong,
        customerId = 1 + Random.nextInt(1000).toLong,
        productId = 1 + Random.nextInt(100).toLong,
        quantity = quantity,
        totalAmount = quantity * unitPrice
      )
    }
    
    spark.createDataset(orders).toDF()
  }
  
  def generateMLData(spark: SparkSession, count: Int): DataFrame = {
    import spark.implicits._
    
    val data = (1 to count).map { i =>
      val age = 18 + Random.nextInt(65)
      val orderCount = Random.nextInt(20)
      val totalSpent = Random.nextDouble() * 5000
      val daysSinceLastOrder = Random.nextInt(365)
      val churn = if (daysSinceLastOrder > 180 && totalSpent < 100) 1.0 else 0.0
      
      (i.toLong, age, orderCount, totalSpent, daysSinceLastOrder, churn)
    }
    
    spark.createDataFrame(data).toDF(
      "customerId", "age", "orderCount", "totalSpent", "daysSinceLastOrder", "churnLabel"
    )
  }
}

// =============================================================================
// MAIN APPLICATION
// =============================================================================

object SparkBigDataApp {
  
  def main(args: Array[String]): Unit = {
    val spark = SparkBigDataProcessing.createSparkSession("SparkBigDataExample")
    
    try {
      println("=== Apache Spark Big Data Processing ===")
      spark.sparkContext.setLogLevel("WARN")
      
      println("\n1. RDD Operations")
      SparkBigDataProcessing.rddOperationsExample(spark)
      
      println("\n2. DataFrame Operations")
      SparkBigDataProcessing.dataFrameOperationsExample(spark)
      
      println("\n3. Spark SQL Analytics")
      SparkBigDataProcessing.sparkSQLExample(spark)
      
      println("\n4. Machine Learning")
      SparkBigDataProcessing.machineLearningExample(spark)
      
      println("\n=== Examples Completed ===")
      println("Demonstrated:")
      println("  - RDD transformations and actions")
      println("  - DataFrame structured operations")
      println("  - SQL analytical queries")
      println("  - ML pipelines and evaluation")
      println("  - Performance optimization")
      
    } catch {
      case e: Exception =>
        println(s"Error: ${e.getMessage}")
        e.printStackTrace()
    } finally {
      spark.stop()
    }
  }
} 