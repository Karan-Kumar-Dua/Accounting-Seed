import { wire } from 'lwc';
import getBalanceSheetDefaults from '@salesforce/apex/FinancialReporterHelper.getBalanceSheetDefaults';
import runBalanceSheet from '@salesforce/apex/FinancialReporterHelper.runBalanceSheet';
import getSettings from "@salesforce/apex/FinancialReporterSettingsHelper.getSettings";
import {AccountingPeriod, FinancialReportResult, FinancialReporterSettings, Ledger} from "c/sobject";
import { AbstractFinReporterCriteria, LabelService } from "c/utils";
import {getFieldValue, getRecord} from "lightning/uiRecordApi";

export default class FinReporterCriteriaBalanceSheet extends AbstractFinReporterCriteria {
    labels = {...LabelService};
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

    @wire(getBalanceSheetDefaults)
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
        this.handleRunReport(runBalanceSheet);
    }
    setLedger(event) {
        super.setLedger(event, this);
        this.receiveSettings(this.runOptions.ledger);
      }

}