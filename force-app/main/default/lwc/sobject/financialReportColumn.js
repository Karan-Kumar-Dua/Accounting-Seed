import FINANCIAL_REPORT_COLUMN from '@salesforce/schema/Financial_Report_Column__c';
import LEDGER from '@salesforce/schema/Financial_Report_Column__c.Ledger__c';
import POSITION from '@salesforce/schema/Financial_Report_Column__c.Position__c';
import OFFSET from '@salesforce/schema/Financial_Report_Column__c.Offset__c';

export default class FinancialReportColumn {
    static objectApiName = FINANCIAL_REPORT_COLUMN.objectApiName;
    static ledger = LEDGER;
    static position = POSITION;
    static offset = OFFSET;

    ledger = LEDGER.fieldApiName;
    position = POSITION.fieldApiName;
    offset = OFFSET.fieldApiName;
}