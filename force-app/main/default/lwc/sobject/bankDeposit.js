import BANK_DEPOSIT from '@salesforce/schema/Bank_Deposit__c';
import DEPOSIT_DATE from '@salesforce/schema/Bank_Deposit__c.Deposit_Date__c';
import DEPOSIT_REFERENCE from '@salesforce/schema/Bank_Deposit__c.Deposit_Reference__c';
import BANK_ACCOUNT from '@salesforce/schema/Bank_Deposit__c.Bank_Account__c';
import AMOUNT from '@salesforce/schema/Bank_Deposit__c.Amount__c';

import { CommonUtils } from "c/utils";

export default class BankDeposit {
  static objectApiName = BANK_DEPOSIT.objectApiName;
  static packageQualifier = CommonUtils.getPackageQualifier(DEPOSIT_DATE.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(DEPOSIT_DATE.fieldApiName);

  static deposit_date = DEPOSIT_DATE;
  static deposit_reference = DEPOSIT_REFERENCE;
  static bank_account = BANK_ACCOUNT;
  static amount = AMOUNT;

  deposit_date = DEPOSIT_DATE.fieldApiName;
  deposit_reference = DEPOSIT_REFERENCE.fieldApiName;
  bank_account = BANK_ACCOUNT.fieldApiName;
  amount = AMOUNT.fieldApiName;
}