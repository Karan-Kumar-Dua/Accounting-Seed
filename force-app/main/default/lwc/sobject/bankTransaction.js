import BANK_TRANSACTION from '@salesforce/schema/Bank_Transaction__c';
import BASE_TYPE from '@salesforce/schema/Bank_Transaction__c.Base_Type__c';

import { CommonUtils } from "c/utils";

export default class BankTransaction {
    static objectApiName = BANK_TRANSACTION.objectApiName;
    static packageQualifier = CommonUtils.getPackageQualifier(BASE_TYPE.fieldApiName);
    packageQualifier = CommonUtils.getPackageQualifier(BASE_TYPE.fieldApiName);

    static base_type = BASE_TYPE;

    base_type = BASE_TYPE.fieldApiName;

}