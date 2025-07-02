# 📁 Cursor AI Generated File Types Reference

**Comprehensive list of file types that Cursor AI Editor can generate for security testing**

## 🔴 **HIGH SECURITY RISK FILES**
*Files that commonly contain security vulnerabilities*

### **Backend Programming Languages**
- `.py` - Python scripts (Django, Flask, FastAPI)
- `.js` - JavaScript (Node.js, Express)
- `.ts` - TypeScript (Node.js, Deno)
- `.php` - PHP scripts (Laravel, WordPress)
- `.rb` - Ruby (Rails, Sinatra)
- `.java` - Java (Spring, Servlets)
- `.scala` - Scala (Play Framework)
- `.go` - Go/Golang (Gin, Echo)
- `.rs` - Rust (Actix, Rocket)
- `.cs` - C# (.NET, ASP.NET)
- `.kt` - Kotlin (Spring Boot)
- `.swift` - Swift (Vapor)

### **System & Shell Scripts**
- `.sh` - Bash shell scripts
- `.zsh` - Zsh scripts
- `.fish` - Fish shell scripts
- `.ps1` - PowerShell scripts
- `.bat` - Windows batch files
- `.cmd` - Windows command files

### **Compiled Languages**
- `.c` - C source code
- `.cpp` / `.cc` / `.cxx` - C++ source code
- `.h` / `.hpp` - Header files
- `.m` - Objective-C
- `.mm` - Objective-C++

### **Database & Query Languages**
- `.sql` - SQL scripts (MySQL, PostgreSQL, SQLite)
- `.plsql` - PL/SQL (Oracle)
- `.psql` - PostgreSQL scripts
- `.mongodb` - MongoDB queries
- `.cql` - Cassandra Query Language

## 🟠 **MEDIUM SECURITY RISK FILES**
*Files that may contain security issues*

### **Frontend Web Technologies**
- `.html` - HTML pages
- `.htm` - HTML pages (legacy)
- `.css` - Stylesheets
- `.scss` - Sass stylesheets
- `.sass` - Sass stylesheets (indented)
- `.less` - Less stylesheets
- `.jsx` - React JSX components
- `.tsx` - TypeScript JSX components
- `.vue` - Vue.js components
- `.svelte` - Svelte components

### **Mobile Development**
- `.dart` - Dart (Flutter)
- `.xml` - Android layouts/manifests
- `.gradle` - Gradle build scripts
- `.xcconfig` - Xcode configuration

### **Configuration Files**
- `.json` - JSON configuration
- `.yaml` / `.yml` - YAML configuration
- `.toml` - TOML configuration
- `.ini` - INI configuration
- `.conf` - Configuration files
- `.config` - Configuration files
- `.env` - Environment variables
- `.properties` - Java properties

### **Infrastructure as Code**
- `.tf` - Terraform
- `.hcl` - HashiCorp Configuration Language
- `.dockerfile` / `Dockerfile` - Docker containers
- `.docker-compose.yml` - Docker Compose
- `.k8s.yaml` - Kubernetes manifests
- `.helm` - Helm charts

### **Cloud & DevOps**
- `.aws` - AWS CLI configurations
- `.azure` - Azure configurations
- `.gcp` - Google Cloud configurations
- `.ansible.yml` - Ansible playbooks
- `.vagrant` - Vagrant configurations

## 🟡 **LOW SECURITY RISK FILES**
*Generally safer file types*

### **Documentation**
- `.md` - Markdown documentation
- `.rst` - reStructuredText
- `.txt` - Plain text files
- `.rtf` - Rich Text Format
- `.pdf` - PDF documents (if generated)

### **Data Files**
- `.csv` - Comma-separated values
- `.tsv` - Tab-separated values
- `.json` - JSON data
- `.xml` - XML data
- `.jsonl` - JSON Lines
- `.parquet` - Parquet data files

### **Templates & Markup**
- `.jinja` / `.jinja2` - Jinja templates
- `.mustache` - Mustache templates
- `.handlebars` - Handlebars templates
- `.ejs` - Embedded JavaScript templates
- `.erb` - Embedded Ruby templates
- `.twig` - Twig templates (PHP)
- `.liquid` - Liquid templates

### **Styling & Assets**
- `.svg` - SVG graphics
- `.ico` - Icon files
- `.png` / `.jpg` / `.jpeg` - Images (if generated)
- `.gif` - GIF images
- `.webp` - WebP images

## 🔵 **SPECIALIZED FILES**
*Framework and tool-specific files*

### **Package Managers**
- `package.json` - npm (Node.js)
- `yarn.lock` - Yarn lockfile
- `requirements.txt` - pip (Python)
- `Pipfile` - Pipenv (Python)
- `poetry.lock` - Poetry (Python)
- `Gemfile` - Bundler (Ruby)
- `Cargo.toml` - Cargo (Rust)
- `go.mod` - Go modules
- `pom.xml` - Maven (Java)
- `build.gradle` - Gradle (Java/Android)
- `composer.json` - Composer (PHP)

