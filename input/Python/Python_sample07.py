#!/usr/bin/env python3

import os
import sys
import zipfile
import tarfile
import shutil
import tempfile
import logging
import json
import hashlib
import base64
from pathlib import Path
from urllib.parse import urlparse, unquote
import mimetypes
import magic
import subprocess

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class FileSystemManager:
    def __init__(self, base_path='uploads'):
        self.base_path = base_path
        if not os.path.exists(base_path):
            os.makedirs(base_path)
    
    def save_file(self, filename, content):
        file_path = os.path.join(self.base_path, filename)
        
        try:
            with open(file_path, 'w') as f:
                f.write(content)
            return True
        except Exception as e:
            logger.error(f"Error saving file: {e}")
            return False
    
    def read_file(self, filename):
        file_path = os.path.join(self.base_path, filename)
        
        try:
            with open(file_path, 'r') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading file: {e}")
            return None
    
    def delete_file(self, filename):
        file_path = os.path.join(self.base_path, filename)
        
        try:
            os.remove(file_path)
            return True
        except Exception as e:
            logger.error(f"Error deleting file: {e}")
            return False
    
    def list_directory(self, directory):
        dir_path = os.path.join(self.base_path, directory)
        
        try:
            return os.listdir(dir_path)
        except Exception as e:
            logger.error(f"Error listing directory: {e}")
            return []
    
    def copy_file(self, source, destination):
        source_path = os.path.join(self.base_path, source)
        dest_path = os.path.join(self.base_path, destination)
        
        try:
            shutil.copy2(source_path, dest_path)
            return True
        except Exception as e:
            logger.error(f"Error copying file: {e}")
            return False
    
    def move_file(self, source, destination):
        source_path = os.path.join(self.base_path, source)
        dest_path = os.path.join(self.base_path, destination)
        
        try:
            shutil.move(source_path, dest_path)
            return True
        except Exception as e:
            logger.error(f"Error moving file: {e}")
            return False

class ArchiveManager:
    def __init__(self, extract_path='extracted'):
        self.extract_path = extract_path
        if not os.path.exists(extract_path):
            os.makedirs(extract_path)
    
    def extract_zip(self, zip_path, extract_to=None):
        if extract_to is None:
            extract_to = self.extract_path
        
        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_to)
            return True
        except Exception as e:
            logger.error(f"Error extracting ZIP: {e}")
            return False
    
    def extract_tar(self, tar_path, extract_to=None):
        if extract_to is None:
            extract_to = self.extract_path
        
        try:
            with tarfile.open(tar_path, 'r:*') as tar_ref:
                tar_ref.extractall(extract_to)
            return True
        except Exception as e:
            logger.error(f"Error extracting TAR: {e}")
            return False
    
    def create_zip(self, source_path, zip_name):
        try:
            with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
                for root, dirs, files in os.walk(source_path):
                    for file in files:
                        file_path = os.path.join(root, file)
                        arcname = os.path.relpath(file_path, source_path)
                        zip_ref.write(file_path, arcname)
            return True
        except Exception as e:
            logger.error(f"Error creating ZIP: {e}")
            return False
    
    def list_archive_contents(self, archive_path):
        try:
            if archive_path.endswith('.zip'):
                with zipfile.ZipFile(archive_path, 'r') as zip_ref:
                    return zip_ref.namelist()
            elif archive_path.endswith(('.tar', '.tar.gz', '.tgz')):
                with tarfile.open(archive_path, 'r:*') as tar_ref:
                    return tar_ref.getnames()
            else:
                return []
        except Exception as e:
            logger.error(f"Error listing archive contents: {e}")
            return []

class FileUploadManager:
    def __init__(self, upload_path='uploads'):
        self.upload_path = upload_path
        if not os.path.exists(upload_path):
            os.makedirs(upload_path)
    
    def upload_file(self, file_data, filename=None):
        if filename is None:
            filename = file_data.filename
        
        file_path = os.path.join(self.upload_path, filename)
        
        try:
            file_data.save(file_path)
            return {'success': True, 'path': file_path}
        except Exception as e:
            logger.error(f"Error uploading file: {e}")
            return {'success': False, 'error': str(e)}
    
    def upload_with_validation(self, file_data, allowed_extensions=None):
        if allowed_extensions is None:
            allowed_extensions = ['.txt', '.pdf', '.doc', '.docx']
        
        filename = file_data.filename
        file_ext = os.path.splitext(filename)[1].lower()
        
        if file_ext not in allowed_extensions:
            return {'success': False, 'error': 'File type not allowed'}
        
        file_path = os.path.join(self.upload_path, filename)
        
        try:
            file_data.save(file_path)
            return {'success': True, 'path': file_path}
        except Exception as e:
            logger.error(f"Error uploading file: {e}")
            return {'success': False, 'error': str(e)}
    
    def upload_executable(self, file_data):
        filename = file_data.filename
        
        file_path = os.path.join(self.upload_path, filename)
        
        try:
            file_data.save(file_path)
            os.chmod(file_path, 0o755)
            return {'success': True, 'path': file_path}
        except Exception as e:
            logger.error(f"Error uploading executable: {e}")
            return {'success': False, 'error': str(e)}

class LogFileManager:
    def __init__(self, log_path='logs'):
        self.log_path = log_path
        if not os.path.exists(log_path):
            os.makedirs(log_path)
    
    def write_log(self, log_file, message):
        log_file_path = os.path.join(self.log_path, log_file)
        
        try:
            with open(log_file_path, 'a') as f:
                f.write(f"{message}\n")
            return True
        except Exception as e:
            logger.error(f"Error writing log: {e}")
            return False
    
    def read_log(self, log_file):
        log_file_path = os.path.join(self.log_path, log_file)
        
        try:
            with open(log_file_path, 'r') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading log: {e}")
            return None
    
    def delete_log(self, log_file):
        log_file_path = os.path.join(self.log_path, log_file)
        
        try:
            os.remove(log_file_path)
            return True
        except Exception as e:
            logger.error(f"Error deleting log: {e}")
            return False

