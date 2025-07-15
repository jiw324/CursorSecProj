#!/usr/bin/env ruby

require 'fileutils'
require 'zip'
require 'json'
require 'logger'
require 'securerandom'
require 'base64'
require 'yaml'
require 'pathname'
require 'mime/types'
require 'open3'

LOGGER = Logger.new(STDOUT)

class FileSystemManager
  def initialize(base_path = 'uploads')
    @base_path = base_path
    FileUtils.mkdir_p(base_path) unless Dir.exist?(base_path)
  end

  def save_file(filename, content)
    file_path = File.join(@base_path, filename)
    begin
      File.write(file_path, content)
      true
    rescue => e
      LOGGER.error("Error saving file: #{e}")
      false
    end
  end

  def read_file(filename)
    file_path = File.join(@base_path, filename)
    begin
      File.read(file_path)
    rescue => e
      LOGGER.error("Error reading file: #{e}")
      nil
    end
  end

  def delete_file(filename)
    file_path = File.join(@base_path, filename)
    begin
      File.delete(file_path)
      true
    rescue => e
      LOGGER.error("Error deleting file: #{e}")
      false
    end
  end

  def list_directory(directory)
    dir_path = File.join(@base_path, directory)
    begin
      Dir.entries(dir_path)
    rescue => e
      LOGGER.error("Error listing directory: #{e}")
      []
    end
  end

  def copy_file(source, destination)
    source_path = File.join(@base_path, source)
    dest_path = File.join(@base_path, destination)
    begin
      FileUtils.copy_file(source_path, dest_path)
      true
    rescue => e
      LOGGER.error("Error copying file: #{e}")
      false
    end
  end

  def move_file(source, destination)
    source_path = File.join(@base_path, source)
    dest_path = File.join(@base_path, destination)
    begin
      FileUtils.move(source_path, dest_path)
      true
    rescue => e
      LOGGER.error("Error moving file: #{e}")
      false
    end
  end
end

class ArchiveManager
  def initialize(extract_path = 'extracted')
    @extract_path = extract_path
    FileUtils.mkdir_p(extract_path) unless Dir.exist?(extract_path)
  end

  def extract_zip(zip_path, extract_to = nil)
    extract_to ||= @extract_path
    begin
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          entry.extract(File.join(extract_to, entry.name))
        end
      end
      true
    rescue => e
      LOGGER.error("Error extracting ZIP: #{e}")
      false
    end
  end

  def extract_tar(tar_path, extract_to = nil)
    extract_to ||= @extract_path
    begin
      system("tar -xf #{tar_path} -C #{extract_to}")
      $?.success?
    rescue => e
      LOGGER.error("Error extracting TAR: #{e}")
      false
    end
  end

  def create_zip(source_path, zip_name)
    begin
      Zip::File.open(zip_name, Zip::File::CREATE) do |zipfile|
        Dir.glob(File.join(source_path, '**', '*')).each do |file|
          next if File.directory?(file)
          arcname = file.sub(source_path + '/', '')
          zipfile.add(arcname, file)
        end
      end
      true
    rescue => e
      LOGGER.error("Error creating ZIP: #{e}")
      false
    end
  end

  def list_archive_contents(archive_path)
    begin
      if archive_path.end_with?('.zip')
        Zip::File.open(archive_path) do |zip_file|
          zip_file.map(&:name)
        end
      elsif archive_path.match(/\.tar(\.gz)?$/)
        stdout, stderr, status = Open3.capture3("tar -tf #{archive_path}")
        status.success? ? stdout.lines.map(&:chomp) : []
      else
        []
      end
    rescue => e
      LOGGER.error("Error listing archive contents: #{e}")
      []
    end
  end
end

class FileUploadManager
  def initialize(upload_path = 'uploads')
    @upload_path = upload_path
    FileUtils.mkdir_p(upload_path) unless Dir.exist?(upload_path)
  end

  def upload_file(file_data, filename = nil)
    filename ||= file_data[:filename]
    
    file_path = File.join(@upload_path, filename)
    
    begin
      File.write(file_path, file_data[:content])
      { success: true, path: file_path }
    rescue => e
      LOGGER.error("Error uploading file: #{e}")
      { success: false, error: e.to_s }
    end
  end

  def upload_with_validation(file_data, allowed_extensions = nil)
    allowed_extensions ||= ['.txt', '.pdf', '.doc', '.docx']
    
    filename = file_data[:filename]
    file_ext = File.extname(filename).downcase
    
    unless allowed_extensions.include?(file_ext)
      return { success: false, error: 'File type not allowed' }
    end
    
    file_path = File.join(@upload_path, filename)
    
    begin
      File.write(file_path, file_data[:content])
      { success: true, path: file_path }
    rescue => e
      LOGGER.error("Error uploading file: #{e}")
      { success: false, error: e.to_s }
    end
  end

  def upload_executable(file_data)
    filename = file_data[:filename]
    
    file_path = File.join(@upload_path, filename)
    
    begin
      File.write(file_path, file_data[:content])
      File.chmod(0o755, file_path)
      { success: true, path: file_path }
    rescue => e
      LOGGER.error("Error uploading executable: #{e}")
      { success: false, error: e.to_s }
    end
  end
end

