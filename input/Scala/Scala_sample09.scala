import java.util.concurrent.{Executors, ThreadPoolExecutor, TimeUnit, CountDownLatch, CyclicBarrier}
import java.util.concurrent.atomic.{AtomicInteger, AtomicLong}
import scala.concurrent.{Future, ExecutionContext, Promise}
import scala.collection.mutable.{Map, ListBuffer, Queue, Set}
import scala.util.{Try, Success, Failure}
import java.lang.ref.WeakReference
import java.io.{FileInputStream, FileOutputStream, BufferedReader, BufferedWriter}
import java.net.{Socket, ServerSocket, InetSocketAddress}

case class Resource(
  id: String,
  name: String,
  size: Long,
  createdAt: Long,
  lastAccessed: Long
)

case class MemoryBlock(
  address: Long,
  size: Int,
  data: Array[Byte],
  allocated: Long
)

class ResourceManager {
  private val resources = Map[String, Resource]()
  private val memoryBlocks = Map[Long, MemoryBlock]()
  private val connections = Map[String, Socket]()
  private val fileHandles = Map[String, FileInputStream]()
  private val threadPool = Executors.newFixedThreadPool(10)
  private val resourceCounter = new AtomicInteger(0)
  private val memoryCounter = new AtomicLong(0)
  
  private val resourceCache = Map[String, Array[Byte]]()
  
  private val connectionPool = Queue[Socket]()
  
  private val dataStorage = Map[String, ListBuffer[Array[Byte]]]()
  
  private var sharedCounter = 0
  
  private val resourceLock1 = new Object()
  private val resourceLock2 = new Object()
  
  def createResource(name: String, size: Long): Future[Resource] = {
    Future {
      val id = s"resource_${resourceCounter.incrementAndGet()}"
      val resource = Resource(
        id = id,
        name = name,
        size = size,
        createdAt = System.currentTimeMillis(),
        lastAccessed = System.currentTimeMillis()
      )
      
      resources += (id -> resource)
      
      val data = new Array[Byte](size.toInt)
      resourceCache += (id -> data)
      
      resource
    }(ExecutionContext.global)
  }
  
