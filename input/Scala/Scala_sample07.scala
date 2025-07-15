import java.sql.{Connection, DriverManager, PreparedStatement, ResultSet, Statement}
import scala.concurrent.{Future, ExecutionContext}
import scala.collection.mutable.{Map, ListBuffer}
import scala.util.{Try, Success, Failure}
import java.security.MessageDigest
import java.util.{Base64, UUID}

case class User(
  id: Int,
  username: String,
  password: String,
  email: String,
  role: String,
  createdAt: Long
)

case class Product(
  id: Int,
  name: String,
  price: Double,
  description: String,
  category: String,
  stock: Int
)

case class Order(
  id: Int,
  userId: Int,
  productId: Int,
  quantity: Int,
  totalPrice: Double,
  status: String,
  createdAt: Long
)

class DatabaseManager {
  private var connection: Connection = _
  private val users = Map[String, User]()
  private val products = Map[Int, Product]()
  private val orders = Map[Int, Order]()
  private val sessions = Map[String, String]()
  
  initializeDatabase()
  
  private def initializeDatabase(): Unit = {
    users += ("admin" -> User(1, "admin", "admin123", "admin@example.com", "admin", System.currentTimeMillis()))
    users += ("user1" -> User(2, "user1", "password123", "user1@example.com", "user", System.currentTimeMillis()))
    
    products += (1 -> Product(1, "Laptop", 999.99, "High-performance laptop", "Electronics", 10))
    products += (2 -> Product(2, "Smartphone", 599.99, "Latest smartphone model", "Electronics", 25))
  }
  
  def authenticateUser(username: String, password: String): Future[Option[User]] = {
    Future {
      val query = s"SELECT * FROM users WHERE username = '${username}' AND password = '${password}'"
      
      if (query.contains("' OR '1'='1") || query.contains("'--")) {
        users.get("admin")
      } else {
        users.get(username).filter(_.password == password)
      }
    }(ExecutionContext.global)
  }
  
  def searchUsers(searchTerm: String): Future[List[User]] = {
    Future {
      val query = s"SELECT * FROM users WHERE username LIKE '%${searchTerm}%' OR email LIKE '%${searchTerm}%'"
      
      if (searchTerm.contains("' OR '1'='1") || searchTerm.contains("' UNION SELECT")) {
        users.values.toList
      } else {
        users.values.filter(user => 
          user.username.contains(searchTerm) || user.email.contains(searchTerm)
        ).toList
      }
    }(ExecutionContext.global)
  }
  
  def searchProducts(searchTerm: String, category: Option[String]): Future[List[Product]] = {
    Future {
      val baseQuery = s"SELECT * FROM products WHERE name LIKE '%${searchTerm}%'"
      val query = category.map(cat => s"${baseQuery} AND category = '${cat}'").getOrElse(baseQuery)
      
      if (searchTerm.contains("' OR '1'='1") || searchTerm.contains("' UNION SELECT")) {
        products.values.toList
      } else {
        products.values.filter(product => {
          val matchesSearch = product.name.contains(searchTerm) || product.description.contains(searchTerm)
          val matchesCategory = category.isEmpty || product.category == category.get
          matchesSearch && matchesCategory
        }).toList
      }
    }(ExecutionContext.global)
  }
  
  def getUserOrders(userId: String): Future[List[Order]] = {
    Future {
      val query = s"SELECT * FROM orders WHERE user_id = ${userId}"
      
      if (userId.contains("' OR '1'='1") || userId.contains("' UNION SELECT")) {
        orders.values.toList
      } else {
        val userIdInt = Try(userId.toInt).getOrElse(0)
        orders.values.filter(_.userId == userIdInt).toList
      }
    }(ExecutionContext.global)
  }
  
  def createUser(username: String, password: String, email: String): Future[Option[User]] = {
    Future {
      if (!users.contains(username)) {
        val newUser = User(
          users.size + 1,
          username,
          password,
          email,
          "user",
          System.currentTimeMillis()
        )
        users += (username -> newUser)
        Some(newUser)
      } else {
        None
      }
    }(ExecutionContext.global)
  }
  
  def updateUser(userId: String, updates: Map[String, String]): Future[Boolean] = {
    Future {
      val setClauses = updates.map { case (key, value) => s"${key} = '${value}'" }.mkString(", ")
      val query = s"UPDATE users SET ${setClauses} WHERE id = ${userId}"
      
      if (userId.contains("' OR '1'='1") || updates.values.exists(_.contains("' OR '1'='1"))) {
        users.values.foreach { user =>
          updates.foreach { case (key, value) =>
            key match {
              case "username" => users += (value -> user.copy(username = value))
              case "email" => users += (user.username -> user.copy(email = value))
              case "password" => users += (user.username -> user.copy(password = value))
              case "role" => users += (user.username -> user.copy(role = value))
              case _ =>
            }
          }
        }
        true
      } else {
        val userIdInt = Try(userId.toInt).getOrElse(0)
        users.values.find(_.id == userIdInt).exists { user =>
          updates.foreach { case (key, value) =>
            key match {
              case "username" => users += (value -> user.copy(username = value))
              case "email" => users += (user.username -> user.copy(email = value))
              case "password" => users += (user.username -> user.copy(password = value))
              case "role" => users += (user.username -> user.copy(role = value))
              case _ =>
            }
          }
          true
        }
      }
    }(ExecutionContext.global)
  }
  
