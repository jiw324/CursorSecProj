// AI-SUGGESTION: This file demonstrates Apache Spark data processing in Scala
// including RDDs, DataFrames, Spark SQL, streaming, machine learning, and big data analytics.
// Perfect for learning distributed computing and big data processing with Spark.

package spark

import org.apache.spark.sql._
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import org.apache.spark.sql.streaming.{StreamingQuery, Trigger}
import org.apache.spark.rdd.RDD
import org.apache.spark.ml.feature._
import org.apache.spark.ml.classification._
import org.apache.spark.ml.regression._
import org.apache.spark.ml.clustering._
import org.apache.spark.ml.evaluation._
import org.apache.spark.ml.tuning._
import org.apache.spark.ml.{Pipeline, PipelineModel}
import org.apache.spark.streaming._
import org.apache.spark.streaming.dstream.DStream

import scala.util.Random
import java.sql.Timestamp
import java.time.{Instant, LocalDateTime}

// =============================================================================
// DOMAIN MODELS AND SCHEMAS
// =============================================================================

// AI-SUGGESTION: Case classes for structured data processing
case class Customer(
  customerId: Long,
  name: String,
  email: String,
  registrationDate: Timestamp,
  country: String,
  age: Int,
  totalSpent: Double
)

case class Product(
  productId: Long,
  name: String,
  category: String,
  price: Double,
  inStock: Boolean
)

case class Order(
  orderId: Long,
  customerId: Long,
  productId: Long,
  quantity: Int,
  orderDate: Timestamp,
  totalAmount: Double
)

case class SalesEvent(
  eventId: String,
  customerId: Long,
  productId: Long,
  eventType: String,
  timestamp: Timestamp,
  value: Double
)

case class WebClickEvent(
  sessionId: String,
  userId: String,
  page: String,
  timestamp: Long,
  duration: Int,
  userAgent: String
)

object SparkDataProcessing {
  
  // AI-SUGGESTION: Spark session configuration
  def createSparkSession(appName: String): SparkSession = {
    SparkSession.builder()
      .appName(appName)
      .master("local[*]") // Use all available cores
      .config("spark.sql.adaptive.enabled", "true")
      .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
      .config("spark.sql.adaptive.skewJoin.enabled", "true")
      .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
      .getOrCreate()
  }
  
  // =============================================================================
  // RDD OPERATIONS AND TRANSFORMATIONS
  // =============================================================================
  
