import { wire } from 'lwc';
import getCustomReportDefaults from '@salesforce/apex/FinancialReporterHelper.getCustomReportDefaults';
import runCustomReport from '@salesforce/apex/FinancialReporterHelper.runCustomReport';
import { AccountingPeriod, FinancialReportResult, FinancialReportDefinition } from "c/sobject";
import { AbstractFinReporterCriteria, LabelService } from "c/utils";
import Labels from './labels';

export default class FinReporterCriteriaCustomReports extends AbstractFinReporterCriteria {
    labels = {...LabelService, ...Labels};
    financialReportResult = FinancialReportResult;
    accountingPeriod = AccountingPeriod;
    financialReportDefinition = FinancialReportDefinition;

    runOptions = {};
    defaults = {};
    loaded = false;
    runButtonDisabled = false;
    error;
    isError = false;
    
    @wire(getCustomReportDefaults)
    getDefaults({ data, error }) {
        this.getDefaultsOptions(data, error);
        this.selectedCurrency = this.runOptions.currencyISO;
    }

    setCustomReport(event) {
        this.runOptions.financialReportDefinitionId = event.detail && event.detail.recordId;
    }

    handleRun() {
       this.handleRunReport(runCustomReport);
    }
}