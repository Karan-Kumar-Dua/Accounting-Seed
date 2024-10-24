import FIXED_ASSET from '@salesforce/schema/Fixed_Asset__c';
import LEDGER from '@salesforce/schema/Fixed_Asset__c.Ledger__c';
import LEDGER_R_NAME from '@salesforce/schema/Fixed_Asset__c.Ledger__r.Name';
import LEDGER_R_ACCT_METHOD from '@salesforce/schema/Fixed_Asset__c.Ledger__r.Accounting_Method__c';
import NAME_FIELD from '@salesforce/schema/Fixed_Asset__c.Name';
import VALUE from '@salesforce/schema/Fixed_Asset__c.Value__c';


export default class FixedAsset {
    static objectApiName = FIXED_ASSET.objectApiName;

    static ledger = LEDGER;
    static ledger_r_name = LEDGER_R_NAME;
    static name_field = NAME_FIELD;
    static value = VALUE;
    static ledger_r_acct_method = LEDGER_R_ACCT_METHOD;

    ledger = LEDGER.fieldApiName
    ledger_r_name = LEDGER_R_NAME.fieldApiName;
    name_field = NAME_FIELD.fieldApiName;
    value = VALUE.fieldApiName;
    ledger_r_acct_method = LEDGER_R_ACCT_METHOD.fieldApiName;
}