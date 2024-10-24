import { api, LightningElement } from 'lwc';
import { LabelService } from 'c/utils';
import Labels from './labels';

const reportTypes = [
    {fullLabel: LabelService.stdReportProfitLoss,    label: LabelService.stdReportProfitLoss,      value: 'profitLoss' },
    {fullLabel: Labels.INF_PROFIT_LOSS_VS_BUDGET,    label: Labels.INF_P_AND_L_VS_BUDGET,          value: 'profitLossVsBudget' },
    {fullLabel: LabelService.stdReportBalanceSheet,  label: LabelService.stdReportBalanceSheet,    value: 'balanceSheet' },
    {fullLabel: LabelService.stdReportTrialBalance,  label: LabelService.stdReportTrialBalance,    value: 'trialBalance' },
    {fullLabel: LabelService.enablementsCashFlow,    label: LabelService.stdReportCashFlow,        value: 'cashFlow' },
    {fullLabel: LabelService.stdReportLedgerInquiry, label: LabelService.stdReportLedgerInquiry,   value: 'ledgerInquiry' }
];

export default class FinReporterStdReports extends LightningElement {

    labels = Labels;
    selectStandardReportWithCharacter = Labels.INF_SELECT_STANDARD_REPORT + ' ‌ ‌';
    reportTypes = reportTypes;
    @api defaultAcctPeriod;
    @api ledgerId;
    @api glAccountId;
    @api defaultglav1;
    @api defaultglav2;
    @api defaultglav3;
    @api defaultglav4;

    selectedReportType = reportTypes[0];

    @api
    set activeReportValue(value) {
        const found = reportTypes.find(t => value === t.value && value !== this.selectedReportType.value);
        if (found) {
            this.selectedReportType = found;
        }
    }
    get activeReportValue() {
        return this.selectedReportType.value;
    }

    
    get showProfitLoss() {
        return this.selectedReportType.value === 'profitLoss';
    }

    get showProfitLossVsBudget() {
        return this.selectedReportType.value === 'profitLossVsBudget';
    }

    get showBalanceSheet() {
        return this.selectedReportType.value === 'balanceSheet';
    }

    get showTrialBalance() {
        return this.selectedReportType.value === 'trialBalance';
    }

    get showCashFlow() {
        return this.selectedReportType.value === 'cashFlow';
    }

    get showLedgerInquiry() {
        return this.selectedReportType.value === 'ledgerInquiry';
    }

    handleReportTypeSelection(event) {
        const selection = event.detail.value;
        this.selectedReportType = reportTypes.find(opt => opt.value === selection);
    }

}