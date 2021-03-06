part of mongo_dart;
class Connection{
  Map<int,Completer<MongoReplyMessage>> _replyCompleters;
  BsonBinary _lengthBuffer;
  ServerConfig serverConfig;
  BsonBinary _bufferToSend;
  Queue<MongoMessage> _sendQueue;
  BsonBinary _messageBuffer;
  Socket socket;
  List _incompleteLengthBytes = [];
  StreamSubscription<List<int>> _socketSubscription;
  bool connected = false;
  Connection([this.serverConfig]){
    if (serverConfig == null){
      serverConfig = new ServerConfig();
    }
  }
  Future<bool> connect(){
    _replyCompleters = new Map();
    _sendQueue = new Queue();
    _lengthBuffer = new BsonBinary(4);    
    Completer completer = new Completer();   
    Socket.connect(serverConfig.host, serverConfig.port).then((Socket _socket) {
      /* Socket connected. */
      socket = _socket;
      _socketSubscription = socket.listen(_receiveData,onError: (e) {
        print("connect exception ${e}");
        completer.completeError(e);
      });
      connected = true;
      completer.complete(true);
    });
    return completer.future;
  }
  
  void close(){
    while (!_sendQueue.isEmpty){
      _sendBuffer();
    }
    _sendQueue.clear();
    socket.close();
    _replyCompleters.clear();
  }
  _getNextBufferToSend(){
    if (_bufferToSend == null || _bufferToSend.atEnd()){
      if(!_sendQueue.isEmpty){
        MongoMessage message = _sendQueue.removeFirst();
        _log.finer(message.toString());
        _bufferToSend = message.serialize();
        _log.finer(_bufferToSend.hexString);
      } else {
        _bufferToSend = null;
      }
    }
  }
  _sendBuffer(){
    while(_sendQueue.length > 0) {
      _bufferToSend = _sendQueue.removeFirst().serialize();
      socket.writeBytes(_bufferToSend.byteList);
    }
  }
  void _receiveData(List<int> data, [int offset = 0, int recursion = 0]) {
    if (_messageBuffer == null){
      if (data.length - offset < 4) {
        _incompleteLengthBytes = data.sublist(offset);
        return;
      }
      _lengthBuffer.byteList.setRange(0, _incompleteLengthBytes.length, _incompleteLengthBytes, offset);     
      _lengthBuffer.byteList.setRange(0 + _incompleteLengthBytes.length, 4 - _incompleteLengthBytes.length, data, offset);
      int messageLength = _lengthBuffer.readInt32();
      if (messageLength == 0) {
        return;
      }
      _messageBuffer = new BsonBinary(messageLength);
      _messageBuffer.byteList.setRange(0, 4 , _lengthBuffer.byteList);   
      _messageBuffer.offset += 4;
      offset += 4 - _incompleteLengthBytes.length;
      _incompleteLengthBytes = [];
    }
    int delta = min(data.length - offset,_messageBuffer.byteList.length-_messageBuffer.offset);
    //print('offset:$offset delta:$delta data.length:${data.length} message.lenght:${_messageBuffer.byteList.length}');
    //***** temporary safety hatch
    if (recursion > 20) {
      return;
    }
    _messageBuffer.byteList.setRange(_messageBuffer.offset, delta , data, offset);
    _messageBuffer.offset += delta;
    if (_messageBuffer.atEnd()){
      MongoReplyMessage reply = new MongoReplyMessage();
      _messageBuffer.rewind();
      reply.deserialize(_messageBuffer);
      _log.finer(reply.toString());
      _messageBuffer = null;
      _lengthBuffer.rewind();
      Completer completer = _replyCompleters.remove(reply.responseTo);
      if (completer != null){
        completer.complete(reply);
      }
      else {
        _log.fine("Unexpected respondTo: ${reply.responseTo} ${reply.documents[0]}");
      }
      if (delta + offset < data.length) {
        _receiveData(data, delta + offset, recursion + 1); 
      }  
    }
  }
  Future<MongoReplyMessage> query(MongoMessage queryMessage){
    Completer completer = new Completer();
    _replyCompleters[queryMessage.requestId] = completer;
    _sendQueue.addLast(queryMessage);
    _sendBuffer();
    return completer.future;
  }
  void execute(MongoMessage mongoMessage){
    _sendQueue.addLast(mongoMessage);
    _sendBuffer();
  }
}
