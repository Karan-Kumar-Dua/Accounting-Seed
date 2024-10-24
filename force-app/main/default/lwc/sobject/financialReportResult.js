import FINANCIAL_REPORT_RESULT from '@salesforce/schema/Financial_Report_Result__c';
import LEDGER from '@salesforce/schema/Financial_Report_Result__c.Ledger__c';
import BUDGET_LEDGER from '@salesforce/schema/Financial_Report_Result__c.Budget_Ledger__c';
import ACCOUNTING_PERIOD from '@salesforce/schema/Financial_Report_Result__c.Accounting_Period__c';
import END_ACCOUNTING_PERIOD from '@salesforce/schema/Financial_Report_Result__c.End_Accounting_Period__c';
import STATUS from '@salesforce/schema/Financial_Report_Result__c.Status__c';
import RUN_FINISHED from '@salesforce/schema/Financial_Report_Result__c.Run_Finished__c';
import CREATED_BY_ID from '@salesforce/schema/Financial_Report_Result__c.CreatedById';
import GL_ACCOUNT_VARIABLE_1 from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_1__c';
import GL_ACCOUNT_VARIABLE_2 from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_2__c';
import GL_ACCOUNT_VARIABLE_3 from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_3__c';
import GL_ACCOUNT_VARIABLE_4 from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_4__c';
import FINANCIAL_REPORT_DEFINITION from '@salesforce/schema/Financial_Report_Result__c.Financial_Report_Definition__c';
import ROUNDING from '@salesforce/schema/Financial_Report_Result__c.Rounding__c';
import REPORT_TYPE from '@salesforce/schema/Financial_Report_Result__c.Report_Type__c';

import LEDGER_R_NAME from '@salesforce/schema/Financial_Report_Result__c.Ledger__r.Name';
import BUDGET_LEDGER_R_NAME from '@salesforce/schema/Financial_Report_Result__c.Budget_Ledger__r.Name';
import ACCOUNTING_PERIOD_R_NAME from '@salesforce/schema/Financial_Report_Result__c.Accounting_Period__r.Name';
import END_ACCOUNTING_PERIOD_R_NAME from '@salesforce/schema/Financial_Report_Result__c.End_Accounting_Period__r.Name';
import CREATED_BY_ID_R_NAME from '@salesforce/schema/Financial_Report_Result__c.CreatedBy.Name';
import GL_ACCOUNT_VARIABLE_1_R_NAME from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_1__r.Name';
import GL_ACCOUNT_VARIABLE_2_R_NAME from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_2__r.Name';
import GL_ACCOUNT_VARIABLE_3_R_NAME from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_3__r.Name';
import GL_ACCOUNT_VARIABLE_4_R_NAME from '@salesforce/schema/Financial_Report_Result__c.GL_Account_Variable_4__r.Name';
import FINANCIAL_REPORT_DEFINITION_R_NAME from '@salesforce/schema/Financial_Report_Result__c.Financial_Report_Definition__r.Name';

import { CommonUtils } from "c/utils";

export default class FinancialReportResult {
    static packageQualifier = CommonUtils.getPackageQualifier(LEDGER.fieldApiName);
    packageQualifier = CommonUtils.getPackageQualifier(LEDGER.fieldApiName);

    static financial_report_result = FINANCIAL_REPORT_RESULT;
    financial_report_result = FINANCIAL_REPORT_RESULT;

    static objectApiName = FINANCIAL_REPORT_RESULT.objectApiName;

    static ledger = LEDGER;
    static budget_ledger = BUDGET_LEDGER;
    static accounting_period = ACCOUNTING_PERIOD;
    static end_accounting_period = END_ACCOUNTING_PERIOD;
    static status = STATUS;
    static run_finished = RUN_FINISHED;
    static created_by_id = CREATED_BY_ID;
    static gl_account_variable_1 = GL_ACCOUNT_VARIABLE_1;
    static gl_account_variable_2 = GL_ACCOUNT_VARIABLE_2;
    static gl_account_variable_3 = GL_ACCOUNT_VARIABLE_3;
    static gl_account_variable_4 = GL_ACCOUNT_VARIABLE_4;
    static financial_report_definition = FINANCIAL_REPORT_DEFINITION;
    static rounding = ROUNDING;
    static report_type = REPORT_TYPE;

    static ledger_r_name = LEDGER_R_NAME;
    static budget_ledger_r_name = BUDGET_LEDGER_R_NAME;
    static accounting_period_r_name = ACCOUNTING_PERIOD_R_NAME;
    static end_accounting_period_r_name = END_ACCOUNTING_PERIOD_R_NAME;
    static created_by_id_r_name = CREATED_BY_ID_R_NAME;
    static gl_account_variable_1_r_name = GL_ACCOUNT_VARIABLE_1_R_NAME;
    static gl_account_variable_2_r_name = GL_ACCOUNT_VARIABLE_2_R_NAME;
    static gl_account_variable_3_r_name = GL_ACCOUNT_VARIABLE_3_R_NAME;
    static gl_account_variable_4_r_name = GL_ACCOUNT_VARIABLE_4_R_NAME;
    static financial_report_definition_r_name = FINANCIAL_REPORT_DEFINITION_R_NAME;

    ledger = LEDGER.fieldApiName;
    budget_ledger = BUDGET_LEDGER.fieldApiName;
    accounting_period = ACCOUNTING_PERIOD.fieldApiName;
    end_accounting_period = END_ACCOUNTING_PERIOD.fieldApiName;
    status = STATUS.fieldApiName;
    run_finished = RUN_FINISHED.fieldApiName;
    created_by_id = CREATED_BY_ID.fieldApiName;
    gl_account_variable_1 = GL_ACCOUNT_VARIABLE_1.fieldApiName;
    gl_account_variable_2 = GL_ACCOUNT_VARIABLE_2.fieldApiName;
    gl_account_variable_3 = GL_ACCOUNT_VARIABLE_3.fieldApiName;
    gl_account_variable_4 = GL_ACCOUNT_VARIABLE_4.fieldApiName;
    financial_report_definition = FINANCIAL_REPORT_DEFINITION.fieldApiName;
    rounding = ROUNDING.fieldApiName;
    report_type = REPORT_TYPE.fieldApiName;

    ledger_r_name = LEDGER_R_NAME.fieldApiName;
    budget_ledger_r_name = BUDGET_LEDGER_R_NAME.fieldApiName;
    accounting_period_r_name = ACCOUNTING_PERIOD_R_NAME.fieldApiName;
    end_accounting_period_r_name = END_ACCOUNTING_PERIOD_R_NAME.fieldApiName;
    created_by_id_r_name = CREATED_BY_ID_R_NAME.fieldApiName;
    gl_account_variable_1_r_name = GL_ACCOUNT_VARIABLE_1_R_NAME.fieldApiName;
    gl_account_variable_2_r_name = GL_ACCOUNT_VARIABLE_2_R_NAME.fieldApiName;
    gl_account_variable_3_r_name = GL_ACCOUNT_VARIABLE_3_R_NAME.fieldApiName;
    gl_account_variable_4_r_name = GL_ACCOUNT_VARIABLE_4_R_NAME.fieldApiName;
    financial_report_definition_r_name = FINANCIAL_REPORT_DEFINITION_R_NAME.fieldApiName;

}