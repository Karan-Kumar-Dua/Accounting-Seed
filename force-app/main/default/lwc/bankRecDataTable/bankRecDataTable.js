import { api, LightningElement, wire } from "lwc";
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import Helper from './bankRecDataTableHelper';
import ReconciliationItemStore from './reconciliationItemStore';
import { SortStrategyFactory, ErrorUtils, WindowUtils, DateUtils, LabelService } from "c/utils";
import { BankReconciliation } from "c/sobject";
import getAllItems from '@salesforce/apex/BankReconciliationHelper.getAllRecords';
import getRecordCount from '@salesforce/apex/BankReconciliationHelper.getRecordCount';
import clearItems from '@salesforce/apex/BankReconciliationHelper.clearItems';
import unclearItems from '@salesforce/apex/BankReconciliationHelper.unclearItems';
import setClearedDate from '@salesforce/apex/BankReconciliationHelper.setClearedDate';
import isMultiCurrencyEnabled from '@salesforce/apex/BankReconciliationHelper.isMultiCurrencyEnabled';
import setCompleted from '@salesforce/apex/BankReconciliationHelper.setCompleted';
import runAutoClearJob from '@salesforce/apex/BankReconciliationHelper.runAutoClearJob';
import setInProgress from '@salesforce/apex/BankReconciliationHelper.setInProgress';
import Labels from './labels';

const KEY_FIELD = 'Id';
const MAX_ITEMS_LOADED = 8001;
const LOAD_ERROR = Labels.ERR_LOADING_ASSOCIATED_ITEMS;
const FIELDS = [BankReconciliation.status, BankReconciliation.bank_account, BankReconciliation.type1, BankReconciliation.modern_br];
const WORKING = 'Working';
const AUTO_CLEAR_RUNNING = 'Auto Clear Running';
const COMPLETED = 'Completed';
const IN_PROGRESS = 'In Progress';
const COMPLETED_CONFIRM = Labels.WRN_CHANGE_BANK_RECONCILIATION_STATUS_COMPLETED;
const IN_PROGRESS_CONFIRM = Labels.WRN_CHANGE_BANK_RECONCILIATION_STATUS_IN_PROGRESS;
const CLEAR_ALL_CONFIRM = Labels.WRN_CLEAR_ALL_RECORDS_ON_PAGE;
const UNCLEAR_ALL_CONFIRM = Labels.WRN_UNCLEAR_ALL_RECORDS_ON_PAGE;

export default class BankRecDataTable extends LightningElement {
  labels = {...LabelService, ...Labels};
  @api recordId;
  br = new BankReconciliation();
  bankRec;
  pageSize = 100;
  recItems;
  columnsWithLedgerAmount = Helper.getColumnsWithLedgerAmount();
  columns = Helper.getColumns();
  itemsStore = new ReconciliationItemStore();
  keyField = KEY_FIELD;
  sortFactory;
  isSpinner = false;
  isError = false;
  isMaxLoadError = false;
  isReportMode = false;
  isLoadRecords = false;
  showLightbox = false;
  showTable = false;
  isAutoClearJobRunning = false;
  isLegacyBR = false;
  lightboxMessage;
  lightboxHeader;
  error;
  unclearedAll = false;
  sortOpts = {
    sortedBy: 'recordDate',
    sortedDirection: 'asc'
  };
  showCurrentDatePicker = false;
  currentRow;
  currentClearedDate;
  currentClientX;
  currentClientY;
  saveButtonDisable = false;
  showPopup = false;
  completedButtonDisable = false;
  autoClearButtonDisable = false;
  selectClearAll = false;
  showAutoClearButton = false;
  showStatusButton = false;
  
  get maxItemsDisplayed() {
    return MAX_ITEMS_LOADED - 1;
  }

  get clearedAll() {
    return {
      label: this.unclearedAll ? Labels.INF_UNCLEAR_ALL : Labels.INF_CLEAR_ALL,
      icon: this.unclearedAll ? 'utility:check' : 'utility:add'
    };
  }

  get completedLabel() {
    return this.completedButtonLabel();
  }

  get autoClearLabel() {
    return this.autoClearButtonLabel;
  }

  get autoClearTitle() {
    return this.autoClearButtonTitle;
  }

