import { wire } from 'lwc';
import getProfitLossVsBudgetDefaults from '@salesforce/apex/FinancialReporterHelper.getProfitLossVsBudgetDefaults';
import runProfitLossVsBudget from '@salesforce/apex/FinancialReporterHelper.runProfitLossVsBudget';
import getSettings from "@salesforce/apex/FinancialReporterSettingsHelper.getSettings";
import { AccountingPeriod, Ledger, FinancialReportResult, FinancialReporterSettings } from "c/sobject";
import { AbstractFinReporterCriteria, Constants, LabelService } from "c/utils";
import { keywords } from "c/lookupKeywords";
import {getFieldValue, getRecord} from "lightning/uiRecordApi";
import Labels from './labels';

export default class FinReporterCriteriaProfitLossVsBudget extends AbstractFinReporterCriteria {
    labels = {...LabelService, ...Labels};
    financialReportResult = FinancialReportResult;
    financialReporterSettings = FinancialReporterSettings;
    accountingPeriod = AccountingPeriod;
    ledger = Ledger;

    runOptions = {};
    defaults = {};
    loaded = false;
    runButtonDisabled = false;
    error;
    isError = false;
    defaultRoundingMode;

    ledgerFilter = {
        type: keywords.type.STRING,
        field: this.ledger.type1.fieldApiName,
        op: keywords.op.IN,
        val: [Constants.LEDGER.TYPE_TRANSACTIONAL, Constants.LEDGER.TYPE_CONSOLIDATIONS_TRANSACTIONAL, Constants.LEDGER.TYPE_ELIMINATIONS_TRANSACTIONAL]
    }

    budgetLedgerFilter = {
        type: keywords.type.STRING,
        field: this.ledger.type1.fieldApiName,
        op: keywords.op.IN,
        val: [Constants.LEDGER.TYPE_BUDGET, Constants.LEDGER.TYPE_CONSOLIDATIONS_BUDGET, Constants.LEDGER.TYPE_ELIMINATIONS_BUDGET]
    }

    @wire(getRecord, {recordId: '$selectedLedgerId', fields: [Ledger.type1]})
    getRecordValues({data}) {
        if (data) {
            this.selectedLedgerType = getFieldValue(data, Ledger.type1);
        }
    }

    @wire(getProfitLossVsBudgetDefaults)
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

    setLedger(event) {
        super.setLedger(event, this, event.detail && event.detail.recordId);
        this.selectedLedgerId = event.detail && event.detail.recordId;
        this.runOptions.ledger = this.selectedLedgerId;
        this.receiveSettings(this.runOptions.ledger);
    }

    setBudgetLedger(event) {
        this.runOptions.budgetLedger = event.detail ? event.detail.recordId : null;
    }

    handleRun() {
        this.handleRunReport(runProfitLossVsBudget);
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

}