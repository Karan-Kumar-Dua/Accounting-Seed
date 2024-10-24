import PAYMENT_PROCESSOR from '@salesforce/schema/Payment_Processor__c';

import NAME_FIELD from '@salesforce/schema/Payment_Processor__c.Name';
import TYPE from '@salesforce/schema/Payment_Processor__c.Type__c';
import ACTIVE from '@salesforce/schema/Payment_Processor__c.Active__c';
import EXTERNAL_KEY from '@salesforce/schema/Payment_Processor__c.External_Key__c';
import MERCHANT_GL_ACCOUNT from '@salesforce/schema/Payment_Processor__c.Merchant_GL_Account__c';
import TEST_MODE from '@salesforce/schema/Payment_Processor__c.Test_Mode__c';
import CC_PERCENT from '@salesforce/schema/Payment_Processor__c.CC_Percent__c';
import CC_FLAT_FEE from '@salesforce/schema/Payment_Processor__c.CC_Flat_Fee__c';
import ENABLE_CON_FEE from '@salesforce/schema/Payment_Processor__c.Enable_Convenience_Fees__c';
import CREDIT_CARD_FEE_TYPE from '@salesforce/schema/Payment_Processor__c.Credit_Card_Convenience_Fee_Type__c';
import CON_FEE_GL_Account from '@salesforce/schema/Payment_Processor__c.Convenience_Fees_GL_Account__c';
import ACH_FEE_TYPE from '@salesforce/schema/Payment_Processor__c.ACH_Convenience_Fee_Type__c';
import ACH_FLAT_FEE from '@salesforce/schema/Payment_Processor__c.ACH_Flat_Fee__c';
import ACH_PERCENT from '@salesforce/schema/Payment_Processor__c.ACH_Percent__c';




export default class PaymentProcessor {
    static objectApiName = PAYMENT_PROCESSOR.objectApiName;

    static active = ACTIVE;
    static type = TYPE;
    static nameField = NAME_FIELD;
    static externalKey = EXTERNAL_KEY;
    static testmode = TEST_MODE;
    static merchantGlAccount = MERCHANT_GL_ACCOUNT;
    static conFeeGLAccount = CON_FEE_GL_Account;
    static creditCardFeeType = CREDIT_CARD_FEE_TYPE;
    static enableConFee = ENABLE_CON_FEE;
    static ccFlatFee = CC_FLAT_FEE;
    static ccPercent = CC_PERCENT;
    static achFeeType = ACH_FEE_TYPE;
    static achFlatFee = ACH_FLAT_FEE;
    static achPercent = ACH_PERCENT;

    active = ACTIVE.fieldApiName;
    type = TYPE.fieldApiName;
    nameField = NAME_FIELD.fieldApiName;
    externalKey = EXTERNAL_KEY.fieldApiName;
    testmode = TEST_MODE.fieldApiName;
    merchantGlAccount = MERCHANT_GL_ACCOUNT.fieldApiName;
    conFeeGLAccount = CON_FEE_GL_Account.fieldApiName;
    creditCardFeeType = CREDIT_CARD_FEE_TYPE.fieldApiName;
    enableConFee = ENABLE_CON_FEE.fieldApiName;
    ccFlatFee = CC_FLAT_FEE.fieldApiName;
    ccPercent = CC_PERCENT.fieldApiName;
    achFeeType = ACH_FEE_TYPE.fieldApiName;
    achFlatFee = ACH_FLAT_FEE.fieldApiName;
    achPercent = ACH_PERCENT.fieldApiName;
}