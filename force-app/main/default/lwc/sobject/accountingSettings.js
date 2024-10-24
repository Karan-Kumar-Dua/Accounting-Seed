import ACCOUNTING_SETTINGS from '@salesforce/schema/Accounting_Settings__c';
import STREET from '@salesforce/schema/Accounting_Settings__c.Street__c';
import CITY from '@salesforce/schema/Accounting_Settings__c.City__c';
import REGION from '@salesforce/schema/Accounting_Settings__c.Region__c';
import POSTAL_CODE from '@salesforce/schema/Accounting_Settings__c.Postal_Code__c';
import COUNTRY_CODE from '@salesforce/schema/Accounting_Settings__c.Country_Code__c';
import PRE_POPULATE_ACCOUNT_INFO from '@salesforce/schema/Accounting_Settings__c.Pre_Populate_Account_Info__c';
import INVENTORY_VALUATION_METHOD from '@salesforce/schema/Accounting_Settings__c.Inventory_Valuation_Method__c';
import STRIPE_CONNECTED_ACCOUNT_ID from '@salesforce/schema/Accounting_Settings__c.Stripe_Connected_Account_Id__c';

export default class AccountingSettings {
  static objectApiName = ACCOUNTING_SETTINGS.objectApiName;
  static prePopulateAccountInfo = PRE_POPULATE_ACCOUNT_INFO;
  static street = STREET;
  static city = CITY;
  static region = REGION;
  static postalCode = POSTAL_CODE;
  static countryCode = COUNTRY_CODE;
  static inventoryValuationMethod = INVENTORY_VALUATION_METHOD;
  static stripeConnectedAccountId = STRIPE_CONNECTED_ACCOUNT_ID;

  street = STREET.fieldApiName;
  city = CITY.fieldApiName;
  region = REGION.fieldApiName;
  postalCode = POSTAL_CODE.fieldApiName;
  countryCode = COUNTRY_CODE.fieldApiName;
  inventoryValuationMethod = INVENTORY_VALUATION_METHOD.fieldApiName;
  stripeConnectedAccountId = STRIPE_CONNECTED_ACCOUNT_ID.fieldApiName;
}