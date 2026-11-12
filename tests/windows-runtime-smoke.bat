@echo off
setlocal
set "ROOT=%~dp0.."
set "PHP=%ROOT%\server\bin\php\php-8.3.30-Win32-vs16-x64"
set "MYSQL=%ROOT%\server\bin\mysql\mysql-8.4.3-winx64\bin"

echo Checking PHP and required extensions...
"%PHP%\php.exe" -n -d "extension_dir=%PHP%\ext" -d extension=curl -d extension=fileinfo -d extension=gd -d extension=intl -d extension=mbstring -d extension=exif -d extension=mysqli -d extension=openssl -d extension=pdo_mysql -d extension=pdo_sqlite -d extension=sodium -d extension=sqlite3 -d extension=xsl -r "foreach (['curl','fileinfo','gd','intl','mbstring','exif','mysqli','openssl','pdo_mysql','pdo_sqlite','sodium','sqlite3','xsl'] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, 'Missing extension: ' . $e . PHP_EOL); exit(1); } } echo PHP_VERSION, PHP_EOL;"
if errorlevel 1 goto :failed

echo Checking MySQL client...
"%MYSQL%\mysql.exe" --no-defaults --version
if errorlevel 1 goto :failed

echo Checking MySQL server...
"%MYSQL%\mysqld.exe" --no-defaults --version
if errorlevel 1 goto :failed

echo Runtime smoke test passed.
exit /b 0

:failed
echo Runtime smoke test failed.
exit /b 1
