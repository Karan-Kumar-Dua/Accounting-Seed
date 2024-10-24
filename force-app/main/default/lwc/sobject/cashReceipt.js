import CASH_RECEIPT from '@salesforce/schema/Cash_Receipt__c';
import RECEIPT_DATE from '@salesforce/schema/Cash_Receipt__c.Receipt_Date__c';
import PAYMENT_REFERENCE from '@salesforce/schema/Cash_Receipt__c.Payment_Reference__c';
import CREDIT_GL_ACCOUNT from '@salesforce/schema/Cash_Receipt__c.Credit_GL_Account__c';
import BANK_ACCOUNT from '@salesforce/schema/Cash_Receipt__c.Bank_Account__c';
import ACCOUNT from '@salesforce/schema/Cash_Receipt__c.Account__c';
import PAYMENT_TYPE from '@salesforce/schema/Cash_Receipt__c.Payment_Type__c';
import MEMO from '@salesforce/schema/Cash_Receipt__c.Memo__c';
import CASH_RECEIPT_NAME from '@salesforce/schema/Cash_Receipt__c.Name';
import BALANCE from '@salesforce/schema/Cash_Receipt__c.Balance__c';
import CHECK_NUMBER from '@salesforce/schema/Cash_Receipt__c.Check_Number__c';
import AMOUNT from '@salesforce/schema/Cash_Receipt__c.Amount__c';
import PROJECT from '@salesforce/schema/Cash_Receipt__c.Project__c';
import PRODJECT_TASK from '@salesforce/schema/Cash_Receipt__c.Project_Task__c';
import DESCRIPTION from '@salesforce/schema/Cash_Receipt__c.Description__c';
import CASH_FLOW_CATEGORY from '@salesforce/schema/Cash_Receipt__c.Cash_Flow_Category__c';

import CREDIT_GL_ACCOUNT_R_BANK from '@salesforce/schema/Cash_Receipt__c.Credit_GL_Account__r.Bank__c';
import CREDIT_GL_ACCOUNT_R_NAME from '@salesforce/schema/Cash_Receipt__c.Credit_GL_Account__r.Name';
import BANK_ACCOUNT_R_NAME from '@salesforce/schema/Cash_Receipt__c.Bank_Account__r.Name';
import ACCOUNT_R_NAME from '@salesforce/schema/Cash_Receipt__c.Account__r.Name';

import CASH_FLOW_CATEGORY_R_NAME from '@salesforce/schema/Cash_Receipt__c.Cash_Flow_Category__r.Name';
import VOID_DESCRIPTION from '@salesforce/schema/Cash_Receipt__c.Void_Description__c';
import PAYMENT_PROCESSOR_TYPE from '@salesforce/schema/Cash_Receipt__c.Payment_Processor__r.Type__c';
import PAYMENT_PROCESSOR_NAME from '@salesforce/schema/Cash_Receipt__c.Payment_Processor__r.Name';
import VOID from '@salesforce/schema/Cash_Receipt__c.Void__c';



import { CommonUtils } from "c/utils";

export default class CashReceipt {
  static objectApiName = CASH_RECEIPT.objectApiName;
  static packageQualifier = CommonUtils.getPackageQualifier(CREDIT_GL_ACCOUNT.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(CREDIT_GL_ACCOUNT.fieldApiName);

  static receipt_date = RECEIPT_DATE;
  static payment_reference = PAYMENT_REFERENCE;
  static credit_gl_account = CREDIT_GL_ACCOUNT;
  static bank_account = BANK_ACCOUNT;
  static account = ACCOUNT;
  static payment_type = PAYMENT_TYPE;
  static memo = MEMO;
  static cash_receipt_name = CASH_RECEIPT_NAME;
  static balance = BALANCE;
  static check_number = CHECK_NUMBER;
  static amount = AMOUNT;

  static credit_gl_account_r_bank = CREDIT_GL_ACCOUNT_R_BANK;
  static credit_gl_account_r_name = CREDIT_GL_ACCOUNT_R_NAME;
  static bank_account_r_name = BANK_ACCOUNT_R_NAME;
  static account_r_name = ACCOUNT_R_NAME;

  static cash_flow_category_name = CASH_FLOW_CATEGORY_R_NAME;
  static void_description = VOID_DESCRIPTION;
  static cash_flow_category = CASH_FLOW_CATEGORY;
  static payment_processor_type = PAYMENT_PROCESSOR_TYPE;
  static payment_processor_name = PAYMENT_PROCESSOR_NAME;
  static void = VOID;

  receipt_date = RECEIPT_DATE.fieldApiName;
  payment_reference = PAYMENT_REFERENCE.fieldApiName;
  credit_gl_account = CREDIT_GL_ACCOUNT.fieldApiName;
  bank_account = BANK_ACCOUNT.fieldApiName;
  account = ACCOUNT.fieldApiName;
  payment_type = PAYMENT_TYPE.fieldApiName;
  memo = MEMO.fieldApiName;
  cash_receipt_name = CASH_RECEIPT_NAME.fieldApiName;
  balance = BALANCE.fieldApiName;
  check_number = CHECK_NUMBER.fieldApiName;
  amount = AMOUNT.fieldApiName;
  project = PROJECT.fieldApiName;
  project_task = PRODJECT_TASK.fieldApiName;
  description = DESCRIPTION.fieldApiName;
  cash_flow_category = CASH_FLOW_CATEGORY.fieldApiName;

  credit_gl_account_r_bank = CREDIT_GL_ACCOUNT_R_BANK.fieldApiName;
  credit_gl_account_r_name = CREDIT_GL_ACCOUNT_R_NAME.fieldApiName;
  bank_account_r_name = BANK_ACCOUNT_R_NAME.fieldApiName;
  account_r_name = ACCOUNT_R_NAME.fieldApiName;

  cash_flow_category_name = CASH_FLOW_CATEGORY_R_NAME.fieldApiName;
  void_description = VOID_DESCRIPTION.fieldApiName;
  payment_processor_type = PAYMENT_PROCESSOR_TYPE.fieldApiName;
  payment_processor_name = PAYMENT_PROCESSOR_NAME.fieldApiName;
  void = VOID.fieldApiName;
}