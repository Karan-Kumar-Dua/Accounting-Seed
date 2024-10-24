import PAYMENT_METHOD from '@salesforce/schema/Payment_Method__c';

import EXTERNAL_Id from '@salesforce/schema/Payment_Method__c.External_Id__c';
import PAYMENT_METHOD_TYPE from '@salesforce/schema/Payment_Method__c.Payment_Method_Type__c';

export default class PaymentMethod {
    static objectApiName = PAYMENT_METHOD.objectApiName;
    static externalId = EXTERNAL_Id;
    static paymentMethodType = PAYMENT_METHOD_TYPE;

    externalId = EXTERNAL_Id.fieldApiName;
    paymentMethodType = PAYMENT_METHOD_TYPE.fieldApiName;
}