import JOURNAL_ENTRY_LINE from '@salesforce/schema/Journal_Entry_Line__c';
import CREDIT from '@salesforce/schema/Journal_Entry_Line__c.Credit__c';
import DEBIT from '@salesforce/schema/Journal_Entry_Line__c.Debit__c';
import JOURNAL_ENTRY from '@salesforce/schema/Journal_Entry_Line__c.Journal_Entry__c';
import GL_ACCOUNT from '@salesforce/schema/Journal_Entry_Line__c.GL_Account__c';

import JOURNAL_ENTRY_R_JOURNAL_DATE from '@salesforce/schema/Journal_Entry_Line__c.Journal_Entry__r.Journal_Date__c';

import { CommonUtils } from "c/utils";

export default class JournalEntryLine {
  static objectApiName = JOURNAL_ENTRY_LINE.objectApiName;
  static packageQualifier = CommonUtils.getPackageQualifier(JOURNAL_ENTRY.fieldApiName);
  packageQualifier = CommonUtils.getPackageQualifier(JOURNAL_ENTRY.fieldApiName);

  static credit = CREDIT;
  static debit = DEBIT;
  static journal_entry = JOURNAL_ENTRY;
  static gl_account = GL_ACCOUNT;

  static journal_entry_r_journal_date = JOURNAL_ENTRY_R_JOURNAL_DATE;

  credit = CREDIT.fieldApiName;
  debit = DEBIT.fieldApiName;
  journal_entry = JOURNAL_ENTRY.fieldApiName;
  gl_account = GL_ACCOUNT.fieldApiName;

  journal_entry_r_journal_date = JOURNAL_ENTRY_R_JOURNAL_DATE.fieldApiName;
}