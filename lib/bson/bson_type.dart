class ElementPair{
  String name;
  var value;
  ElementPair([this.name,this.value]);
}
class BsonObject {  
  int get typeByte(){ throw const Exception("must be implemented");}
  int byteLength() => 0;
  packElement(String name, var buffer){
    buffer.writeByte(typeByte);
    if (name !== null){
      new BsonCString(name).packValue(buffer);
    }
    packValue(buffer);
  } 
  packValue(var buffer){ throw const Exception("must be implemented");}

  ElementPair unpackElement(buffer){
    ElementPair result = new ElementPair();
    result.name = buffer.readCString();    
    unpackValue(buffer);
    result.value = value;
    return result;
  }
  uppackValue(var buffer){ throw const Exception("must be implemented");}
  get value()=>null;
}

 int elementSize(name, value) {
    int size = 1;
    if (name !== null){
      size += name.length + 1;
    } 
    size += bsonObjectFrom(value).byteLength();
    return size;
  }
BsonObject bsonObjectFrom(var value){
  if (value is BsonObject){
    return value;
  }
  if (value is int){
    return new BsonInt(value);
  }    
  if (value is num){
    return new BsonDouble(value);
  } 

  if (value is String){
    return new BsonString(value);
  }        
  if (value is Map){
    return new BsonMap(value);
  }        
  if (value is List){
    return new BsonArray(value);
  }        
  throw new Exception("Not implemented for $value");           
}  

BsonObject bsonObjectFromTypeByte(int typeByte){
  switch(typeByte){
    case BSON.BSON_DATA_INT:
      return new BsonInt(null);
    case BSON.BSON_DATA_NUMBER:
      return new BsonDouble(null);
    case BSON.BSON_DATA_STRING:
      return new BsonString(null);
    case BSON.BSON_DATA_ARRAY:
      return new BsonArray([]);
    case BSON.BSON_DATA_OBJECT:
      return new BsonMap({});
    default:
      throw new Exception("Not implemented for BSON TYPE $typeByte");           
  }  
}