  get popupLabel() {
    return this.selectClearAll ? this.clearAllButtonLabel() : this.completedButtonLabel();
  }

  get popupMessage() {
    return this.selectClearAll ? this.clearAllButtonMessage() : this.completedButtonMessage();
  }

  get maxLoadErrorMessage() {
    const n = this.itemCount && this.itemCount.data && !isNaN(this.itemCount.data) ? this.itemCount.data  : `${Labels.INF_MORE_THAN} ${MAX_ITEMS_LOADED - 1}`;
    return Helper.getLimitErrorMessage().replace(/{BREC_Total_Count}/g, n);
  }

  @wire(isMultiCurrencyEnabled, {bankRecId: '$recordId'})
  setIsMultiCurrency({ data }) {
    if (data) {
      this.itemsStore.setMultiCurrencyEnabled(data.isMultiCurrencyEnabled);
      this.itemsStore.setCurrencyCode(data.currencyIsoCode);
      if (data.isMultiCurrencyEnabled && data.isSameCurrencyAsLedger) {
        this.columns = this.columnsWithLedgerAmount;
        this.itemsStore.isLedgerAmount = true;
      }
    }
  }

  @wire(getRecordCount, {bankRecId: '$recordId'})
  itemCount;

  @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
  getRecord({ error, data }) {
    if (data) {
      this.bankRec = data;
      this.isLegacyBR = !data.fields[this.br.modern_br].value;
      if (!this.isReportMode && data.fields[this.br.status].value === COMPLETED) {
        this.isReportMode = true;
        this.showTable = true;
        this.loadRecords();
      }
      if (!this.isLoadRecords && !this.showTable && data.fields[this.br.status].value !== WORKING) {
        this.showTable = true;
        this.loadRecords();
      }
      if (this.isReportMode && data.fields[this.br.status].value === IN_PROGRESS) {
        this.isReportMode = false;
        this.loadRecords();
      }
      if (this.showTable && data.fields[this.br.status].value === WORKING) {
        this.showTable = false;        
      }
      if (data.fields[this.br.status].value === AUTO_CLEAR_RUNNING) {
        this.setAutoClearStatus(true);        
      }
      if (this.isAutoClearJobRunning && data.fields[this.br.status].value === IN_PROGRESS) {
        this.setAutoClearStatus(false);
        this.loadRecords();        
      }
      this.showAutoClearButton = !this.isLegacyBR && !this.isReportMode;
      this.showStatusButton = !this.isLegacyBR;
    }
    else if (error) {
      this.processError(error)
    }
  }

  async loadRecords() {
    this.itemsStore.clearItems();
    this.isLoadRecords = true;
    this.isSpinner = true;
    await this.getAllRecords();
    if (!this.isMaxLoadError && !this.isError && this.showTable) {
      this.unclearedAll = !this.itemsStore.checkIfUnclear(this.applicableItems().getCurrentPageItems());
    }
    this.isSpinner = false;
  }

  setAutoClearStatus(status) {
    this.isAutoClearJobRunning = status;
    this.isSpinner = status;
  }

  getAllRecords() {
    return getAllItems({bankRecId: this.recordId})
      .then(result => {
        if (result){
          this.validateMaxRecordCount(result.length);
          let sortedResult = this.itemsStore.sortAllItemsByCleared(result, MAX_ITEMS_LOADED - 1);
          this.itemsStore.addItems(sortedResult, this.bankRec, this.isReportMode);
          if (this.isMaxLoadError) {
            this.itemsStore.disableAllUnclearedItem();
          }
          this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
        }
        else {
          this.error = LOAD_ERROR;
        }
      })
      .catch(e => this.processError(e));
  }

  validateMaxRecordCount(totalCount) {
    if (totalCount > MAX_ITEMS_LOADED - 1) {
      this.isMaxLoadError = true;
      this.unclearedAll = true;
      this.completedButtonDisable = true;
      this.autoClearButtonDisable = true;
    }
  }

  clearedItems(values, item) {
    let sourceIds = Array.isArray(values) ? values : [values];
    return clearItems({bankRecId: this.recordId, sourceRecIds: sourceIds})
      .then((result) => {
        if (result.isSuccess) {
          this.processAfterCall(item);
          this.error = null;
        }
        else {
          this.processAfterCallError(item, sourceIds);
          this.processCustomErrorResult(result);
        }
      })
      .catch(e => this.processError(e));
  }