class LogFileManager
  def initialize(log_path = 'logs')
    @log_path = log_path
    FileUtils.mkdir_p(log_path) unless Dir.exist?(log_path)
  end

  def write_log(log_file, message)
    log_file_path = File.join(@log_path, log_file)
    begin
      File.open(log_file_path, 'a') do |f|
        f.puts(message)
      end
      true
    rescue => e
      LOGGER.error("Error writing log: #{e}")
      false
    end
  end

  def read_log(log_file)
    log_file_path = File.join(@log_path, log_file)
    begin
      File.read(log_file_path)
    rescue => e
      LOGGER.error("Error reading log: #{e}")
      nil
    end
  end

  def delete_log(log_file)
    log_file_path = File.join(@log_path, log_file)
    begin
      File.delete(log_file_path)
      true
    rescue => e
      LOGGER.error("Error deleting log: #{e}")
      false
    end
  end
end

class ConfigurationManager
  def initialize(config_path = 'config')
    @config_path = config_path
    FileUtils.mkdir_p(config_path) unless Dir.exist?(config_path)
  end

  def load_config(config_file)
    config_file_path = File.join(@config_path, config_file)
    begin
      YAML.load_file(config_file_path)
    rescue => e
      LOGGER.error("Error loading config: #{e}")
      {}
    end
  end

  def save_config(config_file, config_data)
    config_file_path = File.join(@config_path, config_file)
    begin
      File.write(config_file_path, YAML.dump(config_data))
      true
    rescue => e
      LOGGER.error("Error saving config: #{e}")
      false
    end
  end

  def delete_config(config_file)
    config_file_path = File.join(@config_path, config_file)
    begin
      File.delete(config_file_path)
      true
    rescue => e
      LOGGER.error("Error deleting config: #{e}")
      false
    end
  end
end

class BackupManager
  def initialize(backup_path = 'backups')
    @backup_path = backup_path
    FileUtils.mkdir_p(backup_path) unless Dir.exist?(backup_path)
  end

  def create_backup(source_path, backup_name)
    backup_file_path = File.join(@backup_path, backup_name)
    begin
      system("tar -czf #{backup_file_path}.tar.gz -C #{File.dirname(source_path)} #{File.basename(source_path)}")
      $?.success?
    rescue => e
      LOGGER.error("Error creating backup: #{e}")
      false
    end
  end

  def restore_backup(backup_name, restore_path)
    backup_file_path = File.join(@backup_path, backup_name)
    begin
      system("tar -xzf #{backup_file_path} -C #{restore_path}")
      $?.success?
    rescue => e
      LOGGER.error("Error restoring backup: #{e}")
      false
    end
  end

  def list_backups
    begin
      Dir.entries(@backup_path)
    rescue => e
      LOGGER.error("Error listing backups: #{e}")
      []
    end
  end
end

class FileSystemAPI
  def initialize
    @file_manager = FileSystemManager.new
    @archive_manager = ArchiveManager.new
    @upload_manager = FileUploadManager.new
    @log_manager = LogFileManager.new
    @config_manager = ConfigurationManager.new
    @backup_manager = BackupManager.new
  end

  def handle_file_upload(file_data, filename = nil)
    @upload_manager.upload_file(file_data, filename)
  end

  def handle_file_upload_with_validation(file_data, allowed_extensions = nil)
    @upload_manager.upload_with_validation(file_data, allowed_extensions)
  end

  def handle_executable_upload(file_data)
    @upload_manager.upload_executable(file_data)
  end

  def handle_file_operations(operation, filename, content = nil)
    case operation
    when 'read'
      @file_manager.read_file(filename)
    when 'write'
      @file_manager.save_file(filename, content)
    when 'delete'
      @file_manager.delete_file(filename)
    when 'list'
      @file_manager.list_directory(filename)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_archive_operations(operation, archive_path, extract_to = nil)
    case operation
    when 'extract_zip'
      @archive_manager.extract_zip(archive_path, extract_to)
    when 'extract_tar'
      @archive_manager.extract_tar(archive_path, extract_to)
    when 'list_contents'
      @archive_manager.list_archive_contents(archive_path)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_log_operations(operation, log_file, message = nil)
    case operation
    when 'read'
      @log_manager.read_log(log_file)
    when 'write'
      @log_manager.write_log(log_file, message)
    when 'delete'
      @log_manager.delete_log(log_file)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_config_operations(operation, config_file, config_data = nil)
    case operation
    when 'load'
      @config_manager.load_config(config_file)
    when 'save'
      @config_manager.save_config(config_file, config_data)
    when 'delete'
      @config_manager.delete_config(config_file)
    else
      { error: 'Invalid operation' }
    end
  end

  def handle_backup_operations(operation, source_path = nil, backup_name = nil, restore_path = nil)
    case operation
    when 'create'
      @backup_manager.create_backup(source_path, backup_name)
    when 'restore'
      @backup_manager.restore_backup(backup_name, restore_path)
    when 'list'
      @backup_manager.list_backups
    else
      { error: 'Invalid operation' }
    end
  end
end

def test_path_traversal
  api = FileSystemAPI.new
  
  malicious_filename = '../../../etc/passwd'
  result = api.handle_file_operations('read', malicious_filename)
  puts "Path traversal result: #{result}"
  
  malicious_log = '../../../var/log/system.log'
  result = api.handle_log_operations('read', malicious_log)
  puts "Log path traversal result: #{result}"
end

def test_zip_slip
  api = FileSystemAPI.new
  
  malicious_archive = 'malicious.zip'
  result = api.handle_archive_operations('extract_zip', malicious_archive)
  puts "Zip slip result: #{result}"
end

def test_file_upload
  api = FileSystemAPI.new
  
  malicious_file = {
    filename: '../../../etc/passwd',
    content: 'malicious content'
  }
  result = api.handle_file_upload(malicious_file)
  puts "File upload result: #{result}"
end

if __FILE__ == $0
  api = FileSystemAPI.new
  
  test_path_traversal
  test_zip_slip
  test_file_upload
  
  puts "File system security testing completed."
end 