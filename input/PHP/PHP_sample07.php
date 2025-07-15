<?php

class VulnerableFileManager {
    private $rootDir = '.';
    private $uploadDir = 'uploads';
    private $logFile = 'filemgr.log';

    public function __construct() {
        $this->initDirs();
    }

    private function initDirs() {
        if (!is_dir($this->uploadDir)) {
            mkdir($this->uploadDir, 0777, true);
        }
    }

    public function handleRequest() {
        $action = $_GET['action'] ?? ($_SERVER['argc'] > 1 ? $_SERVER['argv'][1] : 'home');
        switch ($action) {
            case 'upload':
                $this->uploadFile();
                break;
            case 'download':
                $this->downloadFile();
                break;
            case 'list':
                $this->listFiles();
                break;
            case 'delete':
                $this->deleteFile();
                break;
            case 'zip':
                $this->createZip();
                break;
            case 'unzip':
                $this->extractZip();
                break;
            default:
                $this->showHome();
        }
    }

    private function showHome() {
        echo "<h1>Vulnerable File Manager</h1>";
        echo "<ul>";
        echo "<li><a href='?action=upload'>Upload File</a></li>";
        echo "<li><a href='?action=list'>List Files</a></li>";
        echo "<li><a href='?action=zip'>Create Zip</a></li>";
        echo "<li><a href='?action=unzip'>Extract Zip</a></li>";
        echo "</ul>";
    }

    private function uploadFile() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $file = $_FILES['file'] ?? null;
            if ($file && $file['error'] === UPLOAD_ERR_OK) {
                $filename = basename($file['name']);
                $target = $this->uploadDir . '/' . $filename;
                move_uploaded_file($file['tmp_name'], $target);
                $this->log("File uploaded: $filename");
                echo "<p>File uploaded: $filename</p>";
            } else {
                echo "<p>Upload failed</p>";
            }
        }
        echo "<form method='POST' enctype='multipart/form-data'><input type='file' name='file'><button type='submit'>Upload</button></form>";
    }

    private function downloadFile() {
        $file = $_GET['file'] ?? '';
        $filePath = $this->uploadDir . '/' . $file;
        if (file_exists($filePath)) {
            header('Content-Type: application/octet-stream');
            header('Content-Disposition: attachment; filename="' . basename($file) . '"');
            readfile($filePath);
            $this->log("File downloaded: $file");
            exit;
        } else {
            echo "<p>File not found</p>";
        }
        echo "<form method='GET'><input type='hidden' name='action' value='download'><input name='file' placeholder='Filename'><button type='submit'>Download</button></form>";
    }

    private function listFiles() {
        $files = scandir($this->uploadDir);
        echo "<h2>Files</h2><ul>";
        foreach ($files as $file) {
            if ($file === '.' || $file === '..') continue;
            echo "<li>$file <a href='?action=download&file=$file'>Download</a> <a href='?action=delete&file=$file'>Delete</a></li>";
        }
        echo "</ul>";
    }

    private function deleteFile() {
        $file = $_GET['file'] ?? '';
        $filePath = $this->uploadDir . '/' . $file;
        if (file_exists($filePath)) {
            unlink($filePath);
            $this->log("File deleted: $file");
            echo "<p>File deleted: $file</p>";
        } else {
            echo "<p>File not found</p>";
        }
        $this->listFiles();
    }

    private function createZip() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $zipName = $_POST['zipname'] ?? 'archive.zip';
            $files = $_POST['files'] ?? [];
            $zip = new ZipArchive();
            if ($zip->open($zipName, ZipArchive::CREATE) === TRUE) {
                foreach ($files as $file) {
                    $zip->addFile($this->uploadDir . '/' . $file, $file);
                }
                $zip->close();
                $this->log("Zip created: $zipName");
                echo "<p>Zip created: $zipName</p>";
            } else {
                echo "<p>Failed to create zip</p>";
            }
        }
        $files = scandir($this->uploadDir);
        echo "<form method='POST'><input name='zipname' placeholder='Zip name'><br>";
        foreach ($files as $file) {
            if ($file === '.' || $file === '..') continue;
            echo "<input type='checkbox' name='files[]' value='$file'>$file<br>";
        }
        echo "<button type='submit'>Create Zip</button></form>";
    }

    private function extractZip() {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $zipFile = $_POST['zipfile'] ?? '';
            $extractTo = $this->uploadDir;
            $zip = new ZipArchive();
            if ($zip->open($zipFile) === TRUE) {
                $zip->extractTo($extractTo);
                $zip->close();
                $this->log("Zip extracted: $zipFile");
                echo "<p>Zip extracted: $zipFile</p>";
            } else {
                echo "<p>Failed to extract zip</p>";
            }
        }
        echo "<form method='POST'><input name='zipfile' placeholder='Zip file'><button type='submit'>Extract Zip</button></form>";
    }

    private function log($msg) {
        file_put_contents($this->logFile, date('c') . " $msg\n", FILE_APPEND);
    }
}

$app = new VulnerableFileManager();
$app->handleRequest(); 