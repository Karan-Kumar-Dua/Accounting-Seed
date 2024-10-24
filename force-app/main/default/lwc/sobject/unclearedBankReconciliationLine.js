import DATE from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Date__c';
import DESCRIPTION from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Description__c';
import PAYEE_ID from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Payee_Id__c';
import PAYEE_NAME from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Payee_Name__c';
import TYPE from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Type__c';
import BANK_DEPOSIT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Bank_Deposit__c';
import CASH_DISBURSEMENT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Disbursement__c';
import CASH_RECEIPT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__c';
import JOURNAL_ENTRY_LINE from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Journal_Entry_Line__c';
import REFERENCE from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Reference__c';

import BANK_DEPOSIT_R_NAME from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Bank_Deposit__r.Name';
import CASH_DISBURSEMENT_R_NAME from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Disbursement__r.Name';
import CASH_DISBURSEMENT_R_DEBIT_GL_ACCOUNT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Disbursement__r.Debit_GL_Account__c';
import CASH_DISBURSEMENT_R_CHECK_NUMBER from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Disbursement__r.Check_Number__c';
import CASH_RECEIPT_R_NAME from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__r.Name';
import CASH_RECEIPT_R_CREDIT_GL_ACCOUNT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__r.Credit_GL_Account__c';
import CASH_RECEIPT_R_CHECK_NUMBER from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__r.Check_Number__c';
import JOURNAL_ENTRY_LINE_R_NAME from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Journal_Entry_Line__r.Name';
import JOURNAL_ENTRY_LINE_R_CREDIT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Journal_Entry_Line__r.Credit__c';
import JOURNAL_ENTRY_LINE_R_DEBIT from '@salesforce/schema/Uncleared_Bank_Reconciliation_Line__c.Journal_Entry_Line__r.Debit__c';

import { CommonUtils } from "c/utils";

export default class UnclearedBankReconciliationLine {
  static packageQualifier = CommonUtils.getPackageQualifier(DATE.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(DATE.fieldApiName);

  static date = DATE;
  static description = DESCRIPTION;
  static payee_id = PAYEE_ID;
  static payee_name = PAYEE_NAME;
  static type = TYPE;
  static bank_deposit = BANK_DEPOSIT;
  static cash_disbursement = CASH_DISBURSEMENT;
  static cash_receipt = CASH_RECEIPT;
  static journal_entry_line = JOURNAL_ENTRY_LINE;
  static reference = REFERENCE;

  static bank_deposit_r_name = BANK_DEPOSIT_R_NAME;
  static cash_disbursement_r_check_number = CASH_DISBURSEMENT_R_CHECK_NUMBER;
  static cash_disbursement_r_name = CASH_DISBURSEMENT_R_NAME;
  static cash_receipt_r_name = CASH_RECEIPT_R_NAME;
  static cash_disbursement_r_debit_gl_account = CASH_DISBURSEMENT_R_DEBIT_GL_ACCOUNT;
  static cash_receipt_r_credit_gl_account = CASH_RECEIPT_R_CREDIT_GL_ACCOUNT;
  static cash_receipt_r_check_number = CASH_RECEIPT_R_CHECK_NUMBER;
  static journal_entry_line_r_name = JOURNAL_ENTRY_LINE_R_NAME;
  static journal_entry_line_r_credit = JOURNAL_ENTRY_LINE_R_CREDIT;
  static journal_entry_line_r_debit = JOURNAL_ENTRY_LINE_R_DEBIT;

  date = DATE.fieldApiName;
  description = DESCRIPTION.fieldApiName;
  payee_id = PAYEE_ID.fieldApiName;
  payee_name = PAYEE_NAME.fieldApiName;
  type = TYPE.fieldApiName;
  bank_deposit = BANK_DEPOSIT.fieldApiName;
  cash_disbursement = CASH_DISBURSEMENT.fieldApiName;
  cash_receipt = CASH_RECEIPT.fieldApiName;
  journal_entry_line = JOURNAL_ENTRY_LINE.fieldApiName;
  reference = REFERENCE.fieldApiName;

  bank_deposit_r_name = BANK_DEPOSIT_R_NAME.fieldApiName;
  cash_disbursement_r_name = CASH_DISBURSEMENT_R_NAME.fieldApiName;
  cash_receipt_r_name = CASH_RECEIPT_R_NAME.fieldApiName;
  cash_disbursement_r_debit_gl_account = CASH_DISBURSEMENT_R_DEBIT_GL_ACCOUNT.fieldApiName;
  cash_receipt_r_credit_gl_account = CASH_RECEIPT_R_CREDIT_GL_ACCOUNT.fieldApiName;
  cash_receipt_r_check_number = CASH_RECEIPT_R_CHECK_NUMBER.fieldApiName;
  journal_entry_line_r_name = JOURNAL_ENTRY_LINE_R_NAME.fieldApiName;
  journal_entry_line_r_credit = JOURNAL_ENTRY_LINE_R_CREDIT.fieldApiName;
  journal_entry_line_r_debit = JOURNAL_ENTRY_LINE_R_DEBIT.fieldApiName;
  cash_disbursement_r_check_number = CASH_DISBURSEMENT_R_CHECK_NUMBER.fieldApiName;
}