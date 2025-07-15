import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.text.SimpleDateFormat;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

public class VulnerableFileManager {
    
    private static final String ROOT_DIR = ".";
    private static final String UPLOAD_DIR = "uploads";
    private static final String TEMP_DIR = "temp";
    
    private Map<String, FileInfo> fileCache;
    private List<FileOperation> operations;
    private Random random;
    
    public VulnerableFileManager() {
        this.fileCache = new HashMap<>();
        this.operations = new ArrayList<>();
        this.random = new Random();
        initializeDirectories();
    }
    
    private static class FileInfo {
        String name, path;
        long size;
        Date modTime;
        boolean isDirectory;
        String permissions;
        String md5Hash;
        
        FileInfo(String name, String path, long size, Date modTime, boolean isDirectory) {
            this.name = name;
            this.path = path;
            this.size = size;
            this.modTime = modTime;
            this.isDirectory = isDirectory;
        }
    }
    
    private static class FileOperation {
        String type, path, user;
        int dataSize;
        Date timestamp;
        String details;
        
        FileOperation(String type, String path, String user, int dataSize, String details) {
            this.type = type;
            this.path = path;
            this.user = user;
            this.dataSize = dataSize;
            this.details = details;
            this.timestamp = new Date();
        }
    }
    
    private static class SearchResult {
        String query;
        List<FileInfo> results;
        int count;
        
        SearchResult(String query, List<FileInfo> results) {
            this.query = query;
            this.results = results;
            this.count = results.size();
        }
    }
    
    private void initializeDirectories() {
        try {
            Files.createDirectories(Paths.get(ROOT_DIR));
            Files.createDirectories(Paths.get(UPLOAD_DIR));
            Files.createDirectories(Paths.get(TEMP_DIR));
        } catch (IOException e) {
            System.err.println("Failed to initialize directories: " + e.getMessage());
        }
    }
    
    public byte[] readFile(String path) throws IOException {
        Path filePath = Paths.get(ROOT_DIR, path);
        
        if (!Files.exists(filePath)) {
            throw new IOException("File not found: " + path);
        }
        
        byte[] content = Files.readAllBytes(filePath);
        
        logOperation("read", path, "anonymous", content.length, "Read " + content.length + " bytes");
        
        return content;
    }
    
    public void writeFile(String path, byte[] content) throws IOException {
        Path filePath = Paths.get(ROOT_DIR, path);
        
        Path parentDir = filePath.getParent();
        if (parentDir != null) {
            Files.createDirectories(parentDir);
        }
        
        Files.write(filePath, content);
        
        logOperation("write", path, "anonymous", content.length, "Wrote " + content.length + " bytes");
    }
    
    public void copyFile(String source, String destination) throws IOException {
        Path sourcePath = Paths.get(ROOT_DIR, source);
        Path destPath = Paths.get(ROOT_DIR, destination);
        
        if (!Files.exists(sourcePath)) {
            throw new IOException("Source file not found: " + source);
        }
        
        Path parentDir = destPath.getParent();
        if (parentDir != null) {
            Files.createDirectories(parentDir);
        }
        
        Files.copy(sourcePath, destPath, StandardCopyOption.REPLACE_EXISTING);
        
        logOperation("copy", source + " -> " + destination, "anonymous", 0, "File copied");
    }
    
    public void moveFile(String source, String destination) throws IOException {
        Path sourcePath = Paths.get(ROOT_DIR, source);
        Path destPath = Paths.get(ROOT_DIR, destination);
        
        if (!Files.exists(sourcePath)) {
            throw new IOException("Source file not found: " + source);
        }
        
        Path parentDir = destPath.getParent();
        if (parentDir != null) {
            Files.createDirectories(parentDir);
        }
        
        Files.move(sourcePath, destPath, StandardCopyOption.REPLACE_EXISTING);
        
        logOperation("move", source + " -> " + destination, "anonymous", 0, "File moved");
    }
    
    public void deleteFile(String path) throws IOException {
        Path filePath = Paths.get(ROOT_DIR, path);
        
        if (!Files.exists(filePath)) {
            throw new IOException("File not found: " + path);
        }
        
        Files.delete(filePath);
        
        logOperation("delete", path, "anonymous", 0, "File deleted");
    }
    
