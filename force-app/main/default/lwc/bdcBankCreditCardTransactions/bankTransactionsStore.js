import {AbstractItemsStore, CommonUtils, SobjectUtils} from 'c/utils';

export default class bankTransactionsStore extends AbstractItemsStore {

  setItems(items) {
    this.values = items
      .map(item => this.copy(item))
      .map(item => this.setSObjectAttr(item))
      .map(item => this.flattenObject(item));
    this.clearChanges();
  }

  addAppliedItems(items) {
    let newItems = items
      .map(item => this.copy(item))
      .map(item => this.setSObjectAttr(item))
      .map(item => this.setAppliedAttr(item))
      .map(item => this.flattenObject(item));
    this.setAppliedItems(newItems);
  }

  setUnmatchedCreatedItems(items, removeError) {
    items.map(item => {
      this.setSObjectAttr(item);
      let index = this.values.findIndex(elem => elem.Id === item.Id);
      if (this.isProxyId(item) || !this.isStatusUnmatched(item)) {
        this.values.splice(index, 1);
      }
      else if (item.errors.length > 0 && !this.isProxyId(item) && index !== -1) {
        let newItem = item;
        if (removeError) {
          newItem = CommonUtils.copyObject(item);
          newItem.errors = [];
        }
        this.values[index] = newItem;
      }
      else if (item.errors.length === 0 && !this.isProxyId(item) && this.isStatusUnmatched(item) && this.isAccountingPeriod(item)) {
        item = this.setAppliedAttr(item)
        this.values.push(item);
      }
      return item;
    });
  }

  isStatusUnmatched = item => item.bt.obj.AcctSeed__Status__c === 'Unmatched';
  isAccountingPeriod = item => item.hasOwnProperty('accountingPeriodId');
  isProxyId = item => (item.proxyObj.obj.Id !== undefined && item.proxyObj.obj.Id != null);

  setMatchedCreatedItems(items, removeError) {
    items.map(item => {
      let newItem = item;
      if (removeError) {
        newItem = CommonUtils.copyObject(item);
        newItem.errors = [];
      }
      this.setSObjectAttr(newItem);
      let index = this.values.findIndex(elem => elem.Id === item.Id);
      if (index !== -1) {
        this.values[index] = newItem;
      }
      else {
        this.values.push(newItem);
      }
      return item;
    });
  }

  setAppliedItems(items) {
    items.map(item => {
      let index = this.values.findIndex(elem => elem.Id === item.Id);
      if (index !== -1 && !this.values[index].hasOwnProperty('rulesApplied') ) {
        this.values[index] = item;
      }
      return item;
    });
  }

  isRulesNotAppliedItemsByOffset(offset, pageSize) {
    return this.values.slice(offset, offset + pageSize).some(item => !item.hasOwnProperty('rulesApplied'));
  }

  setSObjectAttr = result => {
    SobjectUtils.setSobjectAttributes(result.proxyObj.obj, result.proxyObj.sobjType);
    SobjectUtils.setSobjectAttributes(result.shadowProxyObj.obj, result.shadowProxyObj.sobjType);
    result.possibleMatches.forEach(item => {
      SobjectUtils.setSobjectAttributes(item.possibleMatch.obj, item.possibleMatch.sobjType);
    });
    if (result.hasOwnProperty('defaultAppliedProxyObj')) {
      SobjectUtils.setSobjectAttributes(result.defaultAppliedProxyObj, result.proxyObj.sobjType);
    }

    if (Object.keys(result.bt.obj).some(item => item.indexOf("__r") !== -1)) {
      Object.keys(result.bt.obj).map(item => {
        if (item.indexOf("__r") !== -1) {
          result.bt.obj[item] = SobjectUtils.rewriteSubquery(result.bt.obj[item]);
        }
        return item;
      })
    }
    return result;
  }

  setAppliedAttr = result => {
    if (!result.hasOwnProperty('rulesApplied')) {
      result.rulesApplied = true;
    }
    return result;
  }
}