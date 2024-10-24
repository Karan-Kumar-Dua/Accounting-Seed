import { LightningElement, api, wire } from "lwc";
import Helper from './finReporterLedgerInquiryTableHelper';
import FinReporterLedgerInquiryTableStore from './finReporterLedgerInquiryTableStore';
import { SortStrategyFactory, LabelService } from "c/utils";
import { FinancialReportResult } from "c/sobject";
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import Labels from "./labels";

const KEY_FIELD = 'Id';
const MAX_ITEMS_LOADED = 8001;

export default class FinReporterLedgerInquiryTable extends LightningElement {
  frr = new FinancialReportResult();
  recItems;
  labels = {...LabelService, ...Labels};
  columns = Helper.getColumns();
  itemsStore = new FinReporterLedgerInquiryTableStore();
  keyField = KEY_FIELD;
  pageSize = 50;
  sortFactory;
  error;
  sortOpts = {
    sortedBy: 'transactionLink',
    sortedDirection: 'desc'
  };
  glVariable1Value = LabelService.commonGLVariable + ' 1';
  glVariable2Value = LabelService.commonGLVariable + ' 2';
  glVariable3Value = LabelService.commonGLVariable + ' 3';
  glVariable4Value = LabelService.commonGLVariable + ' 4';
  reportCriteriaOptions;
  isXlsExportInProgress = false;

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

  @api
  setValues(result) {
    this.itemsStore.setItems(result);
    this.sort(this.sortOpts.sortedBy, this.sortOpts.sortedDirection);
    this.setGlavsHeaderValue();
    if (this.gridCmp()) {
      this.gridCmp().showFirstPage();
    }
  }

  @api
  setOpeningBalance(result) {
    this.itemsStore.setOpeningBalance(result);
  }

  @api
  setReportCriteriaOptions(options) {
    this.reportCriteriaOptions = options;
  }

  get maxItemsDisplayed() {
    return MAX_ITEMS_LOADED - 1;
  }

  setGlavsHeaderValue() {
    this.columns[9].label = this.glVariable1Value;
    this.columns[10].label = this.glVariable2Value;
    this.columns[11].label = this.glVariable3Value;
    this.columns[12].label = this.glVariable4Value;
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
    let sortFn = this.sortFactory.getSortStrategy(field, direction, this.transformTotalAmountValue);
    this.itemsStore.sort(sortFn);
    this.itemsStore.setRunningBalance();
    this.recItems = this.itemsStore.getItems();
  }

  transformTotalAmountValue = val => {
    let updated = {...val};
    updated.totalAmount = updated.amount;
    return updated;
  }

  handleExportExcel() {

    try {
      if (this.reportCriteriaOptions) {
        this.isXlsExportInProgress = true;
        let base64 = btoa(JSON.stringify(this.reportCriteriaOptions));
        window.open('/apex/' + this.frr.packageQualifier + 'LedgerInquiryInXlsFormat?options=' + base64, "_self");
        setTimeout(() => this.isXlsExportInProgress = false, 3000);
      }
    }
    catch (error) {
      console.error(error);
      this.isXlsExportInProgress = false
    }

  }

  gridCmp = () => this.template.querySelector(".itemsGrid");

}