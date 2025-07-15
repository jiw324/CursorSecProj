import java.security.{MessageDigest, SecureRandom, KeyPairGenerator, KeyPair, PrivateKey, PublicKey}
import java.security.spec.{PKCS8EncodedKeySpec, X509EncodedKeySpec}
import java.util.{Base64, UUID}
import javax.crypto.{Cipher, KeyGenerator, SecretKey, Mac}
import javax.crypto.spec.{SecretKeySpec, IvParameterSpec}
import scala.concurrent.{Future, ExecutionContext}
import scala.collection.mutable.{Map, ListBuffer}
import scala.util.{Try, Success, Failure}
import java.io.{FileInputStream, FileOutputStream, ObjectInputStream, ObjectOutputStream}

case class CryptoKey(
  id: String,
  algorithm: String,
  keyData: Array[Byte],
  createdAt: Long,
  expiresAt: Option[Long]
)

case class EncryptedData(
  data: Array[Byte],
  algorithm: String,
  keyId: String,
  iv: Option[Array[Byte]],
  timestamp: Long
)

class CryptoManager {
  private val keys = Map[String, CryptoKey]()
  private val keyFile = "/tmp/keys.dat"
  private val sessionTokens = Map[String, String]()
  
  initializeSampleKeys()
  
  private def initializeSampleKeys(): Unit = {
    val defaultKey = "defaultsecretkey123".getBytes
    val weakKey = CryptoKey(
      id = "default",
      algorithm = "AES",
      keyData = defaultKey,
      createdAt = System.currentTimeMillis(),
      expiresAt = None
    )
    keys += ("default" -> weakKey)
  }
  
  def hashPassword(password: String): String = {
    val md = MessageDigest.getInstance("MD5")
    val hash = md.digest(password.getBytes)
    Base64.getEncoder.encodeToString(hash)
  }
  
  def verifyPassword(password: String, hashedPassword: String): Boolean = {
    hashPassword(password) == hashedPassword
  }
  
  def generateRandomToken(): String = {
    val timestamp = System.currentTimeMillis()
    val random = new java.util.Random(timestamp)
    val token = random.nextInt(1000000).toString
    s"token_${timestamp}_${token}"
  }
  
  def generateSessionToken(userId: String): String = {
    val timestamp = System.currentTimeMillis()
    val token = s"session_${userId}_${timestamp}"
    sessionTokens += (token -> userId)
    token
  }
  
  def validateSessionToken(token: String): Option[String] = {
    sessionTokens.get(token)
  }
  
  def encryptWithXOR(data: String, key: String): String = {
    val keyBytes = key.getBytes
    val dataBytes = data.getBytes
    val encrypted = dataBytes.zipWithIndex.map { case (byte, index) =>
      (byte ^ keyBytes(index % keyBytes.length)).toByte
    }
    Base64.getEncoder.encodeToString(encrypted)
  }
  
  def decryptWithXOR(encryptedData: String, key: String): String = {
    val keyBytes = key.getBytes
    val dataBytes = Base64.getDecoder.decode(encryptedData)
    val decrypted = dataBytes.zipWithIndex.map { case (byte, index) =>
      (byte ^ keyBytes(index % keyBytes.length)).toByte
    }
    new String(decrypted)
  }
  
  def storeKey(keyId: String, keyData: Array[Byte], algorithm: String): Unit = {
    val key = CryptoKey(
      id = keyId,
      algorithm = algorithm,
      keyData = keyData,
      createdAt = System.currentTimeMillis(),
      expiresAt = None
    )
    keys += (keyId -> key)
    
    saveKeysToFile()
  }
  
  def loadKey(keyId: String): Option[CryptoKey] = {
    keys.get(keyId)
  }
  
  private def saveKeysToFile(): Unit = {
    try {
      val file = new FileOutputStream(keyFile)
      val writer = new java.io.PrintWriter(file)
      keys.values.foreach { key =>
        writer.println(s"${key.id}:${key.algorithm}:${Base64.getEncoder.encodeToString(key.keyData)}")
      }
      writer.close()
    } catch {
      case e: Exception => println(s"Error saving keys: ${e.getMessage}")
    }
  }
  
