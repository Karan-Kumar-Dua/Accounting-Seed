import FINANCIAL_REPORT_RESULT_VALUE from '@salesforce/schema/Financial_Report_Result_Value__c';
import COLUMN_HEADER_1 from '@salesforce/schema/Financial_Report_Result_Value__c.Column_Header_1__c';
import COLUMN_HEADER_2 from '@salesforce/schema/Financial_Report_Result_Value__c.Column_Header_2__c';
import COLUMN_POSITION from '@salesforce/schema/Financial_Report_Result_Value__c.Column_Position__c';
import ROW_POSITION from '@salesforce/schema/Financial_Report_Result_Value__c.Row_Position__c';
import COLUMN_TYPE from '@salesforce/schema/Financial_Report_Result_Value__c.Column_Type__c';
import ROW_TYPE from '@salesforce/schema/Financial_Report_Result_Value__c.Row_Type__c';
import INDENT from '@salesforce/schema/Financial_Report_Result_Value__c.Indent__c';
import ROW_LABEL from '@salesforce/schema/Financial_Report_Result_Value__c.Row_Label__c';
import TEXT_VALUE from '@salesforce/schema/Financial_Report_Result_Value__c.Text_Value__c';
import CURRENCY_VALUE from '@salesforce/schema/Financial_Report_Result_Value__c.Currency_Value__c';
import SUPPRESS_CELL_HYPERLINK from '@salesforce/schema/Financial_Report_Result_Value__c.Suppress_Cell_Hyperlink__c';

import { CommonUtils } from "c/utils";

export default class financialReportResultValue {

  static packageQualifier = CommonUtils.getPackageQualifier(COLUMN_HEADER_1.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(COLUMN_HEADER_1.fieldApiName);

  static financial_report_result = FINANCIAL_REPORT_RESULT_VALUE;
  financial_report_result = FINANCIAL_REPORT_RESULT_VALUE;

  static objectApiName = FINANCIAL_REPORT_RESULT_VALUE.objectApiName;

  static column_header_1 = COLUMN_HEADER_1;
  static column_header_2 = COLUMN_HEADER_2;
  static column_position = COLUMN_POSITION;
  static column_type = COLUMN_TYPE;
  static row_position = ROW_POSITION;
  static row_type = ROW_TYPE;
  static indent = INDENT;
  static row_label = ROW_LABEL;
  static text_value = TEXT_VALUE;
  static currency_value = CURRENCY_VALUE;
  static suppress_cell_hyperlink = SUPPRESS_CELL_HYPERLINK;

  column_header_1 = COLUMN_HEADER_1.fieldApiName;
  column_header_2 = COLUMN_HEADER_2.fieldApiName;
  column_position = COLUMN_POSITION.fieldApiName;
  column_type = COLUMN_TYPE.fieldApiName;
  row_position = ROW_POSITION.fieldApiName;
  row_type = ROW_TYPE.fieldApiName;
  indent = INDENT.fieldApiName;
  row_label = ROW_LABEL.fieldApiName;
  text_value = TEXT_VALUE.fieldApiName;
  currency_value = CURRENCY_VALUE.fieldApiName;
  suppress_cell_hyperlink = SUPPRESS_CELL_HYPERLINK.fieldApiName;

}