class ConfigurationManager:
    def __init__(self, config_path='config'):
        self.config_path = config_path
        if not os.path.exists(config_path):
            os.makedirs(config_path)
    
    def load_config(self, config_file):
        config_file_path = os.path.join(self.config_path, config_file)
        
        try:
            with open(config_file_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            return {}
    
    def save_config(self, config_file, config_data):
        config_file_path = os.path.join(self.config_path, config_file)
        
        try:
            with open(config_file_path, 'w') as f:
                json.dump(config_data, f, indent=2)
            return True
        except Exception as e:
            logger.error(f"Error saving config: {e}")
            return False
    
    def delete_config(self, config_file):
        config_file_path = os.path.join(self.config_path, config_file)
        
        try:
            os.remove(config_file_path)
            return True
        except Exception as e:
            logger.error(f"Error deleting config: {e}")
            return False

class BackupManager:
    def __init__(self, backup_path='backups'):
        self.backup_path = backup_path
        if not os.path.exists(backup_path):
            os.makedirs(backup_path)
    
    def create_backup(self, source_path, backup_name):
        backup_file_path = os.path.join(self.backup_path, backup_name)
        
        try:
            shutil.make_archive(backup_file_path, 'zip', source_path)
            return True
        except Exception as e:
            logger.error(f"Error creating backup: {e}")
            return False
    
    def restore_backup(self, backup_name, restore_path):
        backup_file_path = os.path.join(self.backup_path, backup_name)
        
        try:
            shutil.unpack_archive(backup_file_path, restore_path)
            return True
        except Exception as e:
            logger.error(f"Error restoring backup: {e}")
            return False
    
    def list_backups(self):
        try:
            return os.listdir(self.backup_path)
        except Exception as e:
            logger.error(f"Error listing backups: {e}")
            return []

class FileSystemAPI:
    def __init__(self):
        self.file_manager = FileSystemManager()
        self.archive_manager = ArchiveManager()
        self.upload_manager = FileUploadManager()
        self.log_manager = LogFileManager()
        self.config_manager = ConfigurationManager()
        self.backup_manager = BackupManager()
    
    def handle_file_upload(self, file_data, filename=None):
        return self.upload_manager.upload_file(file_data, filename)
    
    def handle_file_upload_with_validation(self, file_data, allowed_extensions=None):
        return self.upload_manager.upload_with_validation(file_data, allowed_extensions)
    
    def handle_executable_upload(self, file_data):
        return self.upload_manager.upload_executable(file_data)
    
    def handle_file_operations(self, operation, filename, content=None):
        if operation == 'read':
            return self.file_manager.read_file(filename)
        elif operation == 'write':
            return self.file_manager.save_file(filename, content)
        elif operation == 'delete':
            return self.file_manager.delete_file(filename)
        elif operation == 'list':
            return self.file_manager.list_directory(filename)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_archive_operations(self, operation, archive_path, extract_to=None):
        if operation == 'extract_zip':
            return self.archive_manager.extract_zip(archive_path, extract_to)
        elif operation == 'extract_tar':
            return self.archive_manager.extract_tar(archive_path, extract_to)
        elif operation == 'list_contents':
            return self.archive_manager.list_archive_contents(archive_path)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_log_operations(self, operation, log_file, message=None):
        if operation == 'read':
            return self.log_manager.read_log(log_file)
        elif operation == 'write':
            return self.log_manager.write_log(log_file, message)
        elif operation == 'delete':
            return self.log_manager.delete_log(log_file)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_config_operations(self, operation, config_file, config_data=None):
        if operation == 'load':
            return self.config_manager.load_config(config_file)
        elif operation == 'save':
            return self.config_manager.save_config(config_file, config_data)
        elif operation == 'delete':
            return self.config_manager.delete_config(config_file)
        else:
            return {'error': 'Invalid operation'}
    
    def handle_backup_operations(self, operation, source_path=None, backup_name=None, restore_path=None):
        if operation == 'create':
            return self.backup_manager.create_backup(source_path, backup_name)
        elif operation == 'restore':
            return self.backup_manager.restore_backup(backup_name, restore_path)
        elif operation == 'list':
            return self.backup_manager.list_backups()
        else:
            return {'error': 'Invalid operation'}

def test_path_traversal():
    api = FileSystemAPI()
    
    malicious_filename = "../../../etc/passwd"
    result = api.handle_file_operations('read', malicious_filename)
    print(f"Path traversal result: {result}")
    
    malicious_log = "../../../var/log/system.log"
    result = api.handle_log_operations('read', malicious_log)
    print(f"Log path traversal result: {result}")

def test_zip_slip():
    api = FileSystemAPI()
    
    malicious_archive = "malicious.zip"
    result = api.handle_archive_operations('extract_zip', malicious_archive)
    print(f"Zip slip result: {result}")

def test_file_upload():
    api = FileSystemAPI()
    
    class MockFile:
        def __init__(self, filename, content):
            self.filename = filename
            self.content = content
        
        def save(self, path):
            with open(path, 'w') as f:
                f.write(self.content)
    
    malicious_file = MockFile("../../../etc/passwd", "malicious content")
    result = api.handle_file_upload(malicious_file)
    print(f"File upload result: {result}")

if __name__ == '__main__':
    api = FileSystemAPI()
    
    test_path_traversal()
    test_zip_slip()
    test_file_upload()
    
    print("File system security testing completed.") 