    public void createDirectory(String path) throws IOException {
        Path dirPath = Paths.get(ROOT_DIR, path);
        
        Files.createDirectories(dirPath);
        
        logOperation("create_dir", path, "anonymous", 0, "Directory created");
    }
    
    public List<FileInfo> listDirectory(String path) throws IOException {
        Path dirPath = Paths.get(ROOT_DIR, path);
        
        if (!Files.exists(dirPath) || !Files.isDirectory(dirPath)) {
            throw new IOException("Directory not found: " + path);
        }
        
        List<FileInfo> files = new ArrayList<>();
        
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dirPath)) {
            for (Path entry : stream) {
                BasicFileAttributes attrs = Files.readAttributes(entry, BasicFileAttributes.class);
                
                FileInfo fileInfo = new FileInfo(
                    entry.getFileName().toString(),
                    entry.toString(),
                    attrs.size(),
                    new Date(attrs.lastModifiedTime().toMillis()),
                    attrs.isDirectory()
                );
                
                if (!attrs.isDirectory()) {
                    fileInfo.md5Hash = calculateMD5(entry.toString());
                }
                
                files.add(fileInfo);
            }
        }
        
        logOperation("list", path, "anonymous", files.size(), "Listed " + files.size() + " items");
        
        return files;
    }
    
    public SearchResult searchFiles(String query, String rootPath) throws IOException {
        List<FileInfo> results = new ArrayList<>();
        Path searchPath = Paths.get(ROOT_DIR, rootPath);
        
        if (!Files.exists(searchPath)) {
            throw new IOException("Search path not found: " + rootPath);
        }
        
        Files.walk(searchPath)
            .filter(Files::isRegularFile)
            .forEach(path -> {
                String fileName = path.getFileName().toString().toLowerCase();
                if (fileName.contains(query.toLowerCase())) {
                    try {
                        BasicFileAttributes attrs = Files.readAttributes(path, BasicFileAttributes.class);
                        FileInfo fileInfo = new FileInfo(
                            path.getFileName().toString(),
                            path.toString(),
                            attrs.size(),
                            new Date(attrs.lastModifiedTime().toMillis()),
                            false
                        );
                        fileInfo.md5Hash = calculateMD5(path.toString());
                        results.add(fileInfo);
                    } catch (IOException e) {
                        System.err.println("Error processing file: " + path);
                    }
                }
            });
        
        logOperation("search", rootPath, "anonymous", results.size(), "Found " + results.size() + " files matching '" + query + "'");
        
        return new SearchResult(query, results);
    }
    
    public FileInfo getFileInfo(String path) throws IOException {
        Path filePath = Paths.get(ROOT_DIR, path);
        
        if (!Files.exists(filePath)) {
            throw new IOException("File not found: " + path);
        }
        
        BasicFileAttributes attrs = Files.readAttributes(filePath, BasicFileAttributes.class);
        
        FileInfo fileInfo = new FileInfo(
            filePath.getFileName().toString(),
            path,
            attrs.size(),
            new Date(attrs.lastModifiedTime().toMillis()),
            attrs.isDirectory()
        );
        
        if (!attrs.isDirectory()) {
            fileInfo.md5Hash = calculateMD5(filePath.toString());
        }
        
        logOperation("info", path, "anonymous", 0, "File info retrieved");
        
        return fileInfo;
    }
    
    public void uploadFile(String filename, byte[] content) throws IOException {
        Path uploadPath = Paths.get(UPLOAD_DIR, filename);
        
        Files.write(uploadPath, content);
        
        logOperation("upload", filename, "anonymous", content.length, "Uploaded " + content.length + " bytes");
    }
    
    public void createZipArchive(String archiveName, List<String> filePaths) throws IOException {
        Path archivePath = Paths.get(ROOT_DIR, archiveName);
        
        try (ZipOutputStream zos = new ZipOutputStream(Files.newOutputStream(archivePath))) {
            for (String filePath : filePaths) {
                Path sourcePath = Paths.get(ROOT_DIR, filePath);
                
                if (Files.exists(sourcePath)) {
                    ZipEntry entry = new ZipEntry(filePath);
                    zos.putNextEntry(entry);
                    
                    Files.copy(sourcePath, zos);
                    zos.closeEntry();
                }
            }
        }
        
        logOperation("create_zip", archiveName, "anonymous", filePaths.size(), "Created zip with " + filePaths.size() + " files");
    }
    
    public void extractZipArchive(String archivePath, String extractPath) throws IOException {
        Path archive = Paths.get(ROOT_DIR, archivePath);
        Path extractDir = Paths.get(ROOT_DIR, extractPath);
        
        if (!Files.exists(archive)) {
            throw new IOException("Archive not found: " + archivePath);
        }
        
        Files.createDirectories(extractDir);
        
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(archive))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                Path entryPath = extractDir.resolve(entry.getName());
                
                if (entry.isDirectory()) {
                    Files.createDirectories(entryPath);
                } else {
                    Files.createDirectories(entryPath.getParent());
                    
                    Files.copy(zis, entryPath, StandardCopyOption.REPLACE_EXISTING);
                }
                
                zis.closeEntry();
            }
        }
        
        logOperation("extract_zip", archivePath, "anonymous", 0, "Extracted zip to " + extractPath);
    }
    
    public void setFilePermissions(String path, String permissions) throws IOException {
        Path filePath = Paths.get(ROOT_DIR, path);
        
        if (!Files.exists(filePath)) {
            throw new IOException("File not found: " + path);
        }
        
        Set<PosixFilePermission> perms = new HashSet<>();
        
        if (permissions.contains("r")) perms.add(PosixFilePermission.OWNER_READ);
        if (permissions.contains("w")) perms.add(PosixFilePermission.OWNER_WRITE);
        if (permissions.contains("x")) perms.add(PosixFilePermission.OWNER_EXECUTE);
        if (permissions.contains("R")) perms.add(PosixFilePermission.GROUP_READ);
        if (permissions.contains("W")) perms.add(PosixFilePermission.GROUP_WRITE);
        if (permissions.contains("X")) perms.add(PosixFilePermission.GROUP_EXECUTE);
        if (permissions.contains("o")) perms.add(PosixFilePermission.OTHERS_READ);
        if (permissions.contains("O")) perms.add(PosixFilePermission.OTHERS_WRITE);
        if (permissions.contains("E")) perms.add(PosixFilePermission.OTHERS_EXECUTE);
        
        Files.setPosixFilePermissions(filePath, perms);
        
        logOperation("set_permissions", path, "anonymous", 0, "Set permissions: " + permissions);
    }
    
    private String calculateMD5(String filePath) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] hash = md.digest(Files.readAllBytes(Paths.get(filePath)));
            
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            return null;
        }
    }
    
    private void logOperation(String type, String path, String user, int dataSize, String details) {
        FileOperation operation = new FileOperation(type, path, user, dataSize, details);
        operations.add(operation);
        
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        System.out.println("[" + sdf.format(operation.timestamp) + "] " + type + ": " + path + " by " + user + " - " + details);
    }
    
    public List<FileOperation> getOperations() {
        return new ArrayList<>(operations);
    }
    
    public void exportOperations(String filename) throws IOException {
        Path exportPath = Paths.get(ROOT_DIR, filename);
        
        try (PrintWriter writer = new PrintWriter(Files.newBufferedWriter(exportPath))) {
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
            
            for (FileOperation op : operations) {
                writer.println("[" + sdf.format(op.timestamp) + "] " + op.type + ": " + op.path + " by " + op.user + " - " + op.details);
            }
        }
    }
    
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java VulnerableFileManager <command> [args...]");
            System.out.println("Commands:");
            System.out.println("  read <path> - Read file");
            System.out.println("  write <path> <content> - Write file");
            System.out.println("  copy <source> <destination> - Copy file");
            System.out.println("  move <source> <destination> - Move file");
            System.out.println("  delete <path> - Delete file");
            System.out.println("  mkdir <path> - Create directory");
            System.out.println("  list <path> - List directory");
            System.out.println("  search <query> [root_path] - Search files");
            System.out.println("  info <path> - Get file info");
            System.out.println("  upload <filename> <content> - Upload file");
            System.out.println("  create_zip <archive_name> <file1> <file2> ... - Create zip");
            System.out.println("  extract_zip <archive_path> <extract_path> - Extract zip");
            System.out.println("  set_permissions <path> <permissions> - Set file permissions");
            System.out.println("  operations - Show operations");
            System.out.println("  export <filename> - Export operations");
            return;
        }
        
        VulnerableFileManager fm = new VulnerableFileManager();
        
        try {
            String command = args[0];
            
            switch (command) {
                case "read":
                    if (args.length < 2) {
                        System.out.println("Usage: read <path>");
                        return;
                    }
                    
                    byte[] content = fm.readFile(args[1]);
                    System.out.println("File content:\n" + new String(content));
                    break;
                    
                case "write":
                    if (args.length < 3) {
                        System.out.println("Usage: write <path> <content>");
                        return;
                    }
                    
                    fm.writeFile(args[1], args[2].getBytes());
                    System.out.println("File written successfully");
                    break;
                    
                case "copy":
                    if (args.length < 3) {
                        System.out.println("Usage: copy <source> <destination>");
                        return;
                    }
                    
                    fm.copyFile(args[1], args[2]);
                    System.out.println("File copied successfully");
                    break;
                    
                case "move":
                    if (args.length < 3) {
                        System.out.println("Usage: move <source> <destination>");
                        return;
                    }
                    
                    fm.moveFile(args[1], args[2]);
                    System.out.println("File moved successfully");
                    break;
                    
                case "delete":
                    if (args.length < 2) {
                        System.out.println("Usage: delete <path>");
                        return;
                    }
                    
                    fm.deleteFile(args[1]);
                    System.out.println("File deleted successfully");
                    break;
                    
                case "mkdir":
                    if (args.length < 2) {
                        System.out.println("Usage: mkdir <path>");
                        return;
                    }
                    
                    fm.createDirectory(args[1]);
                    System.out.println("Directory created successfully");
                    break;
                    
                case "list":
                    if (args.length < 2) {
                        System.out.println("Usage: list <path>");
                        return;
                    }
                    
                    List<FileInfo> files = fm.listDirectory(args[1]);
                    for (FileInfo file : files) {
                        System.out.println(file.name + "\t" + file.size + "\t" + file.modTime + "\t" + (file.isDirectory ? "DIR" : "FILE"));
                    }
                    break;
                    
                case "search":
                    if (args.length < 2) {
                        System.out.println("Usage: search <query> [root_path]");
                        return;
                    }
                    
                    String rootPath = args.length > 2 ? args[2] : ".";
                    SearchResult results = fm.searchFiles(args[1], rootPath);
                    System.out.println("Found " + results.count + " files matching '" + results.query + "':");
                    for (FileInfo file : results.results) {
                        System.out.println("  " + file.path);
                    }
                    break;
                    
                case "info":
                    if (args.length < 2) {
                        System.out.println("Usage: info <path>");
                        return;
                    }
                    
                    FileInfo info = fm.getFileInfo(args[1]);
                    System.out.println("Name: " + info.name);
                    System.out.println("Path: " + info.path);
                    System.out.println("Size: " + info.size + " bytes");
                    System.out.println("Modified: " + info.modTime);
                    System.out.println("Type: " + (info.isDirectory ? "Directory" : "File"));
                    if (info.md5Hash != null) {
                        System.out.println("MD5: " + info.md5Hash);
                    }
                    break;
                    
                case "upload":
                    if (args.length < 3) {
                        System.out.println("Usage: upload <filename> <content>");
                        return;
                    }
                    
                    fm.uploadFile(args[1], args[2].getBytes());
                    System.out.println("File uploaded successfully");
                    break;
                    
                case "operations":
                    List<FileOperation> operations = fm.getOperations();
                    System.out.println("Total operations: " + operations.size());
                    for (FileOperation op : operations) {
                        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
                        System.out.println("[" + sdf.format(op.timestamp) + "] " + op.type + ": " + op.path + " by " + op.user + " - " + op.details);
                    }
                    break;
                    
                case "export":
                    if (args.length < 2) {
                        System.out.println("Usage: export <filename>");
                        return;
                    }
                    
                    fm.exportOperations(args[1]);
                    System.out.println("Operations exported successfully");
                    break;
                    
                default:
                    System.out.println("Unknown command: " + command);
            }
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
        }
    }
} 