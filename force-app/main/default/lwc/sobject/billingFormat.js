import BILLING_FORMAT from "@salesforce/schema/Billing_Format__c";
import TYPE from "@salesforce/schema/Billing_Format__c.Type__c";

export default class BillingFormat {
    static objectApiName = BILLING_FORMAT.objectApiName;

    static type = TYPE;
}