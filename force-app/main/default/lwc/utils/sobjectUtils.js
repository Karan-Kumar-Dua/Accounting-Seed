export default class SobjectUtils {

  static rewriteSubquery = (array) => {
    if (array && !array.hasOwnProperty('records')) {
      let tempArray = array;
      array = {
        totalSize: tempArray.length,
        done: true,
        records: tempArray
      }
    }
    return array;
  };

  static setSobjectAttributes = (obj, sobjType) => {
    if (!obj.hasOwnProperty('attributes')) {
      obj.attributes = {type : sobjType};
    }
  }

}