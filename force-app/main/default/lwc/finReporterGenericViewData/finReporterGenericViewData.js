import { api, LightningElement } from "lwc";
import { WindowUtils, CommonUtils } from "c/utils";

export default class FinReporterGenericViewData extends LightningElement {
  @api items = [];
  @api headers = [];
  innerKeyIndex = 0;
  defaultReportWidth = 300;

  @api expandCollapseAll(isExpand) {
    this.rows().forEach(item => {
      let innerButton = this.button(item.dataset.rowKey);
      if (!isExpand) {
        if (this.isInnerRow(item.dataset.rowLevel)) {
          item.style.display = 'none';
        }
        if (innerButton) {
          innerButton.iconName = 'utility:right';
        }
      }
      else {
        item.style.display = 'table-row';
        if (innerButton) {
          innerButton.iconName = 'utility:down';
        }
      }
    });
  }

  connectedCallback() {
    this._headers = this.headers.map(item => CommonUtils.copyObject(item));
    this._items = this.items.map(item => CommonUtils.copyObject(item));
    this.calculateFirstColumnWidth();
    this._headers = this.setHeaders(this._headers);
    this._items = this.getItems(this._items);
    this._items = this.setKeyId(this._items);
    this.setLastElementClass();
  }

  handleSelectCategory(event) {
    let selectedButton = this.button(event.target.dataset.id);
    selectedButton.iconName = selectedButton.iconName === 'utility:right' ? 'utility:down' : 'utility:right';
    this.expandCollapseCategory(selectedButton.iconName, event.target.dataset.id);
  }

  expandCollapseCategory(value, rowId) {
    let isExpand = value === 'utility:down';
    this.rows().forEach(item => {
      if (item.dataset.rowKey !== undefined && this.compareRowKey(rowId, item.dataset.rowKey, !isExpand)) {
        if (isExpand) {
          item.style.display = 'table-row';
        }
        else {
          item.style.display = 'none';
          let innerButton = this.button(item.dataset.rowKey);
          if (innerButton) {
            innerButton.iconName = 'utility:right';
          }
        }
      }
    });
  }

  compareRowKey(rowId, rowKey, selectAll) {
    let isCorrectKey = false;
    let subKey = rowKey.substring(rowId.length - 1);
    let level = (subKey.match(/-/g) || []).length
    if (selectAll && this.isIdIncludes(rowKey, rowId) && rowKey !== rowId) {
      isCorrectKey = true;
    }
    else if (!selectAll && this.isIdIncludes(rowKey, rowId) && level === 1) {
      isCorrectKey = true;
    }
    return isCorrectKey;
  }

  isIdIncludes(rowKey, rowId) {
    return rowId === rowKey.substring(0, rowId.length) && (rowKey.charAt(rowId.length) === '-' || rowKey.charAt(rowId.length) === '');
  }

  setLastElementClass() {
    this._items[this._items.length-1].values.forEach(item => {
      item.class = item.class.includes('border-top-single')
        ? item.class.replace('border-top-single', 'border-top-solid')
        : item.class + ' border-top-solid'
    });
  }

  setKeyId(items) {
    let level1 = 0;
    let level2 = 0;
    let level3 = 0;
    let level4 = 0;
    let result = items.map((item) => {
      switch (item.level) {
        case '1':
          level1 ++;
          item.id = `0${level1.toString()}`;
          level2 = 0;
          level3 = 0;
          level4 = 0;
          break;
        case '2':
          level2 ++;
          item.id = `0${level1.toString()}-${level2.toString()}`;
          level3 = 0;
          level4 = 0;
          break;
        case '3':
          level3 ++;
          item.id = `0${level1.toString()}-${level2.toString()}-${level3.toString()}`;
          level4 = 0;
          break;
        case '4':
          level4 ++;
          item.id = `0${level1.toString()}-${level2.toString()}-${level3.toString()}-${level4.toString()}`;
          break;
        default:
      }
      return item;
    });
    return result;
  }

