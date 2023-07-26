$NetBSD$

--- src/os/unix/crashlog_unix.cpp.orig	2010-01-18 10:11:27.000000000 +0000
+++ src/os/unix/crashlog_unix.cpp
@@ -27,6 +27,10 @@
 #	include <dlfcn.h>
 #endif
 
+#if defined(__NetBSD__)
+#include <unistd.h>
+#endif
+
 /**
  * Unix implementation for the crash logger.
  */