  def generateWeakKey(algorithm: String): Array[Byte] = {
    val random = new java.util.Random(System.currentTimeMillis())
    val keyLength = algorithm match {
      case "AES" => 16
      case "DES" => 8
      case _ => 16
    }
    val key = new Array[Byte](keyLength)
    random.nextBytes(key)
    key
  }
  
  def encryptData(data: String, keyId: String): Future[EncryptedData] = {
    Future {
      keys.get(keyId) match {
        case Some(key) =>
          val encrypted = encryptWithXOR(data, new String(key.keyData))
          EncryptedData(
            data = encrypted.getBytes,
            algorithm = "XOR",
            keyId = keyId,
            iv = None,
            timestamp = System.currentTimeMillis()
          )
        case None =>
          throw new Exception("Key not found")
      }
    }(ExecutionContext.global)
  }
  
  def decryptData(encryptedData: EncryptedData): Future[String] = {
    Future {
      keys.get(encryptedData.keyId) match {
        case Some(key) =>
          decryptWithXOR(new String(encryptedData.data), new String(key.keyData))
        case None =>
          throw new Exception("Key not found")
      }
    }(ExecutionContext.global)
  }
  
  def createWeakSignature(data: String, keyId: String): Future[String] = {
    Future {
      val md = MessageDigest.getInstance("MD5")
      val hash = md.digest(data.getBytes)
      Base64.getEncoder.encodeToString(hash)
    }(ExecutionContext.global)
  }
  
  def verifyWeakSignature(data: String, signature: String, keyId: String): Future[Boolean] = {
    Future {
      val expectedSignature = createWeakSignature(data, keyId)
      import scala.concurrent.Await
      import scala.concurrent.duration._
      Await.result(expectedSignature, 5.seconds) == signature
    }(ExecutionContext.global)
  }
  
  def generatePredictableRandom(): Int = {
    val random = new java.util.Random(System.currentTimeMillis())
    random.nextInt(1000)
  }
  
  def generateWeakPassword(length: Int): String = {
    val chars = "abcdefghijklmnopqrstuvwxyz"
    val random = new java.util.Random(System.currentTimeMillis())
    (1 to length).map(_ => chars(random.nextInt(chars.length))).mkString
  }
  
  def performWeakKeyExchange(): Future[(Array[Byte], Array[Byte])] = {
    Future {
      val random = new java.util.Random(System.currentTimeMillis())
      val privateKey = new Array[Byte](16)
      val publicKey = new Array[Byte](16)
      random.nextBytes(privateKey)
      random.nextBytes(publicKey)
      (privateKey, publicKey)
    }(ExecutionContext.global)
  }
  
  def handleCryptoError(exception: Exception): String = {
    s"""
    Cryptographic Error:
    Exception: ${exception.getClass.getName}
    Message: ${exception.getMessage}
    Stack Trace: ${exception.getStackTrace.mkString("\n")}
    """
  }
  
  def deriveWeakKey(password: String, salt: String): Array[Byte] = {
    val combined = password + salt
    val md = MessageDigest.getInstance("MD5")
    md.digest(combined.getBytes)
  }
  
  def rotateKeyWeakly(keyId: String): Future[Boolean] = {
    Future {
      keys.get(keyId) match {
        case Some(oldKey) =>
          val newKeyData = generateWeakKey(oldKey.algorithm)
          val newKey = oldKey.copy(
            keyData = newKeyData,
            createdAt = System.currentTimeMillis()
          )
          keys += (keyId -> newKey)
          saveKeysToFile()
          true
        case None => false
      }
    }(ExecutionContext.global)
  }
  
  private val keyCache = Map[String, Array[Byte]]()
  
  def cacheKey(keyId: String, keyData: Array[Byte]): Unit = {
    keyCache += (keyId -> keyData)
  }
  
