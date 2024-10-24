import { LightningElement,api} from "lwc";
import { CommonUtils, LabelService } from "c/utils";
import Labels from './labels';

export default class CustomDataTable extends LightningElement {
  labels = {...LabelService, ...Labels};
  @api columns = [];
  @api additionalColumns = [];
  @api defaultEdit = false;
  @api maxRecordsDisplayed;
  @api sortedBy;
  @api sortedDirection;
  @api actions = {};
  @api additionalSectionTemplateName = '';
  @api nameTab = '';
  @api pageSize = 10;
  @api changeNotifications;
  @api isNeedUpdateDataSource = false;
  page;
  isProgress = false;
  progressPercent = 0;
  isSpinner = true;
  rendered = false;
  showTable = false;
  showAdditional = false;
  currentIcon = 'chevronright';
  totalRecords;
  pageOffset = 0;
  _items;
  currentPage = 1;
  
  mouseStart;
  oldWidth;

  @api resetProgressPercent(progressPercent) {
    this.progressPercent = progressPercent;
  }

  @api
  set items(val) {
    if (val) {
      this.originalDataLen = val.length;
      this._items = (this.maxRecordsDisplayed && (val.length >= this.maxRecordsDisplayed))
        ? val.slice(0, this.maxRecordsDisplayed)
        : val;
      this.page = this.getCurrentPage(this._items);
      this.totalRecords = this._items.length;
      this.showTable = this._items.length > 0 ? true : false;
    }
  }
  get items() {
    return this._items;
  }

  @api
  refreshView() {
    this.items = [];
  }

  @api
  showTableSpinner(isShown, isProgress) {
    this.isSpinner = isShown;
    if (isShown && isProgress) {
      this.isProgress = true;
    } else if (!isShown) {
      this.isProgress = false;
    }

  }

  @api
  showFirstPage() {
    this.setPaginatorPage(1);
    this.pageOffset = 0;
    this.page = this.items.slice(0, this.pageSize);
  }
  @api
  closeAllOpenDrawers() {
    this.currentIcon = "chevronright";
    this.showAdditional = false;
    this.handleDrawer();
  }

  @api
  goToPage(pageNumber) {
    this.setPaginatorPage(pageNumber);
    this.pageOffset = (pageNumber - 1) * this.pageSize;
    this.page = this.items.slice(this.pageOffset, this.pageOffset + this.pageSize);
  }

  @api
  validateTable() {
    let elements = this.allChildRows();
    let resultData = this.getResultData(elements, true);
    const invalidRecords = this.validateRecords(elements, resultData);
    return !invalidRecords || !invalidRecords.length;
  }

  handleDrawer() {
      let rows = this.allChildRows();
      let additionalRows = this.template.querySelectorAll('.additional-child-row');
      rows.forEach(element => element.setActionIcon(this.currentIcon));
      additionalRows.forEach(element => element.expandCollapsDrawer(this.showAdditional));
  }
  get progressLabel() {
    return `${this.progressPercent}% processed`;
  }

  get showDrawer() {
    return this.additionalColumns.length > 0;
  }

  get iconLink() {
    return "utility:" + this.currentIcon;
  }

  get cancelButton() {
    return !this.defaultEdit && this.actions.showCancel;
  }

  connectedCallback() {
    this.isSpinner = false;
  }

  getCurrentPage(items) {
    this.setPaginatorPage(this.currentPage);
    if (items.length > 0 && items.length <= this.pageSize && this.pageOffset >= this.pageSize) {
      this.pageOffset = 0;
      this.currentPage = 1;
    }
    this.setPaginatorPage(this.currentPage);
    return items.slice(this.pageOffset, this.pageOffset + this.pageSize);
  }

  saveData(data, action) {
    this.isSpinner = true;
    this.dispatchEvent(new CustomEvent('itemsaction', {detail: {data : data, action : action}}));
  }

  handleSectionAction(event) {
    event.stopPropagation();
    let detail = event.detail;
    let element = this.additionalSection(detail);
    let val = element.getExpandCollapsDrawerValue();
    element.expandCollapsDrawer(val ? false : true);
  }

  handleHideErrorRow({detail}) {
    let element = this.errorSection(detail);
    element.style.display = 'none';
  }

  handleShowErrorRow({detail}) {
    let element = this.errorSection(detail);
    element.style.display = 'table-row';
  }

  handleSectionEditAction(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.showSaveButton(detail.mode);
    let element = this.additionalSection(detail.id);
    if (element) {
      element.setEditMode(detail.mode);
    }
    let mainElement = this.mainSection(detail.id);
    if (mainElement) {
      mainElement.setEditMode(detail.mode);
    }
  }

  handleAllEditAction(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.showSaveButton(detail.mode);
    let element = this.additionalSection(detail.id);
    element.setEditAllMode(detail.mode);
    let mainElement = this.mainSection(detail.id);
    mainElement.setEditAllMode(detail.mode);
  }

  handleCancelAllAction() {
    this.showSaveButton(false);
    let elements = this.allChildRows();
    elements.forEach((element) => {
      element.cancelAction();
    });
  }