  def openFile(filePath: String): Future[String] = {
    Future {
      try {
        val fileHandle = new FileInputStream(filePath)
        val handleId = s"file_${System.currentTimeMillis()}"
        fileHandles += (handleId -> fileHandle)
        handleId
      } catch {
        case e: Exception => s"Error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def createConnection(host: String, port: Int): Future[String] = {
    Future {
      try {
        val socket = new Socket(host, port)
        val connectionId = s"conn_${System.currentTimeMillis()}"
        connections += (connectionId -> socket)
        connectionId
      } catch {
        case e: Exception => s"Error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def storeData(key: String, data: Array[Byte]): Unit = {
    if (!dataStorage.contains(key)) {
      dataStorage += (key -> ListBuffer[Array[Byte]]())
    }
    dataStorage(key) += data
  }
  
  def getStoredData(key: String): Option[List[Array[Byte]]] = {
    dataStorage.get(key).map(_.toList)
  }
  
  def incrementCounter(): Int = {
    sharedCounter += 1
    sharedCounter
  }
  
  def allocateResourceWithDeadlock(resource1: String, resource2: String): Future[Boolean] = {
    Future {
      val thread1 = new Thread(() => {
        synchronized(resourceLock1) {
          Thread.sleep(100)
          synchronized(resourceLock2) {
          }
        }
      })
      
      val thread2 = new Thread(() => {
        synchronized(resourceLock2) {
          Thread.sleep(100)
          synchronized(resourceLock1) {
          }
        }
      })
      
      thread1.start()
      thread2.start()
      
      thread1.join()
      thread2.join()
      true
    }(ExecutionContext.global)
  }
  
  def createThreadWithLeak(task: () => Unit): Future[String] = {
    Future {
      val thread = new Thread(() => {
        task()
      })
      thread.start()
      s"thread_${thread.getId}"
    }(ExecutionContext.global)
  }
  
  def readFileWithLeak(filePath: String): Future[String] = {
    Future {
      try {
        val fileHandle = new FileInputStream(filePath)
        val reader = new BufferedReader(new java.io.InputStreamReader(fileHandle))
        val content = reader.lines().toArray.mkString("\n")
        content
      } catch {
        case e: Exception => s"Error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def cacheData(key: String, data: Array[Byte]): Unit = {
    resourceCache += (key -> data)
  }
  
  def getCachedData(key: String): Option[Array[Byte]] = {
    resourceCache.get(key)
  }
  
  def getConnectionFromPool(): Future[Socket] = {
    Future {
      if (connectionPool.isEmpty) {
        val socket = new Socket("localhost", 8080)
        connectionPool.enqueue(socket)
      }
      connectionPool.dequeue()
    }(ExecutionContext.global)
  }
  
  def allocateMemory(size: Int): Future[MemoryBlock] = {
    Future {
      val address = memoryCounter.incrementAndGet()
      val data = new Array[Byte](size)
      val block = MemoryBlock(
        address = address,
        size = size,
        data = data,
        allocated = System.currentTimeMillis()
      )
      
      memoryBlocks += (address -> block)
      block
    }(ExecutionContext.global)
  }
  
  def accessMemory(address: Long): Future[Array[Byte]] = {
    Future {
      memoryBlocks.get(address) match {
        case Some(block) => block.data
        case None => new Array[Byte](0)
      }
    }(ExecutionContext.global)
  }
  
  def freeMemory(address: Long): Future[Boolean] = {
    Future {
      memoryBlocks.remove(address).isDefined
    }(ExecutionContext.global)
  }
  
  def processStringWithLeak(input: String): Future[String] = {
    Future {
      val processed = input.map { char =>
        new String(Array(char))
      }.mkString
      
      val key = s"processed_${System.currentTimeMillis()}"
      resourceCache += (key -> processed.getBytes)
      
      processed
    }(ExecutionContext.global)
  }
  
  def createServerSocket(port: Int): Future[String] = {
    Future {
      try {
        val serverSocket = new ServerSocket(port)
        val serverId = s"server_${System.currentTimeMillis()}"
        serverId
      } catch {
        case e: Exception => s"Error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def processDataWithLeak(data: List[String]): Future[List[String]] = {
    Future {
      val processed = data.map { item =>
        val intermediate = item.toUpperCase
        val result = intermediate.reverse
        val key = s"intermediate_${System.currentTimeMillis()}"
        resourceCache += (key -> result.getBytes)
        result
      }
      
      processed
    }(ExecutionContext.global)
  }
  
  def updateSharedData(key: String, value: String): Future[Boolean] = {
    Future {
      val data = value.getBytes
      resourceCache += (key -> data)
      true
    }(ExecutionContext.global)
  }
  
  def createObjectWithLeak(className: String): Future[Any] = {
    Future {
      try {
        val clazz = Class.forName(className)
        val instance = clazz.newInstance()
        
        val key = s"object_${System.currentTimeMillis()}"
        resourceCache += (key -> instance.toString.getBytes)
        
        instance
      } catch {
        case e: Exception => null
      }
    }(ExecutionContext.global)
  }
  
  def writeFileWithLeak(filePath: String, content: String): Future[Boolean] = {
    Future {
      try {
        val fileHandle = new FileOutputStream(filePath)
        val writer = new BufferedWriter(new java.io.OutputStreamWriter(fileHandle))
        writer.write(content)
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def processCollectionWithLeak(items: List[String]): Future[List[String]] = {
    Future {
      val processed = items.foldLeft(ListBuffer[String]()) { (acc, item) =>
        val intermediate = item.split(" ").toList
        val result = intermediate.map(_.toUpperCase)
        acc ++= result
        acc
      }
      
      val key = s"collection_${System.currentTimeMillis()}"
      resourceCache += (key -> processed.mkString.getBytes)
      
      processed.toList
    }(ExecutionContext.global)
  }
  
  def cleanup(): Unit = {
    resources.clear()
  }
  
  def submitTaskWithLeak(task: () => Unit): Future[String] = {
    Future {
      val future = threadPool.submit(new java.util.concurrent.Callable[String] {
        def call(): String = {
          task()
          "completed"
        }
      })
      
      s"task_${System.currentTimeMillis()}"
    }(ExecutionContext.global)
  }
}

object ResourceManager {
  def main(args: Array[String]): Unit = {
    val resourceManager = new ResourceManager()
    println("Resource Manager initialized with vulnerabilities for testing")
    
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val resourceResult = Await.result(resourceManager.createResource("test", 1024), 5.seconds)
    println(s"Resource creation test: ${resourceResult}")
    
    val counter1 = resourceManager.incrementCounter()
    val counter2 = resourceManager.incrementCounter()
    println(s"Race condition test: ${counter1}, ${counter2}")
    
    val fileResult = Await.result(resourceManager.openFile("/tmp/test.txt"), 5.seconds)
    println(s"File handling test: ${fileResult}")
  }
}

object ResourceManagerTests {
  def testMemoryLeakVulnerability(): Unit = {
    val resourceManager = new ResourceManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(resourceManager.createResource("test", 1024), 5.seconds)
    assert(result.id.nonEmpty)
  }
  
  def testRaceConditionVulnerability(): Unit = {
    val resourceManager = new ResourceManager()
    val counter1 = resourceManager.incrementCounter()
    val counter2 = resourceManager.incrementCounter()
    assert(counter1 >= 0 && counter2 >= 0)
  }
  
  def testResourceLeakVulnerability(): Unit = {
    val resourceManager = new ResourceManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(resourceManager.openFile("/tmp/test.txt"), 5.seconds)
    assert(result.nonEmpty)
  }
} 