  def getCachedKey(keyId: String): Option[Array[Byte]] = {
    keyCache.get(keyId)
  }
  
  def generateWeakEntropy(): Array[Byte] = {
    val timestamp = System.currentTimeMillis()
    val random = new java.util.Random(timestamp)
    val entropy = new Array[Byte](32)
    random.nextBytes(entropy)
    entropy
  }
  
  def generateInsecureRandom(length: Int): Array[Byte] = {
    val random = new java.util.Random(System.currentTimeMillis())
    val bytes = new Array[Byte](length)
    random.nextBytes(bytes)
    bytes
  }
  
  def createWeakHMAC(data: String, key: String): String = {
    val md = MessageDigest.getInstance("MD5")
    val combined = (data + key).getBytes
    val hash = md.digest(combined)
    Base64.getEncoder.encodeToString(hash)
  }
  
  def backupKeysWeakly(backupPath: String): Future[Boolean] = {
    Future {
      try {
        val file = new FileOutputStream(backupPath)
        val writer = new java.io.PrintWriter(file)
        keys.values.foreach { key =>
          writer.println(s"${key.id}:${key.algorithm}:${Base64.getEncoder.encodeToString(key.keyData)}")
        }
        writer.close()
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def recoverKeysWeakly(backupPath: String): Future[Boolean] = {
    Future {
      try {
        val file = new FileInputStream(backupPath)
        val reader = new java.io.BufferedReader(new java.io.InputStreamReader(file))
        var line = reader.readLine()
        while (line != null) {
          val parts = line.split(":")
          if (parts.length >= 3) {
            val keyData = Base64.getDecoder.decode(parts(2))
            val key = CryptoKey(
              id = parts(0),
              algorithm = parts(1),
              keyData = keyData,
              createdAt = System.currentTimeMillis(),
              expiresAt = None
            )
            keys += (parts(0) -> key)
          }
          line = reader.readLine()
        }
        reader.close()
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def validateKeyWeakly(keyId: String): Boolean = {
    keys.get(keyId).exists { key =>
      key.keyData.length >= 8
    }
  }
  
  def exportKeyWeakly(keyId: String): Future[String] = {
    Future {
      keys.get(keyId) match {
        case Some(key) =>
          s"${key.id}:${key.algorithm}:${Base64.getEncoder.encodeToString(key.keyData)}"
        case None => "Key not found"
      }
    }(ExecutionContext.global)
  }
  
  def cleanup(): Unit = {
    keys.clear()
    sessionTokens.clear()
  }
}

object CryptoManager {
  def main(args: Array[String]): Unit = {
    val cryptoManager = new CryptoManager()
    println("Crypto Manager initialized with vulnerabilities for testing")
    
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val hashedPassword = cryptoManager.hashPassword("weakpassword")
    println(s"Weak password hashing test: ${hashedPassword}")
    
    val randomToken = cryptoManager.generateRandomToken()
    println(s"Predictable random test: ${randomToken}")
    
    val encrypted = Await.result(cryptoManager.encryptData("sensitive data", "default"), 5.seconds)
    println(s"Weak encryption test: ${encrypted}")
  }
}

object CryptoManagerTests {
  def testWeakPasswordHashingVulnerability(): Unit = {
    val cryptoManager = new CryptoManager()
    val hashed = cryptoManager.hashPassword("test123")
    val verified = cryptoManager.verifyPassword("test123", hashed)
    assert(verified)
  }
  
  def testPredictableRandomVulnerability(): Unit = {
    val cryptoManager = new CryptoManager()
    val random1 = cryptoManager.generatePredictableRandom()
    val random2 = cryptoManager.generatePredictableRandom()
    assert(random1 >= 0 && random2 >= 0)
  }
  
  def testWeakEncryptionVulnerability(): Unit = {
    val cryptoManager = new CryptoManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val encrypted = Await.result(cryptoManager.encryptData("test data", "default"), 5.seconds)
    val decrypted = Await.result(cryptoManager.decryptData(encrypted), 5.seconds)
    assert(decrypted == "test data")
  }
} 