  handleAllAction(event) {
    let selectedAction = event.target.dataset.action;
    this.showSaveButton(false);
    let elements = this.allChildRows();
    this.prepareAndSave(elements, false, selectedAction);
  }

  handleRowAction(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.showSaveButton(false);
    let element = this.additionalSection(detail.id);
    let mainElement = this.mainSection(detail.id);
    this.prepareAndSave([element, mainElement], true, detail.action);
  }

  prepareAndSave(elements, single, action) {
    let resultData = this.getResultData(elements, single);
    const actionDetail = this.actions?.actions?.find(item => item.actionName === action);
    let invalidRecords = (actionDetail && actionDetail.isSkipValidation && []) || this.validateRecords(elements, resultData);
    let save = Object.values(resultData).filter(item => item.isEdit === true && !invalidRecords.includes(item.Id));
    if (save.length > 0) {
      this.saveData(save, action);
    }
  }

  getResultData(elements, single) {
    let resultData = {};

    elements.forEach((element) => {
      let insideObj = element.saveAction(single);
      if (!resultData.hasOwnProperty(insideObj.Id)) {
        resultData[insideObj.Id] = insideObj;
      }
      else {
        let isEdit = resultData[insideObj.Id].isEdit;
        resultData[insideObj.Id] = CommonUtils.mergeObjects(resultData[insideObj.Id], insideObj);
        resultData[insideObj.Id].isEdit = isEdit ? isEdit : insideObj.isEdit;
      }
    });
    return resultData;
  }

  validateRecords(elements, resultData) {
    let invalidRecords = [];
    elements.forEach((element) => {
      let insideObj = resultData[element.getRowId()];
      if (insideObj.isEdit && !element.allFieldsValid()) {
        invalidRecords.push(element.getRowId());
      }
    });
    return invalidRecords;
  }

  showSaveButton(value) {
    if (this.actions.showBatchButtons) {
      let element = this.template.querySelector('.inner-all-button-group');
      element.style.display = value ? 'block' : 'none';
    }
  }

  handleAllSectionsAction() {
    this.currentIcon = this.currentIcon === "chevronright" ? "chevrondown" : "chevronright";
    this.showAdditional = this.showAdditional === false ? true : false;
    this.handleDrawer();
  }

  handleSortAction(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.dispatchEvent(new CustomEvent('sort', { detail: {fieldName : detail.fieldName, sortDirection: detail.sortDirection}}));
  }

  handleValueChange(event) {
    event.stopPropagation();
    let detail = event.detail;
    this.showSaveButton(true);
    let additional = this.additionalSection(detail.id);
    let main = this.mainSection(detail.id);
    additional?.componentChangeValue(detail.value, detail.fieldApiName);
    main?.componentChangeValue(detail.value, detail.fieldApiName);
    this.isNeedUpdateDataSource && this.updateDataSource(detail);
    this.changeNotifications?.forEach(
        notificationDetail =>
            detail.fieldApiName === notificationDetail.fieldApiName
              && this.dispatchEvent(new CustomEvent(notificationDetail.eventName, { detail }))
    );
  }

  updateDataSource({ id, fieldApiName, value }) {
    this._items = [...this._items.map(item => {
      if (item.Id === id) {
        return CommonUtils.setObjectValue(CommonUtils.copyObject(item), fieldApiName, value);
      }
      return item
    })]
  }

  handleTemplateRowChange({detail}) {
    let additional = this.additionalSection(detail.id);
    additional.updateRow(detail.value);
    let main = this.mainSection(detail.id);
    main.updateRow(detail.value);
  }

  handlePageChange({ detail: offset }) {
    const paginator = this.paginator();
    if (paginator) {
      this.currentPage = paginator.getCurrentPage();
    }
    this.pageOffset = offset;
    this.page = this.items.slice(offset, offset + this.pageSize);
    this.dispatchEvent(new CustomEvent('pageselect', { detail: {offset : offset, pageSize : this.pageSize}}));
  }

  setPaginatorPage(pageNum) {
    const paginator = this.paginator();
    if (paginator) {
      paginator.goToPage(pageNum);
      this.currentPage = paginator.getCurrentPage();
    }
  }

  calculateWidth(event) {
    let childObj = event.target
    let parObj = childObj.parentNode;
    while(parObj.tagName !== 'TH') {
      parObj = parObj.parentNode;
    }

    let mouseStart = event.clientX;
    this.mouseStart = mouseStart;
    this.oldWidth = parObj.offsetWidth;
  }

  setNewWidth(event) {
    let childObj = event.target
    let parObj = childObj.parentNode;
    while(parObj.tagName !== 'TH') {
      parObj = parObj.parentNode;
    }
    let mouseStart = this.mouseStart;
    let oldWidth = this.oldWidth;
    let newWidth = event.clientX- parseFloat(mouseStart) + parseFloat(oldWidth);
    parObj.style.width = newWidth + 'px';
  }

  paginator = () => this.template.querySelector("c-paginator");
  mainSection = id => this.template.querySelector('[data-main-id="' + id + '"]');
  additionalSection = id => this.template.querySelector('[data-id="' + id + '"]');
  errorSection = id => this.template.querySelector('[data-error-id="' + id + '"]');
  allChildRows = () => this.template.querySelectorAll('c-custom-data-table-row');

}