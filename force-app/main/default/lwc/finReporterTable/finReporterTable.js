import { LightningElement, api, wire } from "lwc";
import Helper from './finReporterTableHelper';
import FinReportsTableStore from './finReporterTableStore';
import getFinancialReportResults from '@salesforce/apex/FinancialReporterHelper.getFinancialReportResults';
import deleteFinancialReportResults from '@salesforce/apex/FinancialReporterHelper.deleteFinancialReportResults';
import isHeaderLevelPostEnabled from '@salesforce/apex/FinancialReporterHelper.isHeaderLevelPostEnabled';
import isMultiCurrencyEnabled from '@salesforce/apex/FinancialReporterHelper.isMultiCurrencyEnabled';
import { ErrorUtils, NotificationService, SortStrategyFactory, StreamingApi, LabelService } from "c/utils";
import { FinancialReportResult, ASImmediateEvent } from "c/sobject";
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import Labels from "./labels";

const KEY_FIELD = 'Id';
const MAX_ITEMS_LOADED = 8001;
const IMMEDIATE_CHAN = '/event/' + ASImmediateEvent.packageQualifier + 'AS_Immediate_Event__e';
const COMMIT_CHAN = '/event/' + ASImmediateEvent.packageQualifier + 'AS_Commit_Event__e';
const START_REPORT = 'FINANCIAL_REPORTER_GENERATE_START';
const END_REPORT = 'FINANCIAL_REPORTER_GENERATE_END';
const NO_REPORTS_SELECTED_ERROR = Labels.ERR_NO_REPORTS_TO_DELETE;
const REPORT_COMPLETED = Labels.INF_REPORT_GENERATION_COMPLETE;
const REPORT_MESSAGE_TITLE = LabelService.commonFinancialReports;
const DELETE_ERROR = Labels.ERR_DELETING_REPORT;

export default class FinReporterTable extends LightningElement {
  labels = {...Labels, ...LabelService};
  @api 
  get reportName() {
    return this._reportName;
  } 
  set reportName(val = 'profitLoss') {
    this._reportName = val;
    this.columns = Helper.getColumns(this._reportName);
    this.setGlavsHeaderValue();
  }
  
  frr = new FinancialReportResult();
  immediateChan = new StreamingApi();
  commitChan = new StreamingApi();
  objEvent = new ASImmediateEvent();
  recItems;
  isSpinner = false;
  isFirstRefreshDone = false;
  columns = [];
  itemsStore = new FinReportsTableStore();
  keyField = KEY_FIELD;
  pageSize = 25;
  sortFactory;
  error;
  sortOpts = {
    sortedBy: 'reportLink',
    sortedDirection: 'desc'
  };
  glVariable1Value = LabelService.commonGLVariable + ' 1';
  glVariable2Value = LabelService.commonGLVariable + ' 2';
  glVariable3Value = LabelService.commonGLVariable + ' 3';
  glVariable4Value = LabelService.commonGLVariable + ' 4';
  showPopup = false;
  deleteDisabled = true;
  
  @wire(getObjectInfo, { objectApiName: FinancialReportResult.financial_report_result})
  frrInfo({ data }) {
    if (data) {
      if (data.fields.hasOwnProperty(this.frr.gl_account_variable_1)) {
        this.glVariable1Value = data.fields[this.frr.gl_account_variable_1].label;
      }
      if (data.fields.hasOwnProperty(this.frr.gl_account_variable_2)) {
        this.glVariable2Value = data.fields[this.frr.gl_account_variable_2].label;
      }
      if (data.fields.hasOwnProperty(this.frr.gl_account_variable_3)) {
        this.glVariable3Value = data.fields[this.frr.gl_account_variable_3].label;
      }
      if (data.fields.hasOwnProperty(this.frr.gl_account_variable_4)) {
        this.glVariable4Value = data.fields[this.frr.gl_account_variable_4].label;
      }
    }
  }

  @wire(isHeaderLevelPostEnabled)
  isHLP({ data }) {
    // some reports hide/show columns based on post settings (HLP/LLP)
    if (data === true && ['balanceSheet', 'trialBalance', 'cashFlow'].includes(this.reportName)) {
      const removeColumns = ['glav1Link', 'glav2Link', 'glav3Link', 'glav4Link'];
      this.columns = this.columns.filter(col => !removeColumns.includes(col.fieldName));
    }
  }

  @wire(isMultiCurrencyEnabled)
  setIsMultiCurrency({ data }) {
    if (!data && ['profitLoss', 'profitLossVsBudget', 'balanceSheet', 'trialBalance', 'cashFlow', 'custom'].includes(this.reportName)) {
      const removeColumns = ['currency'];
      this.columns = this.columns.filter(col => !removeColumns.includes(col.fieldName));
    }
  }