  setHeaders(headers) {
    headers.unshift({label: '', header2: this.isHeader2(headers), label2: ''});
    for (let i = 0; i < this.offsetCount(); i++) {
      headers.push({value:'', last : true});
    }
    return this.getHeaders(headers);
  }

  offsetCount() {
    let reportWidth = WindowUtils.getScreenWidth() - this.defaultReportWidth;
    let actualColumnCount = Math.round(reportWidth / 170);
    return actualColumnCount - 1;
  }

  calculateFirstColumnWidth() {
    if (this.getMaxLabelCharacterLength() >= 30) {
      this.defaultReportWidth = 377;
      this.setFirstColumnWidth('29em');
    }
  }

  getMaxLabelCharacterLength() {
    return this._items.reduce((result, item) => {
      if (item.values[0].value && result < item.values[0].value.length && !item.child) {
        result = item.values[0].value.length;
      }
      return result;
    },0);
  }

  isHeader2 = headers => headers.some(item => item.header2);

  getHeaders = items => items.map((item, index) => {
    item.rowClass = 'slds-line-height_reset borders-solid';
    item.class = index % 2 === 0 ? 'header-height' : 'header-height custom-theme_shade';
    if (index !== 0) {
      item.class += ' min-column-width borders-solid';
    }
    if (index === 0) {
      item.class += ' headcol-header borders-solid';
    }
    if (item.last) {
      item.class = 'custom-border-none min-column-width';
    }
    this.setIterationKeys(item);
    return item;
  });

  getItems = items => items.map((item, index) => {
    this.setLineClass(item);
    this.setInnerLevel(item);
    if (index === items.length-1) {
      item.headerClass = 'slds-tree__item headcol-last border-top-solid';
    }
    this.setCategoryFontClass(item);
    item.values = this.setItemsHeaderAndClass(item.values, item.level);
    return item;
  });

  setLineClass(item) {
    item.hidden = true;
    item.headerClass = 'slds-tree__item headcol row-height';
    if (item.level === '1') {
      item.headerClass += ' border-top-single';
      item.hidden = false;
    }
    else if (item.level === '1' && item.child) {
      item.headerClass += ' borders-single';
    }
  }

  setInnerLevel(item) {
    if (item.level !== '1' && item.child) {
      item.innerLevel = '2';
    }
    else {
      item.innerLevel = '1';
    }
  }

  setItemsHeaderAndClass = (items, level) => items.map((item, index) => {
    item.header = index === 0;
    item.class = index % 2 === 0 ? 'slds-text-align_right' : 'slds-text-align_right custom-theme_shade';
    if (!item.header) {
      item.class += ' row-height';
    }
    if (level === '1') {
      item.class += ' border-top-single';
    }
    this.setIterationKeys(item);
    return item;
  });

  setCategoryFontClass(item) {
    if (item.level === '1' && item.child) {
      item.valueClass = 'header-total-font';
    }
    else if (item.level === '1' && !item.child) {
      item.valueClass = 'group-text-color header-font';
    }
    else if (item.level !== '1' && item.child) {
      item.valueClass = 'child-font';
    }
    else if (item.level === '2' && !item.child) {
      item.valueClass = 'group-text-color sub-category-1-font';
    }
    else if (item.level === '3' && !item.child) {
      item.valueClass = 'group-text-color sub-category-2-font';
    }

    if (item.level === '1' && item.child && item.hasOwnProperty('calculated') && !item.calculated) {
      item.valueClass = 'child-font';
    }

    if (item.hasOwnProperty('calculated') && item.calculated) {
      item.valueClass += ' bold-font'
    }
  }

  setIterationKeys(item) {
    item.key = this.innerKeyIndex;
    this.innerKeyIndex ++;
    item.secondKey = this.innerKeyIndex;
    this.innerKeyIndex ++;
  }

  isInnerRow = level => level === '2' || level === '3' || level === '4';

  button = id => this.template.querySelector('[data-id="' + id + '"]');
  rows = () => this.template.querySelectorAll('tr');

  setFirstColumnWidth = width => this.template.host.style.setProperty('--firstColumnWidth', width);
}