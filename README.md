# CustomLaragonLite

## Portable Windows use

Copy the complete folder, including `server.exe` and the `server` directory,
to a writable location on a supported 64-bit Windows PC. Run `server.exe` as
usual (or `server.bat` for diagnostics). The PHP and MySQL executables are
64-bit, so they cannot run on 32-bit Windows. Windows 10/11 or a supported
Windows Server with the Windows Universal CRT is required.

The Microsoft Visual C++ runtime files are bundled next to both PHP and MySQL.
No separate Visual C++ redistributable installation or administrator access is
needed for these runtime DLLs. Keep the files in their respective directories;
do not copy them into Windows system folders. The app-local copies take
precedence over ordinary system copies, including an invalid system MSVCP140.
Other Windows corruption, unsupported Windows versions, or missing OS updates
are not repaired by these files.

To check the copied runtime on a clean client, run
`tests\windows-runtime-smoke.bat` from Command Prompt. It checks PHP, the
configured PHP extensions, and the MySQL client and server without starting a
database or modifying its data. Then start the application and verify MySQL
and Adminer normally. This does not diagnose unrelated port conflicts, data
files, permissions, or application configuration. This test deliberately bypasses
`php.ini`. That file currently contains the developer's absolute
`D:\AlphaPOS\server` path; if PHP extensions or sessions fail after copying,
update its `base_path` to the client's `server` folder. The bundled DLLs do not
fix that separate configuration issue.

The existing `server\data` folder is a MySQL data directory and may contain
private data and keys. Review it before distributing a copy.

## Bundled runtime provenance

The x64 `msvcp140.dll`, `vcruntime140.dll`, and `vcruntime140_1.dll` are the
unmodified Microsoft Visual C++ runtime files from the
[`msvc_runtime` 14.51.36231 Windows x64 wheel](https://pypi.org/project/msvc-runtime/14.51.36231/)
(third-party repackaging of the Microsoft redistributable). They are duplicated
in the PHP executable directory and the MySQL `bin` directory so Windows can
load them independently for either launcher. The wheel SHA-256 is
`89f70d1a37bb64164cdb09d02dd82d6b1400e1310be2995b4ed5a9f23efe2222`.
The DLLs' SHA-256 hashes are:

- `msvcp140.dll`: `7c26614e1d733892c2deac7e245ce115504b1d80592dd0a01b08e3e5a55f89ca`
- `vcruntime140.dll`: `d1f4225df2cd877dbf130d5668a021dce3f94118455ff5ec952061c30afc9ce7`
- `vcruntime140_1.dll`: `a7146c08f89fe5b04541ab507cdb59ff7b44534d4ba3c668a426c6450a03434e`

Microsoft's redistribution terms apply:
https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution
