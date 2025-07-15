import java.io.{File, FileInputStream, FileOutputStream, BufferedReader, BufferedWriter}
import java.nio.file.{Files, Paths, Path, StandardCopyOption}
import java.util.zip.{ZipInputStream, ZipEntry}
import scala.concurrent.{Future, ExecutionContext}
import scala.collection.mutable.{Map, ListBuffer}
import scala.io.Source
import scala.util.{Try, Success, Failure}
import scala.sys.process._

case class FileInfo(
  name: String,
  size: Long,
  path: String,
  createdAt: Long,
  modifiedAt: Long,
  permissions: String
)

case class UploadedFile(
  originalName: String,
  storedName: String,
  size: Long,
  contentType: String,
  uploadTime: Long,
  path: String
)

class FileManager {
  private val uploadDir = "/tmp/uploads"
  private val allowedExtensions = List("txt", "pdf", "jpg", "png")
  private val maxFileSize = 10 * 1024 * 1024L // 10MB
  private val uploadedFiles = Map[String, UploadedFile]()
  
  initializeUploadDirectory()
  
  private def initializeUploadDirectory(): Unit = {
    val uploadDirFile = new File(uploadDir)
    if (!uploadDirFile.exists()) {
      uploadDirFile.mkdirs()
    }
  }
  
