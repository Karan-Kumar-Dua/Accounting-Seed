import { api, LightningElement, track } from "lwc";
import Labels from './labels';
import { LabelService } from "c/utils";

const TRANSACTION_TYPE_OPTIONS = [
  { label: LabelService.commonAll, value: 'All'},
  { label: LabelService.commonCredit, value: 'Credit'},
  { label: LabelService.commonDebit, value: 'Debit'}
];

const TRANSACTION_STATUS_OPTIONS = [
  { label: LabelService.commonAll, value: 'All'},
  { label: LabelService.commonAdded, value: 'Added'},
  { label: Labels.INF_REMOVED, value: 'Removed'},
  { label: Labels.INF_MATCHED, value: 'Matched'},
  { label: Labels.INF_UNMATCHED, value: 'Unmatched'}
];

export default class BdcBankTransactionsFilter extends LightningElement {
  labels = {...Labels, ...LabelService};
  @api label = '';
  @api customer;
  @api customerName;
  @api glAccount;
  @api glAccountName;
  @api project;
  @api product;
  @api errors;
  @api isError = false;
  @api reference;
  @api transactionType;
  @api status;
  @api dateStart;
  @api dateEnd;
  @api amountStart;
  @api amountEnd;
  @api customStatusOptions;
  @api customTypeOptions;
  @api optionalFilter = false;

  @track currencyCode = 'USD';
  @track isMultiCurrencyEnabled = false;
  
  _defaultStatusValue = LabelService.commonStatus;
  _optionalStatusValue = LabelService.commonPostingStatus;

  get transactionTypeOptions() {
    return this.customTypeOptions !== undefined ? this.customTypeOptions : TRANSACTION_TYPE_OPTIONS;
  }

  get transactionStatusOptions() {
    return this.customStatusOptions !== undefined ? this.customStatusOptions : TRANSACTION_STATUS_OPTIONS;
  }

  get defaultTransactionStatusOptions() {
    return this.status !== undefined && this.status !== null ? this.getStatusArray(this.status) : [this.transactionStatusOptions[0]];
  }

  get statusValue() {
    return this.optionalFilter ? this._optionalStatusValue : this._defaultStatusValue;
  }

  getStatusArray(statusArray){
    let status = [];
    statusArray.forEach(function(element) {
      let interator = 0;
      status.push({label:element, name:element, key: interator++});
    });
    return status;
  }

  handleTransactionTypeChange(event) {
    this.transactionType = event.detail.value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleTransactionStatusChange(event) {
    this.status = event.detail.value.split(";").filter(Boolean);
    this.validate();
    this.valueChangeHandler(event);
  }

  handleCustomerChange(event) {
    this.customer = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
    this.customerName = event.detail.value != null && event.detail.value.recordName !== undefined ? event.detail.value.recordName : null;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleGlAccountChange(event) {
    this.glAccount = event.detail.value != null && event.detail.value.recordId !== undefined ? event.detail.value.recordId : null;
    this.glAccountName = event.detail.value != null && event.detail.value.recordName !== undefined ? event.detail.value.recordName : null;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleProjectChange(event) {
    this.project = event.detail.value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleProductChange(event) {
    this.product = event.detail.value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleReferenceChange(event) {
    this.reference = event.detail.value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleDateStartChange(event) {
    this.dateStart = event.detail.value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleDateEndChange(event) {
    this.dateEnd = event.detail.value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleAmountStartChange(event) {
    const value = event.detail.value;
    this.amountStart = value === "" ? null : value;
    this.validate();
    this.valueChangeHandler(event);
  }

  handleAmountEndChange(event) {
    const value = event.detail.value;
    this.amountEnd = value === "" ? null : value;
    this.validate();
    this.valueChangeHandler(event);
  }

  validate() {
    let datesAreValid = this.validateDateRanges();
    let amountIsValid = this.validateAmount();
    return datesAreValid & amountIsValid;
  }

  validateDateRanges() {
    let isValid = true;
    let dateCmp = this.template.querySelector(".dateEnd");

    if(this.dateEnd !== null && this.dateEnd !== undefined && this.dateStart > this.dateEnd){
      dateCmp.setCustomValidity(LabelService.errorEndDateMustBeGreaterThanStart);
      isValid = false;
    } else {
      dateCmp.setCustomValidity("");
    }
    dateCmp.reportValidity();

    return isValid;
  }

  validateAmount() {
    let isValid = false;
    let amountEndCmp = this.template.querySelector(".amountEnd");
    if (parseFloat(this.amountStart) > parseFloat(this.amountEnd)) {
      amountEndCmp.setCustomValidity(LabelService.errorMaxMustBeGreaterThanMin);
    }
    else {
      amountEndCmp.setCustomValidity("");
      isValid = true;
    }
    amountEndCmp.reportValidity();
    return isValid;
  }

  checkValidity() {
    const allValid = [...this.template.querySelectorAll('lightning-input')]
      .reduce((validSoFar, inputCmp) => {
        inputCmp.reportValidity();
        return validSoFar && inputCmp.checkValidity();
      }, true);
    return allValid;
  }

  valueChangeHandler(event) {
    event.preventDefault();
    this.dispatchEvent(new CustomEvent('valuechange', {
    cancelable: true,
    detail: {
      customer: this.customer,
      customerName: this.customerName,
      reference: this.reference,
      transactionType: this.transactionType,
      status: this.status,
      glAccount: this.glAccount,
      glAccountName: this.glAccountName,
      dateStart: this.dateStart,
      dateEnd: this.dateEnd,
      amountStart: this.amountStart,
      amountEnd: this.amountEnd,
      validFilter: this.checkValidity(),
      ...this.optionalFilter && { project: this.project },
      ...this.optionalFilter && { product: this.product }
    }
  }));
  }

}