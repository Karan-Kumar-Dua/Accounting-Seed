import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { BankReconciliation } from "c/sobject";
import { NotificationService, LabelService } from 'c/utils';
import createBankReconciliationPDFReport from '@salesforce/apex/BankReconciliationHelper.createBankReconciliationPDFReport';
import createBankReconciliationCSVFile from '@salesforce/apex/BankReconciliationHelper.createBankReconciliationCSVFile';
import Labels from './labels';

const FIELDS = [BankReconciliation.status, BankReconciliation.modern_br];
const COMPLETED = 'Completed';

const PDF_WARNING = Labels.WRN_RECONCILIATION_PDF_SUMMARY_CANNOT_GENERATED;
const CSV_WARNING = Labels.WRN_CSV_BANK_RECONCILIATION_NOT_SUPPORTED_KOALI;

export default class BankRecCreatePdfReport extends LightningElement {
  labels = {...Labels, ...LabelService};
  @api recordId;
  @api reportType = 'pdf';
  br = new BankReconciliation();
  disableCreateButton = false;
  error;
  pdf = LabelService.commonPDF;
  csv = LabelService.commonCSV;
  report = LabelService.commonSummary;
  file = LabelService.commonFile;

  @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
  getRecord({ error, data }) {
    if (data) {
      if (this.reportType === 'pdf' && data.fields[this.br.status].value !== COMPLETED) {
        this.disableCreateButton = true;
        this.showWarningMessage(PDF_WARNING);
      }
      else if (this.reportType === 'csv' && !data.fields[this.br.modern_br].value) {
        this.disableCreateButton = true;
        this.showWarningMessage(CSV_WARNING);
      }
      else {
        this.disableCreateButton = false;
      }
    }
    else if (error) {
      this.error = error;
    }
  }

  get reportInfoValue() {
    return this.reportType === 'pdf' ? this.pdf + ' ' + this.report : this.csv + ' ' + this.file;
  }

  get reportValue() {
    return this.reportType === 'pdf' ? LabelService.commonSmallReport: '';
  }

  get reportOrFileValue() {
    return this.reportType === 'pdf' ? LabelService.commonSmallReport: LabelService.commonSmallFile;
  }

  get reportTypeValue() {
    return this.reportType === 'pdf' ? this.pdf: this.csv;
  }

  connectedCallback() {
    this.disableCreateButton = true;
  }

  handleCreateReport() {
    if (this.reportType === 'pdf') {
      createBankReconciliationPDFReport({bankRecId: this.recordId});
    }
    else {
      createBankReconciliationCSVFile({bankRecId: this.recordId});
    }
    NotificationService.displayToastMessage(this, `${Labels.INF_A_BANK_RECONCILIATION} ${this.reportInfoValue} ${this.reportValue} ${Labels.INF_WAS_SUCCESSFULLY_GENERATED}`);
    this.closeDialogEvent();
  }

  showWarningMessage(text) {
    NotificationService.displayToastMessage(this, text, '', 'Warning');
  }

  handleCancel() {
    this.closeDialogEvent();
  }

  closeDialogEvent() {
    this.dispatchEvent(new CustomEvent('closedialog'));
  }

}