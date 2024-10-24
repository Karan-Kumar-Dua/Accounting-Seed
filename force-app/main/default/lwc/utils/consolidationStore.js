import AbstractItemsStore from './abstractItemsStore';
import CommonUtils from './commonUtils';

export default class ConsolidationStore extends AbstractItemsStore {

    constructor(ledgerHierarchy){
      super();
      this.lh = ledgerHierarchy;
    }

    itemsMapByParent;
    idKey = 'Id';
  
    addItems(data) {
      let items = data.rows;
      this.getItemsMap(items);
      let newItems = items
        .map(item => this.copy(item))
        .map(item => this.addDerivedFields(item))
        .map(item => this.setChildren(item))
        .filter(item => !item[this.lh.parentLedgerHierarchy])
        .sort((a,b) => this.sortBySortOrder(a, b));
      this.values = newItems;
    }

    getItemsMap(items) {
        this.itemsMapByParent = items.reduce((result, item) => {
            if (item[this.lh.parentLedgerHierarchy]) {
                if (!Object.keys(result).includes(item[this.lh.parentLedgerHierarchy])) {
                    result[item[this.lh.parentLedgerHierarchy]] = [this.addDerivedFields(item)];
                }
                else {
                    result[item[this.lh.parentLedgerHierarchy]].push(this.addDerivedFields(item));
                }
            }
            return result;
        },{});
    }

    isAllLedgerTypeValues(existedPickList, reqValues) {
        return reqValues.every(item => existedPickList.includes(item))
    }

    getItemsList(row) {
        return row[this.lh.parentLedgerHierarchy] ? this.getChildrenList(row[this.lh.parentLedgerHierarchy]) : this.values;
      }
    
    getChildrenList(parentLedgerId) {
        return this.itemsMapByParent[parentLedgerId] ? this.itemsMapByParent[parentLedgerId] : [];
      }

    sortBySortOrder = (a, b) => {
        if (a[this.lh.sort_order] < b[this.lh.sort_order]) {
            return -1
        }
        if (a[this.lh.sort_order] > b[this.lh.sort_order]) {
            return 1
        }
        return 0
    }

    getSortOrderValue = (item, newVal, oldVal) => {
        if (item[this.lh.sort_order] < this.getMinValue(newVal, oldVal) || item[this.lh.sort_order] > this.getMaxValue(newVal, oldVal) ) {
          return item[this.lh.sort_order];
        }
        else if (item[this.lh.sort_order] >= newVal && item[this.lh.sort_order] < oldVal) {
          return item[this.lh.sort_order] + 1;
        }
        else if (item[this.lh.sort_order] <= newVal && item[this.lh.sort_order] > oldVal) {
          return item[this.lh.sort_order] - 1;
        }
    
        return 0;
    }

    getSortOrderUpdateItems(row, newSortOrder) {
        return this.updateSortOrder(row, newSortOrder);
    }
    
    getMaxSortOrder(row) {
        return this.getItemsList(row)
          .reduce((result, item) => item[this.lh.sort_order] > result ? item[this.lh.sort_order] : result, 1);
    }
    
    updateSortOrder(row, newSortOrder) {
        let newSoVal = newSortOrder;
        let oldSoVal = row[this.lh.sort_order];
        let itemsUpdate = [];
        this.getItemsList(row).forEach(val => {
          if (val.Id === row.Id) {
            val[this.lh.sort_order] = newSoVal;
          }
          else {
            val[this.lh.sort_order] = this.getSortOrderValue(val, newSoVal, oldSoVal);
          }
          delete val.name
          itemsUpdate.push(val);
        });
        return itemsUpdate;
    }
    
    getMinValue = (newVal, oldVal) => newVal < oldVal ? newVal : oldVal;
    getMaxValue = (newVal, oldVal) => newVal > oldVal ? newVal : oldVal;

    addDerivedFields = (item) => {
        let update = {...item};
        update = this.setHierarchyTypeField(update);
        update = this.setLedgerTypeField(update);
        update = this.setLastPeriodField(update);
        update = this.setLastRunField(update);
        update = this.setStatusField(update);
        update = this.setGeneratedByField(update);
        update = this.setCurrency(update);
        update = this.setName(update);
        return update;
    }

    setHierarchyTypeField = item => {
        item.hierarchy_type = item[this.lh.type1];
        return item;
    }

    setLedgerTypeField = item => {
        item.ledger_type = CommonUtils.getDataValue(this.lh.ledger_r_type, item);
        if (item.ledger_type !== 'Consolidations-Transactional' && item.ledger_type !== 'Consolidations-Budget') {
            item.cssClass = 'hideActionButton';
        }
        return item;
    }

    setLastPeriodField = item => {
        item.last_period = CommonUtils.getDataValue(this.lh.last_period_r_name, item);
        const last_period_id = CommonUtils.getDataValue(this.lh.last_period_r_id, item);
        item.last_period_url = last_period_id && `/${last_period_id}`;
        return item;
    }

    setLastRunField = item => {
        item.last_run = item[this.lh.last_run];
        return item;
    }

    setStatusField = item => {
        item.status = item[this.lh.status];
        return item;
    }

    setGeneratedByField = item => {
        item.generated_by = CommonUtils.getDataValue(this.lh.generated_by_r_name, item);
        const generated_by_id = CommonUtils.getDataValue(this.lh.generated_by, item);
        item.generated_by_url = generated_by_id && `/${generated_by_id}`;
        return item;
    }

    setCurrency = item => {
        if (this.isMultiCurrencyEnabled) {
            item.currency = CommonUtils.getDataValue(this.lh.ledger_r_currency, item);
        }
        return item;
    }

    setName = item => {
        item.name = item.Name !== item.Id.slice(0, -3) ? item.Name : CommonUtils.getDataValue(this.lh.ledger_r_name, item);
        return item;
    }

    setChildren = item => {
        if (item.Id && Object.keys(this.itemsMapByParent).includes(item.Id)) {
            item._children = this.itemsMapByParent[item.Id];
            item._children.forEach(val => this.setChildren(val));
            item._children.sort((a,b) => this.sortBySortOrder(a, b));
        }
        return item;
    }


}