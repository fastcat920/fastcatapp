VC++ Runtime DLLs (兜底方案)
=============================

CI 构建流程（.github/workflows/build-client.yml）会自动在此目录放置以下文件
（从已安装的 VS Build Tools 中复制）：

  msvcp140.dll
  vcruntime140.dll
  vcruntime140_1.dll

CMakeLists.txt 会自动将这些 DLL 打包到安装目录（与 exe 同目录），
作为 Inno Setup 运行 vc_redist.x64.exe 安装器之外的兜底保障。
如果后续需要按架构区分，也可以放到 windows/vc_redist/x64 或
windows/vc_redist/ARM64 等与 CMAKE_SYSTEM_PROCESSOR 对应的子目录。

本地构建时，如需手动获取这些 DLL：
  方法 1：从 VS 安装目录复制
    VS 2022: C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\<version>\x64\Microsoft.VC143.CRT\
    VS 2019: C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Redist\MSVC\<version>\x64\Microsoft.VC143.CRT\

  方法 2：从 Microsoft 下载 vc_redist.x64.exe 后用 7-Zip 解压提取
    https://aka.ms/vs/17/release/vc_redist.x64.exe
