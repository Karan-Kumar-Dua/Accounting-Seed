import { wire } from 'lwc';
import getTrialBalanceDefaults from '@salesforce/apex/FinancialReporterHelper.getTrialBalanceDefaults';
import runTrialBalance from '@salesforce/apex/FinancialReporterHelper.runTrialBalance';
import getSettings from "@salesforce/apex/FinancialReporterSettingsHelper.getSettings";
import {FinancialReportResult, AccountingPeriod, FinancialReporterSettings, Ledger} from 'c/sobject';
import { AbstractFinReporterCriteria, LabelService } from "c/utils";
import {getFieldValue, getRecord} from "lightning/uiRecordApi";
import Labels from './labels';

export default class FinReporterCriteriaTrialBalance extends AbstractFinReporterCriteria {
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

  @wire(getTrialBalanceDefaults)
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
    this.handleRunReport(runTrialBalance);
  }

  setLedger(event) {
    super.setLedger(event, this);
    this.receiveSettings(this.runOptions.ledger);
  }

}