  unclearedItems(values, item) {
    let sourceIds = Array.isArray(values) ? values : [values];
    return unclearItems({bankRecId: this.recordId, sourceRecIds: sourceIds})
      .then((result) => {
        if (result.isSuccess) {
          this.processAfterCall(item);
          this.error = null;
        }
        else {
          this.processAfterCallError(item, sourceIds);
          this.processCustomErrorResult(result);
        }
      })
      .catch(e => this.processError(e));
  }

  processCustomErrorResult = result => {
    if (result.errors.length > 0) {
      this.error = result.errors[0].detail;
    }
    else {
      this.error = LOAD_ERROR;
    }
  }

  processAfterCall = (item) => {
    this.isSpinner = false;
    if (item) {
      item.disableClearedButton = this.isMaxLoadError ? true : false;
      this.itemsStore.updateItem(item);
      if (this.showTable) {
        this.unclearedAll = !this.itemsStore.checkIfUnclear(this.applicableItems().getCurrentPageItems());
      }
      this.recItems = this.itemsStore.getItems();
    }
    getRecordNotifyChange([{recordId: this.recordId}]);
  }

  processAfterCallError = (item, sourceIds) => {
    this.isSpinner = false;
    if (item) {
      item.isCleared = item.isCleared ? false : true;
      item.disableClearedButton = this.isMaxLoadError ? true : false;
      this.itemsStore.updateItem(item);
    }
    else {
      this.unclearedAll = this.isMaxLoadError || !this.unclearedAll ? true : false;
      let selectedItems = this.applicableItems().getCurrentPageItems().filter(val => sourceIds.includes(val.Id));
      this.itemsStore.clearedAllItem(this.unclearedAll, selectedItems, this.isMaxLoadError);
    }
    this.recItems = this.itemsStore.getItems();
    getRecordNotifyChange([{recordId: this.recordId}]);
  }

  handleRowAction(event) {
    if (!this.isReportMode) {
      switch (event.detail.action.name) {
        case 'cleared':
          this.processItem(event.detail.row);
          this.recItems = this.itemsStore.getItems();
          break;
        case 'clearedDate':
          this.getDataPicker(event);
          break;
        default:
      }
    }
  }

  processItem(item) {
    item.disableClearedButton = true;
    if (!item.isWarning) {
      if (item.isCleared) {
        item.isCleared = false;
        this.unclearedItems(item.Id, item);
      }
      else {
        item.isCleared = true;
        this.clearedItems(item.Id, item);
      }
      this.itemsStore.updateItem(item);
    }
    else {
      this.showLightbox = true;
      this.setLightboxMessage(item);
    }
  }

  setLightboxMessage(item) {
    if (item.isVoided) {
      this.lightboxHeader = Labels.INF_TRANSACTION_IS_VOIDED;
      this.lightboxMessage = Helper.getVoidedWarningMessage();
    }
    else if (item.isLegacyBankDeposit) {
      this.lightboxHeader = LabelService.commonBankDeposit;
      this.lightboxMessage = Helper.getLegacyBDWarningMessage();
    }
    else {
      this.lightboxHeader = Labels.INF_TRANSACTION_IS_CLEARED;
      this.lightboxMessage = Helper.getClearedWarningMessageTemplate().replace(/{BREC_Name}/g, item.extBRName);
    }
  }

  lightboxCloseEvent() {
    this.showLightbox = false;
    this.lightboxMessage = '';
  }

  handleClearedAll() {
    this.isSpinner = true;
    if (this.unclearedAll) {
      this.unclearedAll = this.isMaxLoadError ? true : false;
      this.unclearedItems(this.itemsIds(this.applicableItems().getCurrentPageItems(), true));
    }
    else {
      this.unclearedAll = true;
      this.clearedItems(this.itemsIds(this.applicableItems().getCurrentPageItems(), false));
    }
    this.itemsStore.clearedAllItem(this.unclearedAll, this.applicableItems().getCurrentPageItems(), this.isMaxLoadError);
    this.recItems = this.itemsStore.getItems();
  }

  itemsIds = (currentItems, selectCleared) => currentItems.reduce((arr, item) => {
    if (!item.isWarning && (selectCleared ? item.isCleared : !item.isCleared)) {
      arr.push(item.Id);
    }
    return arr;
  }, []);

