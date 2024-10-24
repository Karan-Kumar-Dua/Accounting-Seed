import { wire } from 'lwc';
import getCashFlowDefaults from '@salesforce/apex/FinancialReporterHelper.getCashFlowDefaults';
import runCashFlow from '@salesforce/apex/FinancialReporterHelper.runCashFlow';
import getSettings from "@salesforce/apex/FinancialReporterSettingsHelper.getSettings";
import {FinancialReportResult, AccountingPeriod, FinancialReporterSettings, Ledger} from 'c/sobject';
import { AbstractFinReporterCriteria, LabelService } from "c/utils";
import {getFieldValue, getRecord} from "lightning/uiRecordApi";
import Labels from './labels';

export default class FinReporterCriteriaCashFlow extends AbstractFinReporterCriteria {
  labels = {...LabelService, ...Labels};
  financialReportResult = FinancialReportResult;
  financialReporterSettings = FinancialReporterSettings;
  accountingPeriod = AccountingPeriod;

  runOptions = {};
  defaults = {};
  loaded = false;
  runButtonDisabled = false;
  error;
  isError = false;
  defaultRoundingMode;

  @wire(getRecord, {recordId: '$selectedLedgerId', fields: [Ledger.type1]})
  getRecordValues({data}) {
    if (data) {
      this.selectedLedgerType = getFieldValue(data, Ledger.type1);
    }
  }

  @wire(getCashFlowDefaults)
  async getDefaults({ data, error }) { 
    await this.getDefaultsOptions(data, error);
    this.receiveSettings(this.runOptions.ledger);
  }

  async receiveSettings(ledgerId) {
    this.isError = false;
    getSettings({ledgerId: ledgerId})
        .then(result => {
            this.defaultRoundingMode = result.settings[FinancialReporterSettings.rounding.fieldApiName];
            this.runOptions.currentRoundingMode = this.defaultRoundingMode;
        })
        .catch(error => {
          this.processError(error);
        });
  }

  handleRun() {
    this.handleRunReport(runCashFlow);
  }

  setLedger(event) {
    super.setLedger(event, this);
    this.receiveSettings(this.runOptions.ledger);
  }

}