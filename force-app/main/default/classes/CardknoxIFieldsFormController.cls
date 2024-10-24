public with sharing class CardknoxIFieldsFormController {

    private Payment_Method__c paymentMethod;
    public void testinput(){
        String accToken = apexpages.currentPage().getParameters().get('inpval1');
        // String cvvToken = apexpages.currentPage().getParameters().get('inpval2');
        String expM = apexpages.currentPage().getParameters().get('inpval2');
        String expY = apexpages.currentPage().getParameters().get('inpval2');

        system.debug(accToken);
        // system.debug(cvvToken);

        paymentMethod = new Payment_Method__c();
        paymentMethod.External_Id__c = accToken;
        paymentMethod.Expiration_Month__c = expM;
        paymentMethod.Expiration_Year__c = expY;

        //call cardknox processor for creating a payment method
        //CardknoxProcessorV1.createPaymentMethod(paymentMethod);
    }
}