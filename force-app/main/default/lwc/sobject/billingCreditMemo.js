import ID from '@salesforce/schema/Billing_Credit_Memo__c.Id';
import NAME_FIELD from '@salesforce/schema/Billing_Credit_Memo__c.Name';
import BILLING_CREDIT_MEMO from '@salesforce/schema/Billing_Credit_Memo__c.Billing_Credit_Memo__c';
import BILLING_INVOICE from '@salesforce/schema/Billing_Credit_Memo__c.Billing_Invoice__c';


export default class BillingCreditMemo {
  static id = ID;  
  static name_field = NAME_FIELD;
  static billing_credit_memo = BILLING_CREDIT_MEMO;
  static billing_invoice = BILLING_INVOICE;
}