  handlePageChange({ detail }) {
    this.unclearedAll = this.isMaxLoadError ? true : !this.itemsStore.checkIfUnclear(detail);
  }

  handleSort({ detail }) {
    this.sort(detail.fieldName, detail.sortDirection);
    this.sortOpts.sortedBy = detail.fieldName;
    this.sortOpts.sortedDirection = detail.sortDirection;
  }

  sort(field, direction) {
    if (!this.sortFactory) {
      this.sortFactory = new SortStrategyFactory(this.columns);
    }
    let sortFn;
    if (field === 'clearedDate') {
      sortFn = this.sortFactory.getSortStrategy(field, direction, this.transformClearedDate);
    }
    else {
      sortFn = this.sortFactory.getSortStrategy(field, direction);
    }
    this.itemsStore.sort(sortFn);
    this.recItems = this.itemsStore.getItems();
  }

  transformClearedDate = val => {
    let update = {...val};
    if (val.clearedDate === 'Edit') {
      update.clearedDate = null;
    }
    else {
      update.clearedDate = new Date(val.rawClearedDate);
    }
    return update;
  }

  setClearedDate() {
    return setClearedDate({sourceRecordId: this.currentRow.Id, clearedDateValue: this.currentClearedDate})
      .then(result => {
        if (result.isSuccess) {
          this.itemsStore.updateItemClearedDate(this.currentRow.Id, this.currentClearedDate);
          this.recItems = this.itemsStore.getItems();
        }
        else {
          this.error = LOAD_ERROR;
        }
      });
  }

  setClearedDateAndClearedStatus() {
    let cleared, uncleared = false;
    this.isSpinner = true;
    if (this.currentClearedDate !== null && !this.currentRow.isCleared) {
      cleared = this.isMaxLoadError ? false : true;
      this.currentRow.disableClearedButton = true;
      this.currentRow.isCleared = this.isMaxLoadError ? false : true;
      this.currentRow.clearedDate = DateUtils.getFormattedDate(this.currentClearedDate.replaceAll('-','/'));
      this.currentRow.rawClearedDate = this.currentClearedDate;
    }
    else if (this.currentClearedDate === null && this.currentRow.isCleared) {
      uncleared = true;
      this.currentRow.disableClearedButton = true;
      this.currentRow.isCleared = false;
      this.currentRow.clearedDate = 'Edit';
      this.currentRow.rawClearedDate = '';
    }
    this.itemsStore.updateItem(this.currentRow);
    this.recItems = this.itemsStore.getItems();
    this.setClearedDate()
      .then(() => {
        if (cleared) {
          this.clearedItems(this.currentRow.Id, this.currentRow);
        }
        else if (uncleared) {
          this.unclearedItems(this.currentRow.Id, this.currentRow);
        }
        this.isSpinner = false;
      }).catch(e => this.processError(e));
  }

  processError(e) {
    this.isSpinner = false;
    let {isError, error} = ErrorUtils.processError(e);
    this.error = error;
    this.isError = isError;
  }

  handleFilterChange({detail}) {
    if (this.gridCmp()) {
      this.gridCmp().showFirstPage();
    }
    this.recItems = this.itemsStore.getItems(detail);
    setTimeout(() => {this.setUnclearButton(detail)}, 0);
  }

  setUnclearButton(detail) {
    if (detail.hasOwnProperty('state') && !this.isMaxLoadError) {
      if (detail.state === 'All') {
        this.unclearedAll = !this.itemsStore.checkIfUnclear(this.applicableItems().getCurrentPageItems());
      }
      else {
        this.unclearedAll = detail.state === 'Cleared'
      }
    }
  }

  getDataPicker(event) {
    this.saveButtonDisable = true;
    this.showCurrentDatePicker = true;
    this.currentRow = event.detail.row;
    this.currentClearedDate = event.detail.row.clearedDate === 'Edit' ? '' : event.detail.row.rawClearedDate;
    let datePicker = this.popover();
    let table = this.table();
    let coordinates = WindowUtils.getXYCoordinates(table, this.currentClientX, this.currentClientY, 30, -85);
    WindowUtils.setElementAbsolutePosition(datePicker, coordinates);
  }

