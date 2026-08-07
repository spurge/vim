-- Swift. Ships with the Xcode toolchain, nothing to install — but it
-- only becomes useful once there's a Package.swift or an .xcodeproj for
-- it to derive a compilation database from. Bare .swift files give you
-- syntax and little else.

return {
  cmd = { "xcrun", "sourcekit-lsp" },
  filetypes = { "swift", "objc", "objcpp", "c", "cpp" },
  root_markers = {
    "Package.swift", "buildServer.json", "compile_commands.json",
    "*.xcodeproj", "*.xcworkspace", ".git",
  },
  -- sourcekit reports its own capabilities oddly; this keeps hover stable.
  capabilities = {
    workspace = {
      didChangeWatchedFiles = { dynamicRegistration = true },
    },
  },
}
