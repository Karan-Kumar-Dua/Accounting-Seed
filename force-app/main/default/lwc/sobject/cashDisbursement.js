import CASH_DISBURSEMENT from '@salesforce/schema/Cash_Disbursement__c';
import PAYMENT_STATUS from '@salesforce/schema/Cash_Disbursement__c.Payment_Status__c';
import DEBIT_GL_ACCOUNT from '@salesforce/schema/Cash_Disbursement__c.Debit_GL_Account__c';
import BANK_RECONCILIATION from '@salesforce/schema/Cash_Disbursement__c.Bank_Reconciliation__c';
import BANK_TRANSACTION from '@salesforce/schema/Cash_Disbursement__c.Bank_Transaction__c';
import DISBURSEMENT_DATE from '@salesforce/schema/Cash_Disbursement__c.Disbursement_Date__c';
import CLEARED_DATE from '@salesforce/schema/Cash_Disbursement__c.Cleared_Date__c';
import REFERENCE from '@salesforce/schema/Cash_Disbursement__c.Reference__c';
import CHECK_NUMBER from '@salesforce/schema/Cash_Disbursement__c.Check_Number__c';
import DESCRIPTION from '@salesforce/schema/Cash_Disbursement__c.Description__c';
import BANK_ACCOUNT from '@salesforce/schema/Cash_Disbursement__c.Bank_Account__c';
import AMOUNT from '@salesforce/schema/Cash_Disbursement__c.Amount__c';
import VENDOR from '@salesforce/schema/Cash_Disbursement__c.Vendor__c';
import CONTACT from '@salesforce/schema/Cash_Disbursement__c.Contact__c';
import EMPLOYEE from '@salesforce/schema/Cash_Disbursement__c.Employee__c';
import LEDGER_AMOUNT from '@salesforce/schema/Cash_Disbursement__c.Ledger_Amount__c';
import SOURCE from '@salesforce/schema/Cash_Disbursement__c.Source__c';

import BANK_RECONCILIATION_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Bank_Reconciliation__r.Name';
import BANK_TRANSACTION_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Bank_Transaction__r.Name';
import DEBIT_GL_ACCOUNT_R_BANK from '@salesforce/schema/Cash_Disbursement__c.Debit_GL_Account__r.Bank__c';
import DEBIT_GL_ACCOUNT_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Debit_GL_Account__r.Name';
import BANK_ACCOUNT_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Bank_Account__r.Name';
import VENDOR_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Vendor__r.Name';
import CONTACT_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Contact__r.Name';
import EMPLOYEE_R_NAME from '@salesforce/schema/Cash_Disbursement__c.Employee__r.Name';

import { CommonUtils } from "c/utils";

export default class CashDisbursement {
  static objectApiName = CASH_DISBURSEMENT.objectApiName;
  static packageQualifier = CommonUtils.getPackageQualifier(DEBIT_GL_ACCOUNT.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(DEBIT_GL_ACCOUNT.fieldApiName);

  static payment_status = PAYMENT_STATUS;
  static debit_gl_account = DEBIT_GL_ACCOUNT;
  static bank_reconciliation = BANK_RECONCILIATION;
  static bank_transaction = BANK_TRANSACTION;
  static disbursement_date = DISBURSEMENT_DATE;
  static cleared_date = CLEARED_DATE;
  static reference = REFERENCE;
  static check_number = CHECK_NUMBER;
  static description = DESCRIPTION;
  static bank_account = BANK_ACCOUNT;
  static amount = AMOUNT;
  static vendor = VENDOR;
  static contact = CONTACT;
  static employee = EMPLOYEE;
  static ledger_amount = LEDGER_AMOUNT;
  static source = SOURCE;

  static bank_reconciliation_r_name = BANK_RECONCILIATION_R_NAME;
  static bank_transaction_r_name = BANK_TRANSACTION_R_NAME;
  static debit_gl_account_r_bank = DEBIT_GL_ACCOUNT_R_BANK;
  static debit_gl_account_r_name = DEBIT_GL_ACCOUNT_R_NAME;
  static bank_account_r_name = BANK_ACCOUNT_R_NAME;
  static vendor_r_name = VENDOR_R_NAME;
  static contact_r_name = CONTACT_R_NAME;
  static employee_r_name = EMPLOYEE_R_NAME;

  payment_status = PAYMENT_STATUS.fieldApiName;
  debit_gl_account = DEBIT_GL_ACCOUNT.fieldApiName;
  bank_reconciliation = BANK_RECONCILIATION.fieldApiName;
  bank_transaction = BANK_TRANSACTION.fieldApiName;
  disbursement_date = DISBURSEMENT_DATE.fieldApiName;
  cleared_date = CLEARED_DATE.fieldApiName;
  reference = REFERENCE.fieldApiName;
  check_number = CHECK_NUMBER.fieldApiName;
  description = DESCRIPTION.fieldApiName;
  bank_account = BANK_ACCOUNT.fieldApiName;
  amount = AMOUNT.fieldApiName;
  vendor = VENDOR.fieldApiName;
  contact = CONTACT.fieldApiName;
  employee = EMPLOYEE.fieldApiName;
  ledger_amount = LEDGER_AMOUNT.fieldApiName;
  source = SOURCE.fieldApiName;

  bank_reconciliation_r_name = BANK_RECONCILIATION_R_NAME.fieldApiName;
  bank_transaction_r_name = BANK_TRANSACTION_R_NAME.fieldApiName;
  debit_gl_account_r_bank = DEBIT_GL_ACCOUNT_R_BANK.fieldApiName;
  debit_gl_account_r_name = DEBIT_GL_ACCOUNT_R_NAME.fieldApiName;
  bank_account_r_name = BANK_ACCOUNT_R_NAME.fieldApiName;
  vendor_r_name = VENDOR_R_NAME.fieldApiName;
  contact_r_name = CONTACT_R_NAME.fieldApiName;
  employee_r_name = EMPLOYEE_R_NAME.fieldApiName;

  static SOURCE_VALUES = {
    MANUAL: 'Manual',
    PAYABLE: 'Payable'
  };
}