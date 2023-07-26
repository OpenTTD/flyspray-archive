$NetBSD$

--- src/network/core/os_abstraction.h.orig	2010-02-10 21:06:05.000000000 +0000
+++ src/network/core/os_abstraction.h
@@ -127,7 +127,7 @@ static inline void OTTDfreeaddrinfo(stru
 
 /* UNIX stuff */
 #if defined(UNIX) && !defined(__OS2__)
-#	if defined(OPENBSD)
+#	if defined(OPENBSD) || defined(__NetBSD__)
 #		define AI_ADDRCONFIG 0
 #	endif
 #	define SOCKET int
