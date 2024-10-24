import CURRENCY from '@salesforce/i18n/currency';

export default class AbstractItemsStore {
  values = [];                        // all records
  changes = [];                      // changed records
  currencyCode = CURRENCY;                       // currency code to apply
  isMultiCurrencyEnabled = false;     // multi currency enabled for org
  editable = true;                    // are fields editable
  idKey = 'id';
  financialInstitutionsName = [];

  clearItems() {
    this.values = [];
  }

  setEditable(isEditable) {
    this.editable = isEditable;
    this.values = this.values.map(item => {
      return { ...item, editable: this.editable }
    });
  }

  getItems() {
    return this.values;
  }

  getItemsByOffset(offset, pageSize) {
    return this.values.slice(offset, offset + pageSize);
  }

  setItems(items) {
    if (items) {
    this.values = items
      .map(item => this.copy(item))
      .map(item => this.addDerivedFields(item))
      .map(item => this.flattenObject(item));
    } else {
      this.values = items;
    }
    this.clearChanges();
  }

  getItem(itemId) {
    let item = this.values.find(value => value[this.idKey] === itemId);
    return {...item};
  }

  flattenObject(obj) {
    const flattened = {};
    Object.keys(obj).forEach((key) => {
      if (typeof obj[key] === 'object' && obj[key] !== null && key === 'extraFields') {
        Object.assign(flattened, this.flattenObject(obj[key]));
      } else {
        flattened[key] = obj[key];
      }
    });
    if (!this.financialInstitutionsName.includes(obj.financialInstitutionName)) {
      this.financialInstitutionsName.push(obj.financialInstitutionName);
    }
    return flattened;
  }

  getAllFinancialInstitutionsName(){
    return this.financialInstitutionsName;
  }

  clearChanges() {
    this.changes = [];
  }

  getChanges() {
    return this.values.filter(value => this.changes.includes(value[this.idKey]));
  }

  copy(item) {
    let clone = {...item};
    if (item.extraColumns) {
      clone.extraColumns = [...item.extraColumns];
    }
    return clone;
  }

  sort(sortFn) {
    this.values = this.values.slice().sort((a,b) => sortFn(a, b));
  }

  setCurrency(isoCode, isMultiCurrencyEnabled) {
    this.currencyCode = isoCode;
    this.isMultiCurrencyEnabled = isMultiCurrencyEnabled;
    if (isoCode && this.values.length > 0) {
      this.values = this.values.map(item => ({ ...item, currency: isoCode, isMultiCurrencyEnabled: isMultiCurrencyEnabled }));
    }
  }

  updateItem(item) {
    this.values = this.values.map(value => { return value[this.idKey] === item[this.idKey] ? item : value });
    if (!this.changes.includes(item[this.idKey])) {
      this.changes.push(item[this.idKey]);
    }
  }

  hasErrors() {
    return this.values.find(item => item.errors.length > 0) ? true : false;
  }

  addError(itemId, fieldname, msg) {
    let item = this.getItem(itemId);
    if (item.errors.length !== 0) {
      item.errors.push({
        column: fieldname,
        msg: msg
      });
    } else {
      item.errors = [{
        column: fieldname,
        msg: msg
      }];
    }
    this.updateItem(item);
  }

  removeError(itemId, fieldname) {
    this.values = this.values.map(value => {
      if (value[this.idKey] === itemId) {
        value.errors = value.errors.filter(e => e.column !== fieldname);
      }
      return value;
    });
  }

  getUniqItems(items) {
    let result = [];
    items.map(item => {
      if (!this.values.some(elem => elem[this.idKey] === item[this.idKey])) {
        result.push(item);
      }
      return item;
    });
    return result;
  }

  addDerivedFields = item => {
    let update = {...item};
    update = this.addCurrency(update);
    update = this.addErrors(update);
    return update;
  }

  addErrors = item => {
    item.errors = [];
    return item;
  };

  addCurrency = item => {
    item.currency = this.currencyCode;
    item.isMultiCurrencyEnabled = this.isMultiCurrencyEnabled;
    return item;
  }

  addEditable = item => {
    item.editable = this.editable;
    return item;
  }
}