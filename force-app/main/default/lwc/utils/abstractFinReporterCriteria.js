import {api, LightningElement, track, wire} from "lwc";
import ErrorUtils from './errorUtils';
import { LabelService } from './labelService';
import NotificationService from './notificationService';
import Constants from "./constants";
import isMultiCurrencyEnabled from '@salesforce/apex/FinancialReporterHelper.isMultiCurrencyEnabled';
import fetchRateTableCurrencies from '@salesforce/apex/FinancialReporterHelper.fetchRateTableCurrencies';

const RUN_ERROR = 'An error occurred while running the report.';
const REPORT_PROGRESS = 'Report generation is in progress.';
const REPORT_MESSAGE_TITLE = 'Financial Reports';

const ROUNDING_OPTIONS = [
  {fullLabel: 'No Rounding', label: 'No Rounding', value: 'No Rounding'},
  {fullLabel: 'Whole Amounts', label: 'Whole Amounts', value: 'Whole Amounts'},
  {fullLabel: 'Round to 1000s', label: 'Round to 1000s', value: 'Round to 1000s'},
];

export default class AbstractFinReporterCriteria extends LightningElement {
  static DEFAULT_CURRENCY = 'USD';

  /**
   * Financial Report Options DTO data type definition
   * @typedef FinancialReportOptions
   * @property {string} ledger
   * @property {string} glVariable1
   * @property {string} glVariable2
   * @property {string} glVariable3
   * @property {string} glVariable4
   * @property {string} startingAccountingPeriod
   * @property {string} endingAccountingPeriod
   * @property {string} subtitle
   * @property {boolean} includeSubType1
   * @property {boolean} includeSubType2
   * @property {boolean} suppressZeroAmountRows
   */

  /** @return {FinancialReportOptions} */
  @api
  get values() {
    return this.runOptions;
  }

  @track selectedLedgerId;
  @track selectedLedgerType;
  @track selectedCurrency = AbstractFinReporterCriteria.DEFAULT_CURRENCY;

  @wire(fetchRateTableCurrencies)
  fetchRateTableCurrencies(result) {
    result.data &&
      (this.rateTableCurrencies = result.data);
  }

  @wire(isMultiCurrencyEnabled)
  setIsMultiCurrency({ data }) {
    if (data) {
      this.isMultiCurrencyEnabled = data;
    }
  }

  getDefaultsOptions(data, error) {
    if (data) {
      this.defaults = data;
      if (this.defaults.reportTypeName !== 'Cash Flow Statement' || this.defaults.isCashFlowStatement) {
        if (this.rateTableCurrencies && !this.rateTableCurrencies.find(item => item.value === this.defaults.currencyISO)) {
          this.selectedCurrency = this.rateTableCurrencies[0]?.value;
          this.showMissingCurrencyMessage();
        } else {
          this.selectedCurrency = this.defaults.currencyISO;
        }
      }
      this.runOptions = {...data, ...this.runOptions};
      this.roundingOptions = ROUNDING_OPTIONS;
      this.loaded = true;
    } else if (error) {
      this.loaded = true;
    }
  }

 
  handleRunReport(runReport) {
    this.error = null;
    this.runButtonDisabled = true;
    runReport({options: JSON.stringify({...this.runOptions, currencyISO: this.selectedCurrency})})
      .then(result => {
        if (result.isSuccess) {
          this.showProgressToastMessage();
        } else {
          this.processCustomErrorResult(result);
        }
        this.runButtonDisabled = false;
      }).catch(e => this.processError(e));
  }

  processError(e) {
    this.runButtonDisabled = false;
    let {isError, error} = ErrorUtils.processError(e);
    this.error = error;
    this.isError = isError;
  }

  showProgressToastMessage() {
    NotificationService.displayToastMessage(
      this,
      REPORT_PROGRESS,
      REPORT_MESSAGE_TITLE
    );
  }

  showMissingCurrencyMessage() {
    NotificationService.displayToastMessage(
        this,
        LabelService.frCurrencyValueMissing,
        'Error',
        'error'
    );
  }

  processCustomErrorResult = result => {
    if (result.errors.length > 0) {
      this.error = result.errors[0].detail;
    }
    else {
      this.error = RUN_ERROR;
    }
  }

  setLedger(event, childInstance, selectedLedgerId) {
    this.selectedLedgerId = selectedLedgerId || (event.detail && event.detail.value && event.detail.value[0]);

    const currencyIso = this.defaults && this.defaults.currenciesByLedgerIds && this.defaults.currenciesByLedgerIds[this.selectedLedgerId];
    if (this.selectedLedgerId && this.isMultiCurrencyEnabled) {
      this.rateTableCurrencies.find(item => item.value === currencyIso) && (this.selectedCurrency = currencyIso) || this.showMissingCurrencyMessage();
    }
    this.runOptions.ledger = this.selectedLedgerId;
    this.clearGLVariables(childInstance);
  }
  setStartPeriod(event) {
    this.runOptions.startingAccountingPeriod = event.detail && event.detail.recordId;
  }
  setEndPeriod(event) {
    this.runOptions.endingAccountingPeriod = event.detail && event.detail.recordId;
  }
  setIncludeSubType1(event) {
    this.runOptions.includeSubType1 = event.detail.checked;
  }
  setIncludeSubType2(event) {
    this.runOptions.includeSubType2 = event.detail.checked;
  }
  setSuppressZeroRows(event) {
    this.runOptions.suppressZeroAmountRows = event.detail.checked;
  }
  setSuppressOpeningBalanceAndPeriodCols(event) {
    this.runOptions.suppressOpeningBalanceAndPeriodColumns = event.detail.checked;
  }
  setShowAllPeriods(event) {
    this.runOptions.showAllPeriods = event.detail.checked;
  }
  setGLVar1(event) {
    this.runOptions.glVariable1 = event.detail.value[0];
  }
  setGLVar2(event) {
    this.runOptions.glVariable2 = event.detail.value[0];
  }
  setGLVar3(event) {
    this.runOptions.glVariable3 = event.detail.value[0];
  }
  setGLVar4(event) {
    this.runOptions.glVariable4 = event.detail.value[0];
  }
  setSubtitle(event) {
    this.runOptions.subtitle = event.detail.value;
  }
  setRoundingMode(event) {
    this.runOptions.currentRoundingMode = event.detail.value;
  }

  clearGLVariables(instance) {
    const acctVariableFields = instance.template.querySelectorAll('lightning-input-field[data-form="acct-variables"]');
    acctVariableFields && acctVariableFields.forEach(acctVariableField => {
      acctVariableField.reset();
    });
    this.runOptions.glVariable1 = null, this.runOptions.glVariable2 = null,
        this.runOptions.glVariable3 = null, this.runOptions.glVariable4 = null;
  }

  handleCurrencyChange(event) {
    this.selectedCurrency = event.detail.value;
  }
}