-- Kotlin — JetBrains' official server, NOT the community
-- kotlin-language-server (which crashes on anything monorepo-sized).
--
--   brew install JetBrains/utils/kotlin-lsp
--
-- It bundles its own JBR, so no separate JDK is needed to *run* it.
-- JAVA_HOME still decides which JDK your code is analysed against.
--
-- Caveat worth knowing: it's based on IntelliJ internals and is partially
-- closed-source, and Kotlin Multiplatform support is still incomplete.
-- For plain JVM Gradle/Maven projects it's very good.

return {
  cmd = { "kotlin-lsp", "--stdio" },
  filetypes = { "kotlin" },
  root_markers = {
    "settings.gradle", "settings.gradle.kts",
    "build.gradle", "build.gradle.kts",
    "pom.xml",
    ".git",
  },
  init_options = {
    storagePath = vim.fn.stdpath("cache") .. "/kotlin-lsp",
  },
}
