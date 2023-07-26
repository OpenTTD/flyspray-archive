#!/usr/bin/env python

import select, socket, struct, sys, time

def recvall(s, lenn):
    r = ""
    while len(r) < lenn:
        rr = s.recv(lenn - len(r))
        if not rr: raise socket.error
        r += rr
    return r

next_time = 0
socks = []

while True:
    if time.time() >= next_time:
        if len(socks) < 4:
            socks.append(socket.socket())
            socks[-1].connect((sys.argv[1], int(sys.argv[2]) if len(sys.argv) >= 2 + 1 else 3977))
        next_time = time.time() + 7

    for r in select.select(socks, [], [], next_time - time.time())[0]:
        try:
            lenn, i = struct.unpack("<HB", recvall(r, 3))
            p = recvall(r, lenn - 3)
            print "Received packet, type %d" % i
            if i == 120:
                print "pwd: %r" % p
                sys.exit()
            elif i == 104:
                r.sendall("\x07\x00\x05pwd\0")
        except socket.error:
            socks.remove(r)
