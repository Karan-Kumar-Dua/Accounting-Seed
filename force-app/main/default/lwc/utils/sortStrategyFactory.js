export default class SortStrategyFactory {

  columns;

  constructor(columns = []) {
    this.columns = columns;
  }

  getSortStrategy(field, direction, extTransformFunc) {
    const fieldName = this.getFieldName(field);
    const type = this.getDataType(field);
    return this.getSortFn(fieldName, type, direction, extTransformFunc);
  }

  getColumn = (field) => this.columns.find(column => JSON.stringify(column.fieldName) === JSON.stringify(field));

  getDataType = (field) => this.getColumn(field).type;

  getFieldName(field) {
    const col = this.getColumn(field);
    if ((col.type === 'url' || col.type === 'customUrl')
          && col.typeAttributes.label !== undefined
          && col.typeAttributes.label.fieldName !== undefined) {

      return col.typeAttributes.label.fieldName;
    }
    return field;
  }

  getSortFn(field, type, direction, extTransformFunc) {
    let sortFn;
    const directionMultiplier = direction === 'desc' ? -1 : 1;

    switch (type) {
      case 'string':
      case 'text':
      case 'email':
      case 'url':
        if (typeof field === 'object') {
          sortFn = this.sortSobject(field, directionMultiplier, this.getProperty, extTransformFunc);
        }
        else {
          sortFn = this.sortString(field, directionMultiplier, this.getProperty, extTransformFunc);
        }
        break;
      case 'date':
        if (typeof field === 'object') {
          sortFn = this.sortSobject(field, directionMultiplier, this.getProperty, extTransformFunc);
        }
        else {
          sortFn = this.sortDate(field, directionMultiplier, this.getProperty, extTransformFunc);
        }
        break;
      default:
        if (typeof field === 'object') {
          sortFn = this.sortSobject(field, directionMultiplier, this.getProperty, extTransformFunc);
        }
        else {
          sortFn = this.sortAny(field, directionMultiplier, this.getProperty, extTransformFunc);
        }

    }
    return sortFn;
  }

  sortAny = (prop, directionMultiplier, getVal, extTransformFunc) => function(a, b) {
    let aV = a;
    let bV = b;
    let aVal, bVal;
    if (extTransformFunc !== undefined) {
      aV = extTransformFunc(a);
      bV = extTransformFunc(b);
    }
    if (prop.includes('__r.')) {
      aVal = aV[prop] !== undefined ? aV[prop] : "";
      bVal = bV[prop] !== undefined ? bV[prop] : "";
    }
    else {
      aVal = getVal(prop, aV) === undefined || getVal(prop, aV) === null || getVal(prop, aV) === 'undefined' || getVal(prop, aV) === 'null' ?
        "" : getVal(prop, aV);
      bVal = getVal(prop, bV) === undefined || getVal(prop, bV) === null || getVal(prop, bV) === 'undefined' || getVal(prop, bV) === 'null'  ?
        "" : getVal(prop, bV);
    }

    if (aVal > bVal) return 1 * directionMultiplier;
    if (aVal < bVal) return -1 * directionMultiplier;
    return 0;
  }

  sortDate = (prop, directionMultiplier, getVal, extTransformFunc) => function(a, b) {
    let aV = a;
    let bV = b;
    let aVal, bVal;
    if (extTransformFunc !== undefined) {
      aV = extTransformFunc(a);
      bV = extTransformFunc(b);
    }
    if (prop.includes('__r.')) {
      aVal = aV[prop] !== undefined ? aV[prop] : "";
      bVal = bV[prop] !== undefined ? bV[prop] : "";
    }
    else {
      aVal = getVal(prop, aV) === undefined || getVal(prop, aV) === null || getVal(prop, aV) === 'undefined' || getVal(prop, aV) === 'null' ?
          "" : getVal(prop, aV);
      bVal = getVal(prop, bV) === undefined || getVal(prop, bV) === null || getVal(prop, bV) === 'undefined' || getVal(prop, bV) === 'null'  ?
          "" : getVal(prop, bV);
    }

    if (new Date(aVal) > new Date(bVal)) return 1 * directionMultiplier;
    if (new Date(aVal) < new Date(bVal)) return -1 * directionMultiplier;
    return 0;
  }

  sortString = (prop, directionMultiplier, getVal, extTransformFunc) => function(a, b) {
    let aV = a;
    let bV = b;
    let propA, propB;

    if (extTransformFunc !== undefined) {
      aV = extTransformFunc(a);
      bV = extTransformFunc(b);
    }

    if (prop.includes('__r.')) {
      propA = aV[prop] !== undefined ? aV[prop].toUpperCase() : "";
      propB = bV[prop] !== undefined ? bV[prop].toUpperCase() : "";
    }
    else {
      propA = getVal(prop, aV) === undefined || getVal(prop, aV) === null || getVal(prop, aV) === 'undefined' || getVal(prop, aV) === 'null' ?
        "" : getVal(prop, aV).toUpperCase();
      propB = getVal(prop, bV) === undefined || getVal(prop, bV) === null || getVal(prop, bV) === 'undefined' || getVal(prop, bV) === 'null'  ?
        "" : getVal(prop, bV).toUpperCase();
    }

    if (propA > propB) return  1 * directionMultiplier;
    if (propA < propB) return -1 * directionMultiplier;
    return 0;
  }

  sortSobject = (prop, directionMultiplier, getVal, extTransformFunc) => function(a, b) {
    let aV = a;
    let bV = b;
    if (extTransformFunc !== undefined) {
      aV = extTransformFunc(a);
      bV = extTransformFunc(b);
    }

    const values = Object.values(prop);
    let propA = "";
    let propB = "";
    for (const val of values) {
      if (getVal(val, aV) !== undefined ) {
        propA = getVal(val, aV);
      }
      if (getVal(val, bV) !== undefined) {
        propB = getVal(val, bV);
      }
    }

    if (propA > propB) return  1 * directionMultiplier;
    if (propA < propB) return -1 * directionMultiplier;
    return 0;
  }

  getProperty = (prop, val) => prop.split('.').reduce((o,i)=>o[i], val);

}