trigger AccountTax on Account_Tax__c (after insert, after update) {

    if (Trigger.isInsert && Trigger.isAfter) {
        AccountTaxActions.validateTaxRateProduct(Trigger.new, NULL);
    }

    if (Trigger.isUpdate && Trigger.isAfter) {
        AccountTaxActions.validateTaxRateProduct(Trigger.new, Trigger.oldMap);
    }

}