  def readFile(filePath: String): Future[String] = {
    Future {
      try {
        val file = new File(filePath)
        if (file.exists() && file.isFile) {
          Source.fromFile(file).mkString
        } else {
          "File not found"
        }
      } catch {
        case e: Exception => s"Error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def writeFile(filePath: String, content: String): Future[Boolean] = {
    Future {
      try {
        val file = new File(filePath)
        val parent = file.getParentFile
        if (parent != null && !parent.exists()) {
          parent.mkdirs()
        }
        
        val writer = new BufferedWriter(new java.io.FileWriter(file))
        writer.write(content)
        writer.close()
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def deleteFile(filePath: String): Future[Boolean] = {
    Future {
      try {
        val file = new File(filePath)
        if (file.exists() && file.isFile) {
          file.delete()
        } else {
          false
        }
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def copyFile(sourcePath: String, destPath: String): Future[Boolean] = {
    Future {
      try {
        val source = new File(sourcePath)
        val dest = new File(destPath)
        
        if (source.exists() && source.isFile) {
          val parent = dest.getParentFile
          if (parent != null && !parent.exists()) {
            parent.mkdirs()
          }
          
          Files.copy(source.toPath, dest.toPath, StandardCopyOption.REPLACE_EXISTING)
          true
        } else {
          false
        }
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def listDirectory(dirPath: String): Future[List[FileInfo]] = {
    Future {
      try {
        val dir = new File(dirPath)
        if (dir.exists() && dir.isDirectory) {
          dir.listFiles().map { file =>
            FileInfo(
              name = file.getName,
              size = file.length(),
              path = file.getAbsolutePath,
              createdAt = file.lastModified(),
              modifiedAt = file.lastModified(),
              permissions = getFilePermissions(file)
            )
          }.toList
        } else {
          List.empty
        }
      } catch {
        case e: Exception => List.empty
      }
    }(ExecutionContext.global)
  }
  
  private def getFilePermissions(file: File): String = {
    if (file.canRead()) "r" else "-"
    if (file.canWrite()) "w" else "-"
    if (file.canExecute()) "x" else "-"
  }
  
  def uploadFile(originalName: String, content: Array[Byte], contentType: String): Future[Option[UploadedFile]] = {
    Future {
      val extension = getFileExtension(originalName).toLowerCase
      
      if (!allowedExtensions.contains(extension)) {
        None
      } else {
        val timestamp = System.currentTimeMillis()
        val storedName = s"${timestamp}_${originalName}"
        val filePath = s"${uploadDir}/${storedName}"
        
        try {
          val file = new File(filePath)
          val fos = new FileOutputStream(file)
          fos.write(content)
          fos.close()
          
          val uploadedFile = UploadedFile(
            originalName = originalName,
            storedName = storedName,
            size = content.length,
            contentType = contentType,
            uploadTime = timestamp,
            path = filePath
          )
          
          uploadedFiles += (storedName -> uploadedFile)
          Some(uploadedFile)
        } catch {
          case e: Exception => None
        }
      }
    }(ExecutionContext.global)
  }
  
  private def getFileExtension(filename: String): String = {
    val lastDot = filename.lastIndexOf('.')
    if (lastDot > 0) filename.substring(lastDot + 1) else ""
  }
  
  def extractZip(zipPath: String, extractDir: String): Future[Boolean] = {
    Future {
      try {
        val zipFile = new File(zipPath)
        if (!zipFile.exists()) {
          false
        } else {
          val zis = new ZipInputStream(new FileInputStream(zipFile))
          var entry: ZipEntry = null
          
          while ({ entry = zis.getNextEntry; entry } != null) {
            val filePath = s"${extractDir}/${entry.getName}"
            val file = new File(filePath)
            
            if (entry.isDirectory) {
              file.mkdirs()
            } else {
              val parent = file.getParentFile
              if (parent != null && !parent.exists()) {
                parent.mkdirs()
              }
              
              val fos = new FileOutputStream(file)
              val buffer = new Array[Byte](1024)
              var len = 0
              while ({ len = zis.read(buffer); len } > 0) {
                fos.write(buffer, 0, len)
              }
              fos.close()
            }
            zis.closeEntry()
          }
          zis.close()
          true
        }
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def processFileWithCommand(filePath: String, command: String): Future[String] = {
    Future {
      val fullCommand = s"${command} ${filePath}"
      try {
        val result = fullCommand.!!
        result
      } catch {
        case e: Exception => s"Error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def executeUploadedFile(fileId: String): Future[String] = {
    Future {
      uploadedFiles.get(fileId) match {
        case Some(file) =>
          try {
            val result = file.path.!!
            result
          } catch {
            case e: Exception => s"Execution error: ${e.getMessage}"
          }
        case None => "File not found"
      }
    }(ExecutionContext.global)
  }
  
  def getFileMetadata(filePath: String): Future[Map[String, String]] = {
    Future {
      val metadata = Map[String, String]()
      
      try {
        val file = new File(filePath)
        if (file.exists()) {
          metadata += ("size" -> file.length().toString)
          metadata += ("created" -> file.lastModified().toString)
          metadata += ("modified" -> file.lastModified().toString)
          metadata += ("isFile" -> file.isFile.toString)
          metadata += ("isDirectory" -> file.isDirectory.toString)
          metadata += ("canRead" -> file.canRead.toString)
          metadata += ("canWrite" -> file.canWrite.toString)
          metadata += ("canExecute" -> file.canExecute.toString)
          
          metadata += ("absolutePath" -> file.getAbsolutePath)
          metadata += ("canonicalPath" -> file.getCanonicalPath)
        }
      } catch {
        case e: Exception => metadata += ("error" -> e.getMessage)
      }
      
      metadata
    }(ExecutionContext.global)
  }
  
  def searchFiles(searchPath: String, pattern: String): Future[List[String]] = {
    Future {
      val command = s"find ${searchPath} -name '${pattern}' -type f"
      try {
        val result = command.!!
        result.split("\n").toList
      } catch {
        case e: Exception => List.empty
      }
    }(ExecutionContext.global)
  }
  
  def backupFile(sourcePath: String, backupDir: String): Future[String] = {
    Future {
      try {
        val source = new File(sourcePath)
        val backupPath = s"${backupDir}/${source.getName}"
        
        if (source.exists() && source.isFile) {
          copyFile(sourcePath, backupPath)
          backupPath
        } else {
          "Source file not found"
        }
      } catch {
        case e: Exception => s"Backup error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  private val fileContentCache = Map[String, Array[Byte]]()
  
  def cacheFileContent(filePath: String, content: Array[Byte]): Unit = {
    fileContentCache += (filePath -> content)
  }
  
  def getCachedFileContent(filePath: String): Option[Array[Byte]] = {
    fileContentCache.get(filePath)
  }
  
  def changeFilePermissions(filePath: String, permissions: String): Future[Boolean] = {
    Future {
      try {
        val command = s"chmod ${permissions} ${filePath}"
        val result = command.!!
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def changeFileOwnership(filePath: String, owner: String, group: String): Future[Boolean] = {
    Future {
      try {
        val command = s"chown ${owner}:${group} ${filePath}"
        val result = command.!!
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def calculateFileHash(filePath: String): Future[String] = {
    Future {
      try {
        val command = s"md5sum ${filePath}"
        val result = command.!!
        result.split(" ")(0)
      } catch {
        case e: Exception => s"Hash error: ${e.getMessage}"
      }
    }(ExecutionContext.global)
  }
  
  def compressFile(sourcePath: String, destPath: String): Future[Boolean] = {
    Future {
      try {
        val command = s"gzip -c ${sourcePath} > ${destPath}"
        val result = command.!!
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
  
  def decompressFile(sourcePath: String, destPath: String): Future[Boolean] = {
    Future {
      try {
        val command = s"gunzip -c ${sourcePath} > ${destPath}"
        val result = command.!!
        true
      } catch {
        case e: Exception => false
      }
    }(ExecutionContext.global)
  }
}

object FileManager {
  def main(args: Array[String]): Unit = {
    val fileManager = new FileManager()
    println("File Manager initialized with vulnerabilities for testing")
    
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val fileContent = Await.result(fileManager.readFile("/etc/passwd"), 5.seconds)
    println(s"Path traversal test: ${fileContent.take(100)}")
    
    val testContent = "test file content".getBytes
    val uploadResult = Await.result(fileManager.uploadFile("test.txt", testContent, "text/plain"), 5.seconds)
    println(s"File upload test: ${uploadResult.isDefined}")
    
    val commandResult = Await.result(fileManager.processFileWithCommand("/tmp/test.txt", "cat"), 5.seconds)
    println(s"Command injection test: ${commandResult}")
  }
}

object FileManagerTests {
  def testPathTraversalVulnerability(): Unit = {
    val fileManager = new FileManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(fileManager.readFile("../../../etc/passwd"), 5.seconds)
    assert(result != "File not found" || result.contains("Error"))
  }
  
  def testFileUploadVulnerability(): Unit = {
    val fileManager = new FileManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val content = "test content".getBytes
    val result = Await.result(fileManager.uploadFile("test.txt", content, "text/plain"), 5.seconds)
    assert(result.isDefined)
  }
  
  def testCommandInjectionVulnerability(): Unit = {
    val fileManager = new FileManager()
    import scala.concurrent.Await
    import scala.concurrent.duration._
    
    val result = Await.result(fileManager.processFileWithCommand("/tmp/test.txt", "cat"), 5.seconds)
    assert(result.nonEmpty)
  }
} 