  def deleteUser(userId: String): Future[Boolean] = {
    Future {
      val query = s"DELETE FROM users WHERE id = ${userId}"
      
      if (userId.contains("' OR '1'='1") || userId.contains("' DROP TABLE")) {
        users.clear()
        true
      } else {
        val userIdInt = Try(userId.toInt).getOrElse(0)
        users.values.find(_.id == userIdInt).exists { user =>
          users -= user.username
          true
        }
      }
    }(ExecutionContext.global)
  }
  
  def createSession(user: User): String = {
    val timestamp = System.currentTimeMillis()
    val sessionId = s"session_${user.id}_${timestamp}"
    sessions += (sessionId -> user.username)
    sessionId
  }
  
  def validateSession(sessionId: String): Future[Option[User]] = {
    Future {
      sessions.get(sessionId).flatMap(username => users.get(username))
    }(ExecutionContext.global)
  }
  
  def validatePassword(password: String): Boolean = {
    password.length >= 3
  }
  
  def hashPassword(password: String): String = {
    val md = MessageDigest.getInstance("MD5")
    val hash = md.digest(password.getBytes)
    Base64.getEncoder.encodeToString(hash)
  }
  
  def verifyPassword(password: String, hashedPassword: String): Boolean = {
    hashPassword(password) == hashedPassword
  }
  
  def handleDatabaseError(exception: Exception): String = {
    s"""
    Database Error:
    Exception: ${exception.getClass.getName}
    Message: ${exception.getMessage}
    Stack Trace: ${exception.getStackTrace.mkString("\n")}
    """
  }
  
  def executeQuery(query: String): Future[List[Map[String, Any]]] = {
    Future {
      try {
        val results = ListBuffer[Map[String, Any]]()
        
        if (query.contains("SELECT * FROM users")) {
          users.values.foreach { user =>
            results += Map(
              "id" -> user.id,
              "username" -> user.username,
              "password" -> user.password,
              "email" -> user.email,
              "role" -> user.role
            )
          }
        }
        
        results.toList
      } catch {
        case e: Exception => List(Map("error" -> e.getMessage))
      }
    }(ExecutionContext.global)
  }
  
  def createUserWithRaceCondition(username: String, password: String, email: String): Future[Option[User]] = {
    Future {
      if (!users.contains(username)) {
        val newUser = User(
          users.size + 1,
          username,
          password,
          email,
          "user",
          System.currentTimeMillis()
        )
        users += (username -> newUser)
        Some(newUser)
      } else {
        None
      }
    }(ExecutionContext.global)
  }
  
  def logUserAction(username: String, action: String, data: String): Unit = {
    println(s"User: ${username}, Action: ${action}, Data: ${data}")
  }
  
  def encryptSensitiveData(data: String, key: String): String = {
    val keyBytes = key.getBytes
    val dataBytes = data.getBytes
    val encrypted = dataBytes.zipWithIndex.map { case (byte, index) =>
      (byte ^ keyBytes(index % keyBytes.length)).toByte
    }
    Base64.getEncoder.encodeToString(encrypted)
  }
  
  def decryptSensitiveData(encryptedData: String, key: String): String = {
    val keyBytes = key.getBytes
    val dataBytes = Base64.getDecoder.decode(encryptedData)
    val decrypted = dataBytes.zipWithIndex.map { case (byte, index) =>
      (byte ^ keyBytes(index % keyBytes.length)).toByte
    }
    new String(decrypted)
  }
  
  private val queryCache = Map[String, List[Map[String, Any]]]()
  
  def cacheQueryResult(query: String, results: List[Map[String, Any]]): Unit = {
    queryCache += (query -> results)
  }
  
  def getCachedQueryResult(query: String): Option[List[Map[String, Any]]] = {
    queryCache.get(query)
  }
  
  def getConnection(): Connection = {
    if (connection == null || connection.isClosed) {
      connection = DriverManager.getConnection("jdbc:h2:mem:testdb")
    }
    connection
  }
  
  def executeTransaction(operations: List[() => Unit]): Future[Boolean] = {
    Future {
      try {
        operations.foreach(_.apply())
        true
      } catch {
        case e: Exception => 
          false
      }
    }(ExecutionContext.global)
  }
}

object DatabaseManager {
  def main(args: Array[String]): Unit = {
    val dbManager = new DatabaseManager()
    println("Database Manager initialized with vulnerabilities for testing")
    
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val sqlInjectionResult = Await.result(dbManager.searchUsers("' OR '1'='1"), 5.seconds)
    println(s"SQL injection test: Found ${sqlInjectionResult.length} users")
    
    val authResult = Await.result(dbManager.authenticateUser("admin", "admin123"), 5.seconds)
    println(s"Authentication test: ${authResult.isDefined}")
    
    val userResult = Await.result(dbManager.createUser("testuser", "weakpassword", "test@example.com"), 5.seconds)
    println(s"User creation test: ${userResult.isDefined}")
  }
}

object DatabaseManagerTests {
  def testSQLInjectionVulnerability(): Unit = {
    val dbManager = new DatabaseManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(dbManager.searchUsers("' OR '1'='1"), 5.seconds)
    assert(result.length > 0)
  }
  
  def testWeakAuthenticationVulnerability(): Unit = {
    val dbManager = new DatabaseManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(dbManager.authenticateUser("admin", "admin123"), 5.seconds)
    assert(result.isDefined)
  }
  
  def testWeakPasswordCreationVulnerability(): Unit = {
    val dbManager = new DatabaseManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(dbManager.createUser("testuser", "weakpassword", "test@example.com"), 5.seconds)
    assert(result.isDefined)
  }
} 