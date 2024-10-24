import FINANCIAL_REPORTER_SETTINGS from '@salesforce/schema/Financial_Reporter_Settings__c';
import COMPANY_NAME from '@salesforce/schema/Financial_Reporter_Settings__c.Company_Name__c';
import COLUMN_HEADER_VARIANT from '@salesforce/schema/Financial_Reporter_Settings__c.Column_Header_Variant__c';
import ROUNDING from '@salesforce/schema/Financial_Reporter_Settings__c.Rounding__c';
import EXPAND_REPORT_ROWS from '@salesforce/schema/Financial_Reporter_Settings__c.Expand_Report_Rows__c';

export default class FinancialReporterSettings {

    static financial_reporter_settings = FINANCIAL_REPORTER_SETTINGS;
    financial_reporter_settings = FINANCIAL_REPORTER_SETTINGS;

    static objectApiName = FINANCIAL_REPORTER_SETTINGS.objectApiName;

    static company_name = COMPANY_NAME;
    static column_header_variant = COLUMN_HEADER_VARIANT;
    static rounding = ROUNDING;
    static expand_report_rows = EXPAND_REPORT_ROWS;

    company_name = COMPANY_NAME.fieldApiName;
    column_header_variant = COLUMN_HEADER_VARIANT.fieldApiName;
    rounding = ROUNDING.fieldApiName;
    expand_report_rows = EXPAND_REPORT_ROWS.fieldApiName;

}