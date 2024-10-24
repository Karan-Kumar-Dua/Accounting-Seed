import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { FinancialReportDefinition } from "c/sobject";
import Labels from './labels';
import { LabelService } from 'c/utils';

const reportTypes = [
    {fullLabel: LabelService.commonCustomReports, label: LabelService.commonCustomReports, value: 'custom' },
];

export default class FinReporterCustomReports extends NavigationMixin(LightningElement) {
    selectedReportType = reportTypes[0];
    financialReportDefinition = FinancialReportDefinition;
    labels = Labels;

    navigateToManageReports() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: this.financialReportDefinition.objectApiName,
                actionName: 'list'
            }
        }).then(url => {
             window.open(url);
        });
    }

}