  handleClearedDateChange({ detail }) {
    this.saveButtonDisable = false;
    this.currentClearedDate = detail.value;
  }

  handleDataPickerSave() {
    this.setClearedDateAndClearedStatus();
    this.handleClearedDatePopoverClose();
  }

  handleClearedDatePopoverClose() {
    this.showCurrentDatePicker = false;
    this.popover().setAttribute('style', 'display:none;');
  }

  handleSelectFilter() {
    setTimeout(() => {this.filter().showFilterPopover(this.table())}, 0);
  }

  handleClick(event) {
    this.currentClientX = event.clientX;
    this.currentClientY = event.clientY;
    if (this.filter()) {
      this.filter().setCoordinates(event.clientX, event.clientY);
    }
  }

  setCompletedStatus() {
    return setCompleted({bankRecId: this.recordId})
      .then(result => {
        if (!result.isSuccess) {
          this.processCustomErrorResult(result);
        }
      })
      .catch(e => this.processError(e))
      .finally(() => (
        this.completedButtonDisable = this.autoClearButtonDisable = false));
  }

  setInProgressStatus() {
    return setInProgress({bankRecId: this.recordId})
      .then(result => {
        if (!result.isSuccess) {
          this.processCustomErrorResult(result);
        }
      })
      .catch(e => this.processError(e))
      .finally(() => (this.completedButtonDisable = this.autoClearButtonDisable = false));
  }

  handleCompletedUncompleted() {
    this.showPopup = false;
    if (this.isReportMode || !this.showTable) {
      this.setInProgressStatus()
    }
    else {
      this.setCompletedStatus()
    }
  }

  handlePopupCancel() {
    this.showPopup = false;
    this.completedButtonDisable = false;
    this.autoClearButtonDisable = false;
  }

  handleCompletedButton() {
    this.showPopup = true;
    this.completedButtonDisable = true;
    this.autoClearButtonDisable = true;
  }

  handleAutoClearButton() {
    this.setAutoClearStatus(true);
    return runAutoClearJob({bankRecId: this.recordId})
    .then(result => {
      if (!result.isSuccess) {
        this.setAutoClearStatus(false); 
        this.processCustomErrorResult(result);        
      }
    })
    .catch(e => {
      this.processError(e);
      this.setAutoClearStatus(false);
    });    
  }

  handlePopupAction() {
    this.showPopup = false;
    if (this.selectClearAll) {
      this.handleClearedAll()
    }
    else {
      this.handleCompletedUncompleted()
    }
  }

  handleCompletedUncompleted() {
    if (this.isReportMode || !this.showTable) {
      this.setInProgressStatus()
    }
    else {
      this.setCompletedStatus()
    }
  }

  handlePopupCancel() {
    this.showPopup = false;
    this.completedButtonDisable = false;
    this.autoClearButtonDisable = false;
  }

  handleCompletedButton() {
    this.selectClearAll = false;
    this.showPopup = true;
    this.completedButtonDisable = true;
    this.autoClearButtonDisable = true;
  }

  handleClearAllButton() {
    this.selectClearAll = true;
    this.showPopup = true;
  }

  completedButtonLabel = () => this.isReportMode || !this.showTable ? Labels.INF_SET_TO_IN_PROGRESS : Labels.INF_SET_TO_COMPLETED;
  autoClearButtonLabel = Labels.INF_CLEAR_BANK_DATES;
  autoClearButtonTitle = Labels.INF_AUTO_CLEAR_BUTTON_TITLE;
  clearAllButtonLabel = () => this.unclearedAll ? Labels.INF_UNCLEAR_ALL : Labels.INF_CLEAR_ALL;
  completedButtonMessage = () => this.isReportMode || !this.showTable ? IN_PROGRESS_CONFIRM : COMPLETED_CONFIRM;
  clearAllButtonMessage = () => this.unclearedAll ? UNCLEAR_ALL_CONFIRM : CLEAR_ALL_CONFIRM;

  applicableItems = () => this.template.querySelector("c-applicable-items");
  popover = () => this.template.querySelector('[data-id="cleared-date-popover"]');
  table = () => this.template.querySelector('[data-id="bank-rec-table"]');
  filter = () => this.template.querySelector("c-bank-rec-filter");
  gridCmp = () => this.template.querySelector(".itemsGrid");

}