$NetBSD$

--- /usr/build/local/openttd/work/openttd-1.0.1/src/string_func.h.orig	2010-01-26 14:04:56.000000000 +0000
+++ /usr/build/local/openttd/work/openttd-1.0.1/src/string_func.h
@@ -246,13 +246,18 @@ static inline bool IsWhitespace(WChar c)
 	;
 }
 
-#ifndef _GNU_SOURCE
+/* Needed for NetBSD version (so feature) testing */
+#ifdef __NetBSD__
+#include <sys/param.h>
+#endif
+
+#if !defined(_GNU_SOURCE) && !(defined(__NetBSD_Version__) && 400000000 < __NetBSD_Version__ )
 /* strndup is a GNU extension */
 char *strndup(const char *s, size_t len);
 #endif /* !_GNU_SOURCE */
 
 /* strcasestr is available for _GNU_SOURCE, BSD and some Apple */
-#if defined(_GNU_SOURCE) || (defined(__BSD_VISIBLE) && __BSD_VISIBLE) || (defined(__APPLE__) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)))
+#if defined(_GNU_SOURCE) || (defined(__BSD_VISIBLE) && __BSD_VISIBLE) || (defined(__APPLE__) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))) || _NETBSD_SOURCE
 #	undef DEFINE_STRCASESTR
 #else
 #	define DEFINE_STRCASESTR
