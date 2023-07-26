--- string_func.h.orig	2010-10-28 00:15:18.000000000 +0400
+++ string_func.h	2010-11-22 09:47:11.407665927 +0300
@@ -269,12 +269,12 @@
 }
 
 /* Needed for NetBSD version (so feature) testing */
-#ifdef __NetBSD__
+#if defined(__NetBSD__) || defined(__FreeBSD__)
 #include <sys/param.h>
 #endif
 
 /* strndup is a GNU extension */
-#if defined(_GNU_SOURCE) || (defined(__NetBSD_Version__) && 400000000 <= __NetBSD_Version__)
+#if defined(_GNU_SOURCE) || (defined(__NetBSD_Version__) && 400000000 <= __NetBSD_Version__) || (defined(__FreeBSD_version) && 720000 <= __FreeBSD_version)
 #	undef DEFINE_STRNDUP
 #else
 #	define DEFINE_STRNDUP
