import TAX_GROUP from '@salesforce/schema/Tax_Group__c';
import TAX_GROUP_NAME from '@salesforce/schema/Tax_Group__c.Name';
import COMBINED_TAX_RATE from '@salesforce/schema/Tax_Group__c.Combined_Tax_Rate__c';
import TAX_TYPE from '@salesforce/schema/Tax_Group__c.Tax_Type__c';
export default class TaxGroup {
    static objectApiName = TAX_GROUP.objectApiName;

    static combinedTaxRate = COMBINED_TAX_RATE;
    static taxGroupName = TAX_GROUP_NAME;
    static tax_type = TAX_TYPE;

    combinedTaxRate = COMBINED_TAX_RATE.fieldApiName;
    taxGroupName = TAX_GROUP_NAME.fieldApiName;
    tax_type = TAX_TYPE.fieldApiName;

}