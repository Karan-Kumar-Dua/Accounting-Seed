import BANK_DISBURSEMENT from '@salesforce/schema/Bank_Disbursement__c';
import DISBURSEMENT_DATE from '@salesforce/schema/Bank_Disbursement__c.Disbursement_Date__c';
import DISBURSEMENT_REFERENCE from '@salesforce/schema/Bank_Disbursement__c.Disbursement_Reference__c';
import BANK_ACCOUNT from '@salesforce/schema/Bank_Disbursement__c.Bank_GL_Account__c';
import AMOUNT from '@salesforce/schema/Bank_Disbursement__c.Amount__c';

import { CommonUtils } from "c/utils";

export default class BankDisbursement {
  static objectApiName = BANK_DISBURSEMENT.objectApiName;
  static packageQualifier = CommonUtils.getPackageQualifier(DISBURSEMENT_DATE.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(DISBURSEMENT_REFERENCE.fieldApiName);

  static disbursement_date = DISBURSEMENT_DATE;
  static disbursement_reference = DISBURSEMENT_REFERENCE;
  static bank_account = BANK_ACCOUNT;
  static amount = AMOUNT;

  disbursement_date = DISBURSEMENT_DATE.fieldApiName;
  disbursement_reference = DISBURSEMENT_REFERENCE.fieldApiName;
  bank_account = BANK_ACCOUNT.fieldApiName;
  amount = AMOUNT.fieldApiName;
}