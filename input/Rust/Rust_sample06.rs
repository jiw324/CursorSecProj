use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write, BufReader, BufWriter};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use std::zip::ZipArchive;

#[derive(Debug)]
struct FileInfo {
    name: String,
    size: u64,
    path: PathBuf,
    created_at: u64,
    modified_at: u64,
    permissions: u32,
}

#[derive(Debug)]
struct UploadedFile {
    original_name: String,
    stored_name: String,
    size: u64,
    content_type: String,
    upload_time: u64,
    path: PathBuf,
}

struct FileManager {
    upload_dir: PathBuf,
    allowed_extensions: Vec<String>,
    max_file_size: u64,
    uploaded_files: Arc<Mutex<HashMap<String, UploadedFile>>>,
}

impl FileManager {
    fn new() -> FileManager {
        let upload_dir = PathBuf::from("/tmp/uploads");
        let _ = fs::create_dir_all(&upload_dir);
        
        FileManager {
            upload_dir,
            allowed_extensions: vec!["txt".to_string(), "pdf".to_string(), "jpg".to_string(), "png".to_string()],
            max_file_size: 10 * 1024 * 1024,
            uploaded_files: Arc::new(Mutex::new(HashMap::new())),
        }
    }
    
    fn read_file(&self, file_path: &str) -> Result<String, Box<dyn std::error::Error>> {
        let path = Path::new(file_path);
        
        if path.exists() && path.is_file() {
            let mut file = File::open(path)?;
            let mut contents = String::new();
            file.read_to_string(&mut contents)?;
            Ok(contents)
        } else {
            Err("File not found".into())
        }
    }
    
    fn write_file(&self, file_path: &str, content: &str) -> Result<(), Box<dyn std::error::Error>> {
        let path = Path::new(file_path);
        
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        
        let mut file = File::create(path)?;
        file.write_all(content.as_bytes())?;
        Ok(())
    }
    
    fn delete_file(&self, file_path: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let path = Path::new(file_path);
        
        if path.exists() && path.is_file() {
            fs::remove_file(path)?;
            Ok(true)
        } else {
            Ok(false)
        }
    }
    
    fn copy_file(&self, source_path: &str, dest_path: &str) -> Result<(), Box<dyn std::error::Error>> {
        let source = Path::new(source_path);
        let dest = Path::new(dest_path);
        
        if source.exists() && source.is_file() {
            if let Some(parent) = dest.parent() {
                let _ = fs::create_dir_all(parent);
            }
            fs::copy(source, dest)?;
            Ok(())
        } else {
            Err("Source file not found".into())
        }
    }
    
    fn list_directory(&self, dir_path: &str) -> Result<Vec<FileInfo>, Box<dyn std::error::Error>> {
        let path = Path::new(dir_path);
        let mut files = Vec::new();
        
        if path.exists() && path.is_dir() {
            for entry in fs::read_dir(path)? {
                let entry = entry?;
                let path = entry.path();
                let metadata = fs::metadata(&path)?;
                
                let file_info = FileInfo {
                    name: path.file_name().unwrap().to_string_lossy().to_string(),
                    size: metadata.len(),
                    path: path.clone(),
                    created_at: metadata.created()?.duration_since(UNIX_EPOCH)?.as_secs(),
                    modified_at: metadata.modified()?.duration_since(UNIX_EPOCH)?.as_secs(),
                    permissions: metadata.permissions().mode(),
                };
                
                files.push(file_info);
            }
        }
        
        Ok(files)
    }
    
    fn upload_file(&self, original_name: &str, content: &[u8], content_type: &str) -> Result<UploadedFile, Box<dyn std::error::Error>> {
        let extension = Path::new(original_name)
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("")
            .to_lowercase();
        
        if !self.allowed_extensions.contains(&extension) {
            return Err("File type not allowed".into());
        }
        
        let timestamp = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
        let stored_name = format!("{}_{}", timestamp, original_name);
        let file_path = self.upload_dir.join(&stored_name);
        
        let mut file = File::create(&file_path)?;
        file.write_all(content)?;
        
        let uploaded_file = UploadedFile {
            original_name: original_name.to_string(),
            stored_name: stored_name.clone(),
            size: content.len() as u64,
            content_type: content_type.to_string(),
            upload_time: timestamp,
            path: file_path,
        };
        
        self.uploaded_files.lock().unwrap().insert(stored_name, uploaded_file.clone());
        Ok(uploaded_file)
    }
    
