import LEDGER_HIERARCHY from '@salesforce/schema/Ledger_Hierarchy__c';
import NAME from '@salesforce/schema/Ledger_Hierarchy__c.Name';
import LEDGER from '@salesforce/schema/Ledger_Hierarchy__c.Ledger__c';
import GENERATED_BY from '@salesforce/schema/Ledger_Hierarchy__c.Generated_By__c';
import NOTES from '@salesforce/schema/Ledger_Hierarchy__c.Notes__c';
import TYPE1 from '@salesforce/schema/Ledger_Hierarchy__c.Hierarchy_Type__c';
import STATUS from '@salesforce/schema/Ledger_Hierarchy__c.Hierarchy_Status__c';
import LAST_RUN from '@salesforce/schema/Ledger_Hierarchy__c.Last_Run__c';
import PARENT_LEDGER_HIERARCHY from '@salesforce/schema/Ledger_Hierarchy__c.Parent_Ledger_Hierarchy__c';
import SORT_ORDER from '@salesforce/schema/Ledger_Hierarchy__c.Sort_Order__c';

import LAST_PERIOD_R_NAME from '@salesforce/schema/Ledger_Hierarchy__c.Last_Period__r.Name';
import LAST_PERIOD_R_ID from '@salesforce/schema/Ledger_Hierarchy__c.Last_Period__r.Id';
import GENERATED_BY_R_NAME from '@salesforce/schema/Ledger_Hierarchy__c.Generated_By__r.Name';
import LEDGER_R_NAME from '@salesforce/schema/Ledger_Hierarchy__c.Ledger__r.Name';
import LEDGER_R_TYPE from '@salesforce/schema/Ledger_Hierarchy__c.Ledger__r.Type__c';
import LAST_MODIFIED_R_NAME from '@salesforce/schema/Ledger_Hierarchy__c.LastModifiedBy.Name';
const LEDGER_R_CURRENCY = {...LEDGER_R_NAME, fieldApiName: `${LEDGER_R_NAME && LEDGER_R_NAME.fieldApiName.split('.')[0]}.CurrencyIsoCode`};

export default class LedgerHierarchy {
  static objectApiName = LEDGER_HIERARCHY.objectApiName;

  static xname = NAME;
  static ledger = LEDGER;
  static generated_by = GENERATED_BY;
  static notes = NOTES;
  static type1 = TYPE1;
  static status = STATUS;
  static last_run = LAST_RUN;
  static parentLedgerHierarchy = PARENT_LEDGER_HIERARCHY;
  static sort_order = SORT_ORDER;
  static ledger_r_name = LEDGER_R_NAME;
  static ledger_r_type = LEDGER_R_TYPE;
  static ledger_r_currency = LEDGER_R_CURRENCY;
  static last_period_r_name = LAST_PERIOD_R_NAME;
  static last_period_r_id = LAST_PERIOD_R_ID;
  static generated_by_r_name = GENERATED_BY_R_NAME;
  static last_modified_r_name = LAST_MODIFIED_R_NAME;

  type1 = TYPE1.fieldApiName;
  generated_by = GENERATED_BY.fieldApiName;
  status = STATUS.fieldApiName;
  last_run = LAST_RUN.fieldApiName;
  parentLedgerHierarchy = PARENT_LEDGER_HIERARCHY.fieldApiName;
  sort_order = SORT_ORDER.fieldApiName;
  ledger_r_name = LEDGER_R_NAME.fieldApiName;
  ledger_r_type = LEDGER_R_TYPE.fieldApiName;
  ledger_r_currency = LEDGER_R_CURRENCY.fieldApiName;
  last_period_r_name = LAST_PERIOD_R_NAME.fieldApiName;
  last_period_r_id = LAST_PERIOD_R_ID.fieldApiName;
  generated_by_r_name = GENERATED_BY_R_NAME.fieldApiName;
  last_modified_r_name = LAST_MODIFIED_R_NAME.fieldApiName;
}