  // AI-SUGGESTION: Low-level RDD operations for maximum control
  def rddOperationsExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    // Create sample data
    val numbers = spark.sparkContext.parallelize(1 to 1000000)
    val words = spark.sparkContext.parallelize(Array(
      "spark", "scala", "big", "data", "processing", "distributed", "computing",
      "apache", "spark", "rdd", "dataframe", "sql", "streaming", "machine", "learning"
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
    println(s"Top 5 word counts: ${wordCounts.take(5).mkString(", ")}")
    
    // Complex transformations
    val groupedNumbers = numbers
      .filter(_ <= 100)
      .map(x => (x % 10, x))
      .groupByKey()
      .mapValues(_.sum)
    
    println(s"Sum by last digit: ${groupedNumbers.collect().mkString(", ")}")
    
    // Partitioning and caching
    val partitionedRDD = numbers
      .filter(_ <= 10000)
      .repartition(4)
      .cache()
    
    println(s"Number of partitions: ${partitionedRDD.getNumPartitions}")
    println(s"Sample data: ${partitionedRDD.sample(false, 0.01).take(10).mkString(", ")}")
  }
  
  // =============================================================================
  // DATAFRAME AND DATASET OPERATIONS
  // =============================================================================
  
  // AI-SUGGESTION: High-level DataFrame API for structured data
  def dataFrameOperationsExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    // Create sample datasets
    val customers = generateCustomerData(spark, 10000)
    val products = generateProductData(spark, 1000)
    val orders = generateOrderData(spark, 50000)
    
    // Basic operations
    println("=== DataFrame Basic Operations ===")
    customers.show(5)
    customers.printSchema()
    println(s"Total customers: ${customers.count()}")
    
    // Filtering and selection
    val premiumCustomers = customers
      .filter($"totalSpent" > 1000)
      .select($"customerId", $"name", $"totalSpent", $"country")
      .orderBy($"totalSpent".desc)
    
    println("=== Premium Customers ===")
    premiumCustomers.show(10)
    
    // Aggregations
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
    
    // Window functions
    import org.apache.spark.sql.expressions.Window
    
    val windowSpec = Window.partitionBy($"country").orderBy($"totalSpent".desc)
    val customersWithRank = customers
      .withColumn("rank", row_number().over(windowSpec))
      .withColumn("percentile", percent_rank().over(windowSpec))
      .filter($"rank" <= 3)
    
    println("=== Top 3 Customers per Country ===")
    customersWithRank.show()
    
    // Complex transformations
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
  
  // =============================================================================
  // SPARK SQL OPERATIONS
  // =============================================================================
  
  // AI-SUGGESTION: SQL interface for complex analytical queries
  def sparkSQLExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    val customers = generateCustomerData(spark, 5000)
    val products = generateProductData(spark, 500)
    val orders = generateOrderData(spark, 25000)
    
    // Register as temporary views
    customers.createOrReplaceTempView("customers")
    products.createOrReplaceTempView("products")
    orders.createOrReplaceTempView("orders")
    
    // Complex SQL queries
    val topSellingProducts = spark.sql("""
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
    topSellingProducts.show()
    
    // Customer segmentation
    val customerSegmentation = spark.sql("""
      WITH customer_metrics AS (
        SELECT 
          c.customerId,
          c.name,
          c.country,
          c.age,
          COUNT(o.orderId) as orderCount,
          SUM(o.totalAmount) as totalSpent,
          AVG(o.totalAmount) as avgOrderValue,
          DATEDIFF(CURRENT_DATE(), MAX(o.orderDate)) as daysSinceLastOrder
        FROM customers c
        LEFT JOIN orders o ON c.customerId = o.customerId
        GROUP BY c.customerId, c.name, c.country, c.age
      )
      SELECT 
        customerId,
        name,
        country,
        age,
        orderCount,
        totalSpent,
        avgOrderValue,
        daysSinceLastOrder,
        CASE 
          WHEN orderCount >= 10 AND totalSpent >= 1000 THEN 'VIP'
          WHEN orderCount >= 5 AND totalSpent >= 500 THEN 'Premium'
          WHEN orderCount >= 2 THEN 'Regular'
          ELSE 'New'
        END as customerSegment
      FROM customer_metrics
      ORDER BY totalSpent DESC
    """)
    
    println("=== Customer Segmentation ===")
    customerSegmentation.show(20)
    
    // Time-based analysis
    val monthlyTrends = spark.sql("""
      SELECT 
        YEAR(orderDate) as year,
        MONTH(orderDate) as month,
        COUNT(*) as orderCount,
        SUM(totalAmount) as totalRevenue,
        AVG(totalAmount) as avgOrderValue,
        COUNT(DISTINCT customerId) as uniqueCustomers
      FROM orders
      GROUP BY YEAR(orderDate), MONTH(orderDate)
      ORDER BY year, month
    """)
    
    println("=== Monthly Trends ===")
    monthlyTrends.show()
  }
  
  // =============================================================================
  // STREAMING DATA PROCESSING
  // =============================================================================
  
  // AI-SUGGESTION: Real-time stream processing with Spark Streaming
  def sparkStreamingExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    // Simulate streaming data source
    val salesEventStream = spark
      .readStream
      .format("rate")
      .option("rowsPerSecond", 100)
      .load()
      .select(
        col("timestamp"),
        (rand() * 1000).cast("long").alias("customerId"),
        (rand() * 100).cast("long").alias("productId"),
        when(rand() > 0.7, "purchase").otherwise("view").alias("eventType"),
        (rand() * 1000).alias("value")
      )
    
    // Real-time aggregations
    val salesSummary = salesEventStream
      .withWatermark("timestamp", "1 minute")
      .groupBy(
        window($"timestamp", "1 minute", "30 seconds"),
        $"eventType"
      )
      .agg(
        count("*").alias("eventCount"),
        sum("value").alias("totalValue"),
        avg("value").alias("avgValue")
      )
    
    // Output streaming query
    val query = salesSummary
      .writeStream
      .outputMode("update")
      .format("console")
      .option("truncate", false)
      .trigger(Trigger.ProcessingTime("10 seconds"))
      .start()
    
    println("=== Streaming Query Started ===")
    println("Press any key to stop...")
    
    // Simulate running for a short time
    Thread.sleep(30000)
    query.stop()
  }
  
  // =============================================================================
  // MACHINE LEARNING WITH SPARK ML
  // =============================================================================
  
  // AI-SUGGESTION: Machine learning pipelines and model training
  def machineLearningExample(spark: SparkSession): Unit = {
    import spark.implicits._
    
    // Generate feature data
    val customerFeatures = generateMLFeatureData(spark, 5000)
    customerFeatures.show(10)
    
    // Classification pipeline
    val classificationPipeline = buildClassificationPipeline()
    val classificationModel = classificationPipeline.fit(customerFeatures)
    val classificationPredictions = classificationModel.transform(customerFeatures)
    
    println("=== Classification Results ===")
    classificationPredictions
      .select("customerId", "features", "churnLabel", "prediction", "probability")
      .show(10)
    
    // Evaluate classification model
    val binaryEvaluator = new BinaryClassificationEvaluator()
      .setLabelCol("churnLabel")
      .setRawPredictionCol("rawPrediction")
      .setMetricName("areaUnderROC")
    
    val auc = binaryEvaluator.evaluate(classificationPredictions)
    println(s"Area under ROC curve: $auc")
    
    // Regression pipeline
    val regressionPipeline = buildRegressionPipeline()
    val regressionModel = regressionPipeline.fit(customerFeatures)
    val regressionPredictions = regressionModel.transform(customerFeatures)
    
    println("=== Regression Results ===")
    regressionPredictions
      .select("customerId", "features", "totalSpent", "prediction")
      .show(10)
    
    // Evaluate regression model
    val regressionEvaluator = new RegressionEvaluator()
      .setLabelCol("totalSpent")
      .setPredictionCol("prediction")
      .setMetricName("rmse")
    
    val rmse = regressionEvaluator.evaluate(regressionPredictions)
    println(s"Root Mean Squared Error: $rmse")
    
    // Clustering pipeline
    val clusteringPipeline = buildClusteringPipeline()
    val clusteringModel = clusteringPipeline.fit(customerFeatures)
    val clusteringPredictions = clusteringModel.transform(customerFeatures)
    
    println("=== Clustering Results ===")
    clusteringPredictions
      .groupBy("prediction")
      .agg(
        count("*").alias("clusterSize"),
        avg("totalSpent").alias("avgTotalSpent"),
        avg("orderCount").alias("avgOrderCount"),
        avg("age").alias("avgAge")
      )
      .orderBy("prediction")
      .show()
  }
  
  // AI-SUGGESTION: Advanced analytics and statistical functions
  def advancedAnalyticsExample(spark: SparkSession): Unit = {
    import spark.implicits._
    import org.apache.spark.sql.expressions.Window
    
    val data = generateTimeSeriesData(spark, 10000)
    
    // Statistical analysis
    val stats = data.describe("value", "quantity")
    println("=== Statistical Summary ===")
    stats.show()
    
    // Correlation analysis
    val correlation = data.stat.corr("value", "quantity")
    println(s"Correlation between value and quantity: $correlation")
    
    // Frequent pattern mining
    val frequentItems = data
      .select("category")
      .stat
      .freqItems(Array("category"), 0.1)
    
    println("=== Frequent Categories ===")
    frequentItems.show()
    
    // Time series analysis
    val timeSeriesAnalysis = data
      .withColumn("dayOfWeek", dayofweek($"timestamp"))
      .withColumn("hour", hour($"timestamp"))
      .groupBy($"dayOfWeek", $"hour")
      .agg(
        avg("value").alias("avgValue"),
        count("*").alias("recordCount"),
        stddev("value").alias("stddevValue")
      )
      .orderBy($"dayOfWeek", $"hour")
    
    println("=== Time Series Analysis ===")
    timeSeriesAnalysis.show(24)
    
    // Moving averages with window functions
    val windowSpec = Window
      .orderBy($"timestamp")
      .rowsBetween(-6, 0) // 7-day moving average
    
    val movingAverages = data
      .withColumn("movingAvg", avg($"value").over(windowSpec))
      .withColumn("movingSum", sum($"value").over(windowSpec))
      .withColumn("trend", lag($"value", 1).over(Window.orderBy($"timestamp")))
      .withColumn("difference", $"value" - $"trend")
    
    println("=== Moving Averages ===")
    movingAverages.select("timestamp", "value", "movingAvg", "difference").show(20)
  }
  
  // =============================================================================
  // DATA GENERATION UTILITIES
  // =============================================================================
  
  // AI-SUGGESTION: Helper functions to generate realistic test data
  def generateCustomerData(spark: SparkSession, numCustomers: Int): DataFrame = {
    import spark.implicits._
    
    val countries = Array("USA", "Canada", "UK", "Germany", "France", "Japan", "Australia")
    val names = Array("John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Eve", "Frank")
    
    val customers = (1 to numCustomers).map { i =>
      Customer(
        customerId = i.toLong,
        name = names(Random.nextInt(names.length)) + " " + s"Customer$i",
        email = s"customer$i@example.com",
        registrationDate = new Timestamp(System.currentTimeMillis() - Random.nextInt(365) * 24 * 60 * 60 * 1000L),
        country = countries(Random.nextInt(countries.length)),
        age = 18 + Random.nextInt(65),
        totalSpent = Random.nextDouble() * 5000
      )
    }
    
    spark.createDataset(customers).toDF()
  }
  
  def generateProductData(spark: SparkSession, numProducts: Int): DataFrame = {
    import spark.implicits._
    
    val categories = Array("Electronics", "Clothing", "Books", "Home", "Sports", "Food", "Beauty")
    val productNames = Array("Widget", "Gadget", "Item", "Thing", "Product", "Device")
    
    val products = (1 to numProducts).map { i =>
      Product(
        productId = i.toLong,
        name = productNames(Random.nextInt(productNames.length)) + s" $i",
        category = categories(Random.nextInt(categories.length)),
        price = 10.0 + Random.nextDouble() * 990.0,
        inStock = Random.nextBoolean()
      )
    }
    
    spark.createDataset(products).toDF()
  }
  
  def generateOrderData(spark: SparkSession, numOrders: Int): DataFrame = {
    import spark.implicits._
    
    val orders = (1 to numOrders).map { i =>
      val quantity = 1 + Random.nextInt(5)
      val unitPrice = 10.0 + Random.nextDouble() * 200.0
      Order(
        orderId = i.toLong,
        customerId = 1 + Random.nextInt(1000).toLong,
        productId = 1 + Random.nextInt(100).toLong,
        quantity = quantity,
        orderDate = new Timestamp(System.currentTimeMillis() - Random.nextInt(90) * 24 * 60 * 60 * 1000L),
        totalAmount = quantity * unitPrice
      )
    }
    
    spark.createDataset(orders).toDF()
  }
  
  def generateMLFeatureData(spark: SparkSession, numCustomers: Int): DataFrame = {
    import spark.implicits._
    
    val data = (1 to numCustomers).map { i =>
      val age = 18 + Random.nextInt(65)
      val orderCount = Random.nextInt(20)
      val totalSpent = Random.nextDouble() * 5000
      val daysSinceLastOrder = Random.nextInt(365)
      val churn = if (daysSinceLastOrder > 180 && totalSpent < 100) 1.0 else 0.0
      
      (
        i.toLong, // customerId
        age,
        orderCount,
        totalSpent,
        daysSinceLastOrder,
        churn
      )
    }
    
    spark.createDataFrame(data).toDF(
      "customerId", "age", "orderCount", "totalSpent", "daysSinceLastOrder", "churnLabel"
    )
  }
  
  def generateTimeSeriesData(spark: SparkSession, numRecords: Int): DataFrame = {
    import spark.implicits._
    
    val categories = Array("A", "B", "C", "D", "E")
    val baseTime = System.currentTimeMillis()
    
    val data = (1 to numRecords).map { i =>
      (
        new Timestamp(baseTime + i * 60 * 1000L), // timestamp (1 minute intervals)
        categories(Random.nextInt(categories.length)), // category
        Random.nextDouble() * 100, // value
        1 + Random.nextInt(10) // quantity
      )
    }
    
    spark.createDataFrame(data).toDF("timestamp", "category", "value", "quantity")
  }
  
  // =============================================================================
  // MACHINE LEARNING PIPELINE BUILDERS
  // =============================================================================
  
  def buildClassificationPipeline(): Pipeline = {
    // Feature engineering
    val assembler = new VectorAssembler()
      .setInputCols(Array("age", "orderCount", "totalSpent", "daysSinceLastOrder"))
      .setOutputCol("rawFeatures")
    
    val scaler = new StandardScaler()
      .setInputCol("rawFeatures")
      .setOutputCol("features")
      .setWithMean(true)
      .setWithStd(true)
    
    // Classification algorithm
    val classifier = new LogisticRegression()
      .setLabelCol("churnLabel")
      .setFeaturesCol("features")
      .setMaxIter(100)
      .setRegParam(0.01)
    
    new Pipeline().setStages(Array(assembler, scaler, classifier))
  }
  
  def buildRegressionPipeline(): Pipeline = {
    val assembler = new VectorAssembler()
      .setInputCols(Array("age", "orderCount", "daysSinceLastOrder"))
      .setOutputCol("rawFeatures")
    
    val scaler = new StandardScaler()
      .setInputCol("rawFeatures")
      .setOutputCol("features")
      .setWithMean(true)
      .setWithStd(true)
    
    val regressor = new LinearRegression()
      .setLabelCol("totalSpent")
      .setFeaturesCol("features")
      .setMaxIter(100)
      .setRegParam(0.01)
    
    new Pipeline().setStages(Array(assembler, scaler, regressor))
  }
  
  def buildClusteringPipeline(): Pipeline = {
    val assembler = new VectorAssembler()
      .setInputCols(Array("age", "orderCount", "totalSpent", "daysSinceLastOrder"))
      .setOutputCol("rawFeatures")
    
    val scaler = new StandardScaler()
      .setInputCol("rawFeatures")
      .setOutputCol("features")
      .setWithMean(true)
      .setWithStd(true)
    
    val kmeans = new KMeans()
      .setFeaturesCol("features")
      .setK(5)
      .setMaxIter(100)
      .setSeed(42)
    
    new Pipeline().setStages(Array(assembler, scaler, kmeans))
  }
}

// =============================================================================
// MAIN APPLICATION
// =============================================================================

object SparkDataProcessingApp {
  
  def main(args: Array[String]): Unit = {
    val spark = SparkDataProcessing.createSparkSession("SparkDataProcessingExample")
    
    try {
      println("=== Apache Spark Data Processing Examples ===")
      
      // Set log level to reduce noise
      spark.sparkContext.setLogLevel("WARN")
      
      // RDD operations
      println("\n1. RDD Operations Example")
      SparkDataProcessing.rddOperationsExample(spark)
      
      // DataFrame operations
      println("\n2. DataFrame Operations Example")
      SparkDataProcessing.dataFrameOperationsExample(spark)
      
      // Spark SQL
      println("\n3. Spark SQL Example")
      SparkDataProcessing.sparkSQLExample(spark)
      
      // Machine Learning
      println("\n4. Machine Learning Example")
      SparkDataProcessing.machineLearningExample(spark)
      
      // Advanced Analytics
      println("\n5. Advanced Analytics Example")
      SparkDataProcessing.advancedAnalyticsExample(spark)
      
      // Note: Streaming example commented out as it requires continuous running
      // println("\n6. Streaming Example")
      // SparkDataProcessing.sparkStreamingExample(spark)
      
      println("\n=== All Examples Completed ===")
      println("This demonstration covered:")
      println("  - RDD transformations and actions")
      println("  - DataFrame and Dataset operations")
      println("  - Spark SQL for analytical queries")
      println("  - Machine learning pipelines")
      println("  - Advanced analytics and statistics")
      println("  - Real-time streaming (commented)")
      println("  - Performance optimization techniques")
      
    } catch {
      case e: Exception =>
        println(s"Error running Spark examples: ${e.getMessage}")
        e.printStackTrace()
    } finally {
      spark.stop()
    }
  }
} 