  get maxItemsDisplayed() {
    return MAX_ITEMS_LOADED - 1;
  }

  getFinReportResults() {
    return getFinancialReportResults({reportTypeName: this.reportName})
      .then(result => {
        if (result){
          this.itemsStore.setItems(result);
          this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
          this.setGlavsHeaderValue();
          if(result.length > 0){
            this.deleteDisabled = false;
          }
          this.isSpinner = false;
        }
      })
      .catch(e => this.processError(e));
  }

  setGlavsHeaderValue() {
    this.columns = this.columns.map(column => {
      if (column.fieldName === 'glav1Link') { 
        column.label = this.glVariable1Value; 
      }
      else if (column.fieldName === 'glav2Link') { 
        column.label = this.glVariable2Value; 
      }
      else if (column.fieldName === 'glav3Link') { 
        column.label = this.glVariable3Value; 
      }
      else if (column.fieldName === 'glav4Link') { 
        column.label = this.glVariable4Value; 
      }
      return column;
    });
  }

  connectedCallback() {
    this.commitChan.channelName = COMMIT_CHAN;
    this.commitChan.handleSubscribe(this.updateCallback);

    this.immediateChan.channelName = IMMEDIATE_CHAN;
    this.immediateChan.handleSubscribe(this.updateCallback);

    this.getFinReportResults();
  }

  disconnectedCallback() {
    this.commitChan.handleUnsubscribe();
    this.immediateChan.handleUnsubscribe();
  }

  updateCallback = response => {
    if (response) {
      this.commitChan.responseError = null;
      this.immediateChan.responseError = null;
      if (response.data.payload[this.objEvent.type] === START_REPORT || response.data.payload[this.objEvent.type] === END_REPORT) {
        this.getFinReportResults();
      }
      if (response.data.payload[this.objEvent.type] === END_REPORT) {
        this.showCompletedToastMessage();
      }
    }
    else {
      if (this.commitChan.responseError) {
        this.error = this.commitChan.responseError;
      }
      else if (this.immediateChan.responseError) {
        this.error = this.immediateChan.responseError;
      }
    }
  };

  handleSort({ detail }) {
    this.sort(detail.fieldName, detail.sortDirection);
    this.sortOpts.sortedBy = detail.fieldName;
    this.sortOpts.sortedDirection = detail.sortDirection;
  }

  sort(field, direction) {
    if (!this.sortFactory) {
      this.sortFactory = new SortStrategyFactory(this.columns);
    }
    let sortFn = this.sortFactory.getSortStrategy(field, direction);
    this.itemsStore.sort(sortFn);
    this.recItems = this.itemsStore.getItems();
  }

  handleDeleteAll() {
    this.error = false;
    this.showPopup = false;
    this.isSpinner = true;
      if(this.applicableItems().getSelectedRows().length > 0) {
        let reportIds = this.itemsIds(this.applicableItems().getSelectedRows());
        deleteFinancialReportResults({reportIds: reportIds})
          .then((result) => {
            if (result.isSuccess) {
              this.itemsStore.removeItemsById(reportIds);
              this.recItems = this.itemsStore.getItems();
              if(this.recItems.length <= 0){
                this.deleteDisabled = true;
              }
            } else {
              this.processCustomErrorResult(result);
            }
            this.isSpinner = false;
          })
          .catch(error => {
            this.isSpinner = false;
            this.processError(error);
          });
      }
  }

  processCustomErrorResult = result => {
    if (result.errors.length > 0) {
      this.error = result.errors[0].detail;
    }
    else {
      this.error = DELETE_ERROR;
    }
  }

  processError(e) {
    this.isSpinner = false;
    let {isError, error} = ErrorUtils.processError(e);
    this.error = error;
    this.isError = isError;
  }

  handleConfirmDelete(){
    if(this.applicableItems != null){
      if(this.applicableItems().getSelectedRows().length > 0) {
        this.showPopup = true;
      } else {
        this.processError(NO_REPORTS_SELECTED_ERROR);
      }
    }
  }

  handlePopupCancel() {
      this.showPopup = false;
  }

  showCompletedToastMessage() {
    NotificationService.displayToastMessage(
      this,
      REPORT_COMPLETED,
      REPORT_MESSAGE_TITLE
    );
  }

  itemsIds = currentItems => currentItems.map(item => item.Id);
  @api applicableItems = () => this.template.querySelector("c-applicable-items");

}