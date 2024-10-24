import FINANCIAL_REPORT_DEFINITION from '@salesforce/schema/Financial_Report_Definition__c';
import SUBTITLE from '@salesforce/schema/Financial_Report_Definition__c.Subtitle__c';
import NAME_FIELD from '@salesforce/schema/Financial_Report_Definition__c.Name';
import PERCENTAGE_DECIMAL_PLACES from '@salesforce/schema/Financial_Report_Definition__c.Percentage_Decimal_Places__c';

export default class FinancialReportDefinition {
    static objectApiName = FINANCIAL_REPORT_DEFINITION.objectApiName;

    static subtitle = SUBTITLE;
    static name_field = NAME_FIELD;
    static percentage_decimal_places = PERCENTAGE_DECIMAL_PLACES;

    subtitle = SUBTITLE.fieldApiName;
    name_field = NAME_FIELD.fieldApiName;
    percentage_decimal_places = PERCENTAGE_DECIMAL_PLACES.fieldApiName;
}