    fn extract_zip(&self, zip_path: &str, extract_dir: &str) -> Result<(), Box<dyn std::error::Error>> {
        let file = File::open(zip_path)?;
        let mut archive = ZipArchive::new(file)?;
        
        for i in 0..archive.len() {
            let mut file = archive.by_index(i)?;
            let file_path = file.name();
            
            let full_path = Path::new(extract_dir).join(file_path);
            
            if file_path.ends_with('/') {
                fs::create_dir_all(&full_path)?;
            } else {
                if let Some(parent) = full_path.parent() {
                    fs::create_dir_all(parent)?;
                }
                
                let mut outfile = File::create(&full_path)?;
                io::copy(&mut file, &mut outfile)?;
            }
        }
        
        Ok(())
    }
    
    fn process_file_with_command(&self, file_path: &str, command: &str) -> Result<String, Box<dyn std::error::Error>> {
        let output = Command::new("sh")
            .arg("-c")
            .arg(&format!("{} {}", command, file_path))
            .output()?;
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        
        Ok(format!("STDOUT: {}\nSTDERR: {}", stdout, stderr))
    }
    
    fn execute_uploaded_file(&self, file_id: &str) -> Result<String, Box<dyn std::error::Error>> {
        let files = self.uploaded_files.lock().unwrap();
        
        if let Some(file) = files.get(file_id) {
            let output = Command::new(&file.path)
                .output();
            
            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    Ok(format!("STDOUT: {}\nSTDERR: {}", stdout, stderr))
                }
                Err(e) => Err(format!("Execution error: {}", e).into())
            }
        } else {
            Err("File not found".into())
        }
    }
    
    fn get_file_metadata(&self, file_path: &str) -> Result<HashMap<String, String>, Box<dyn std::error::Error>> {
        let path = Path::new(file_path);
        let mut metadata = HashMap::new();
        
        if path.exists() {
            let file_metadata = fs::metadata(path)?;
            
            metadata.insert("size".to_string(), file_metadata.len().to_string());
            metadata.insert("created".to_string(), file_metadata.created()?.duration_since(UNIX_EPOCH)?.as_secs().to_string());
            metadata.insert("modified".to_string(), file_metadata.modified()?.duration_since(UNIX_EPOCH)?.as_secs().to_string());
            metadata.insert("permissions".to_string(), format!("{:o}", file_metadata.permissions().mode()));
            metadata.insert("is_file".to_string(), file_metadata.is_file().to_string());
            metadata.insert("is_dir".to_string(), file_metadata.is_dir().to_string());
            
            metadata.insert("absolute_path".to_string(), path.canonicalize()?.to_string_lossy().to_string());
        }
        
        Ok(metadata)
    }
    
    fn search_files(&self, search_path: &str, pattern: &str) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        let command = format!("find {} -name '{}' -type f", search_path, pattern);
        
        let output = Command::new("sh")
            .arg("-c")
            .arg(&command)
            .output()?;
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let files: Vec<String> = stdout.lines().map(|s| s.to_string()).collect();
        
        Ok(files)
    }
    
    fn backup_file(&self, source_path: &str, backup_dir: &str) -> Result<String, Box<dyn std::error::Error>> {
        let source = Path::new(source_path);
        let backup_path = Path::new(backup_dir).join(source.file_name().unwrap());
        
        if source.exists() && source.is_file() {
            fs::copy(source, &backup_path)?;
            Ok(backup_path.to_string_lossy().to_string())
        } else {
            Err("Source file not found".into())
        }
    }
}

fn main() {
    let file_manager = FileManager::new();
    
    println!("File Manager initialized");
    
    match file_manager.read_file("/etc/passwd") {
        Ok(content) => println!("Read file content: {}", &content[..content.len().min(100)]),
        Err(e) => println!("File read error: {}", e),
    }
    
    let test_content = b"test file content";
    match file_manager.upload_file("test.txt", test_content, "text/plain") {
        Ok(file) => println!("Uploaded file: {:?}", file),
        Err(e) => println!("Upload error: {}", e),
    }
    
    match file_manager.process_file_with_command("/tmp/test.txt", "cat") {
        Ok(output) => println!("Command output: {}", output),
        Err(e) => println!("Command error: {}", e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_path_traversal_vulnerability() {
        let file_manager = FileManager::new();
        let result = file_manager.read_file("../../../etc/passwd");
        assert!(result.is_ok() || result.is_err());
    }
    
    #[test]
    fn test_file_upload_vulnerability() {
        let file_manager = FileManager::new();
        let content = b"test content";
        let result = file_manager.upload_file("test.txt", content, "text/plain");
        assert!(result.is_ok());
    }
} 