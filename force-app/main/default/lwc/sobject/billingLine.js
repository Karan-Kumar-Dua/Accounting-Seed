import BILLING_LINE from '@salesforce/schema/Billing_Line__c';
import DATE from '@salesforce/schema/Billing_Line__c.Date__c';
import HOURS_UNITS from '@salesforce/schema/Billing_Line__c.Hours_Units__c';
import RATE from '@salesforce/schema/Billing_Line__c.Rate__c';
import TAX_AMOUNT2 from '@salesforce/schema/Billing_Line__c.Tax_Amount2__c';
import SUB_TOTAL from '@salesforce/schema/Billing_Line__c.Sub_Total__c';
import TOTAL from '@salesforce/schema/Billing_Line__c.Total__c';
import TAX_RATE from '@salesforce/schema/Billing_Line__c.Tax_Rate__c';
export default class BillingLine {
  static objectApiName = BILLING_LINE.objectApiName;
  
  static date = DATE; 
  static hours_units = HOURS_UNITS; 
  static rate = RATE;
  static tax_amount2 = TAX_AMOUNT2;
  static sub_total = SUB_TOTAL;
  static total = TOTAL;
  static tax_rate = TAX_RATE;
}