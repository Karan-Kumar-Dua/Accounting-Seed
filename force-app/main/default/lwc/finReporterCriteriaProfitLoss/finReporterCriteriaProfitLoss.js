import { wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getProfitLossDefaults from '@salesforce/apex/FinancialReporterHelper.getProfitLossDefaults';
import runProfitLoss from '@salesforce/apex/FinancialReporterHelper.runProfitLoss';
import getSettings from "@salesforce/apex/FinancialReporterSettingsHelper.getSettings";
import {AccountingPeriod, FinancialReportResult, FinancialReporterSettings, Ledger} from "c/sobject";
import { AbstractFinReporterCriteria, LabelService } from "c/utils";

export default class FinReporterCriteriaProfitLoss extends AbstractFinReporterCriteria {
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

    @wire(getProfitLossDefaults)
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
        this.handleRunReport(runProfitLoss);
    }

    setIncludeSubType2(event) {
        super.setIncludeSubType2(event);
        let includeSubtype1Checkbox = this.template.querySelector('lightning-input[data-jest="includeSubType1"]');
        if (event.detail.checked) {
            super.setIncludeSubType1(event);
            includeSubtype1Checkbox.checked = true;
            includeSubtype1Checkbox.disabled = true;
        }
        else {
            includeSubtype1Checkbox.disabled = false;
        }
    }

    setLedger(event) {
        super.setLedger(event, this);
        this.receiveSettings(this.runOptions.ledger);
    }
}