### **Build & CI/CD**
- `.github/workflows/*.yml` - GitHub Actions
- `.gitlab-ci.yml` - GitLab CI
- `.travis.yml` - Travis CI
- `.circleci/config.yml` - CircleCI
- `Makefile` - Make build scripts
- `CMakeLists.txt` - CMake
- `webpack.config.js` - Webpack
- `rollup.config.js` - Rollup
- `vite.config.js` - Vite

### **Testing Files**
- `*_test.py` - Python tests
- `*.test.js` - JavaScript tests
- `*.spec.js` - JavaScript specs
- `*_spec.rb` - Ruby specs
- `*Test.java` - Java tests
- `*_test.go` - Go tests

### **API & Protocol Files**
- `.proto` - Protocol Buffers
- `.graphql` - GraphQL schemas
- `.swagger.yml` - Swagger/OpenAPI
- `.postman.json` - Postman collections
- `.rest` - REST client files

### **Game Development**
- `.cs` - Unity C# scripts
- `.gd` - Godot scripts
- `.lua` - Lua scripts
- `.hlsl` - HLSL shaders
- `.glsl` - GLSL shaders

### **Data Science & ML**
- `.ipynb` - Jupyter notebooks
- `.r` - R scripts
- `.R` - R scripts
- `.rmd` - R Markdown
- `.py` - Python ML scripts
- `.scala` - Spark/Scala
- `.sas` - SAS scripts

### **Functional Programming**
- `.hs` - Haskell
- `.ml` - OCaml
- `.fs` - F#
- `.clj` - Clojure
- `.elm` - Elm
- `.ex` / `.exs` - Elixir
- `.erl` - Erlang

### **Legacy & Specialized**
- `.pl` - Perl scripts
- `.tcl` - Tcl scripts
- `.awk` - AWK scripts
- `.sed` - sed scripts
- `.vim` - Vim scripts
- `.powershell` - PowerShell modules

## 🎯 **SECURITY TESTING PRIORITIES**

### **Priority 1: Critical (Test First)**
1. **Python** (`.py`) - Most common AI generation
2. **JavaScript** (`.js`, `.ts`) - Web vulnerabilities
3. **Shell Scripts** (`.sh`, `.ps1`) - Command injection
4. **SQL** (`.sql`) - Injection attacks
5. **PHP** (`.php`) - Web application flaws

### **Priority 2: High (Regular Testing)**
1. **Java** (`.java`) - Enterprise applications
2. **HTML/CSS** (`.html`, `.css`) - XSS vectors
3. **Configuration** (`.json`, `.yaml`) - Misconfigurations
4. **Docker** (`Dockerfile`) - Container security
5. **Go/Rust** (`.go`, `.rs`) - Modern backend

### **Priority 3: Medium (Periodic Testing)**
1. **Mobile** (`.dart`, `.swift`, `.kt`) - App security
2. **Infrastructure** (`.tf`, `.k8s.yaml`) - Cloud security
3. **Templates** (`.jinja`, `.erb`) - Template injection
4. **Build Scripts** (`Makefile`, `*.gradle`) - Supply chain

### **Priority 4: Low (Occasional Testing)**
1. **Documentation** (`.md`, `.rst`) - Generally safe
2. **Data Files** (`.csv`, `.json`) - Data validation
3. **Assets** (`.svg`, `.ico`) - Rarely vulnerable

## 📊 **File Generation Statistics**

Based on typical Cursor AI usage patterns:

- **Python**: ~30% of generated files
- **JavaScript/TypeScript**: ~25% of generated files  
- **Configuration Files**: ~15% of generated files
- **HTML/CSS**: ~10% of generated files
- **Shell Scripts**: ~8% of generated files
- **Other Languages**: ~12% of generated files

## 💡 **Testing Recommendations**

### **For Comprehensive Testing:**
```bash
# Test top 10 most common types
python3 main.py --file test.py
python3 main.py --file test.js
python3 main.py --file test.ts
python3 main.py --file test.java
python3 main.py --file test.php
python3 main.py --file test.cpp
python3 main.py --file test.go
python3 main.py --file test.rs
python3 main.py --file script.sh
python3 main.py --file query.sql
```

### **For Quick Security Check:**
```bash
# Focus on highest-risk types
python3 main.py --file dangerous.py
python3 main.py --file exploit.js
python3 main.py --file injection.sql
python3 main.py --file command.sh
```

---

**💡 Tip**: Start with Python and JavaScript files as they're the most commonly generated by Cursor AI and have the highest vulnerability potential. 