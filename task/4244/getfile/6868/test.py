# -*- coding: utf-8 -*-

str = u"abcμε�έθους"

print 'in "%s" are bad:' % str

for c in str:
	if c <= unichr(0x1F) or (c >= unichr(0xE000) and c <= unichr(0xF7FF)) or (c >= unichr(0xFFF0) and c <= unichr(0xFFFF)):
		print '"%c", %i' % (c, ord(c))
