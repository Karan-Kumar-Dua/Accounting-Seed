import FINANCIAL_REPORT_ROW from '@salesforce/schema/Financial_Report_Row__c';
import GL_ACCOUNTING_VARIABLE_1 from '@salesforce/schema/Financial_Report_Row__c.GL_Account_Variable_1__c';
import GL_ACCOUNTING_VARIABLE_2 from '@salesforce/schema/Financial_Report_Row__c.GL_Account_Variable_2__c';
import GL_ACCOUNTING_VARIABLE_3 from '@salesforce/schema/Financial_Report_Row__c.GL_Account_Variable_3__c';
import GL_ACCOUNTING_VARIABLE_4 from '@salesforce/schema/Financial_Report_Row__c.GL_Account_Variable_4__c';
import TYPE from '@salesforce/schema/Financial_Report_Row__c.Type__c';
import GL_ACCOUNT from '@salesforce/schema/Financial_Report_Row__c.GL_Account__c';
import POSITION from '@salesforce/schema/Financial_Report_Row__c.Position__c';

export default class FinancialReportRow {
    static objectApiName = FINANCIAL_REPORT_ROW.objectApiName;
    static gl_accounting_variable_1 = GL_ACCOUNTING_VARIABLE_1;
    static gl_accounting_variable_2 = GL_ACCOUNTING_VARIABLE_2;
    static gl_accounting_variable_3 = GL_ACCOUNTING_VARIABLE_3;
    static gl_accounting_variable_4 = GL_ACCOUNTING_VARIABLE_4;
    static type = TYPE;
    static gl_account = GL_ACCOUNT;
    static position = POSITION;

    gl_accounting_variable_1 = GL_ACCOUNTING_VARIABLE_1.fieldApiName;
    gl_accounting_variable_2 = GL_ACCOUNTING_VARIABLE_2.fieldApiName;
    gl_accounting_variable_3 = GL_ACCOUNTING_VARIABLE_3.fieldApiName;
    gl_accounting_variable_4 = GL_ACCOUNTING_VARIABLE_4.fieldApiName;
    type = TYPE.fieldApiName;
    gl_account = GL_ACCOUNT.fieldApiName;
    position = POSITION.fieldApiName;
}