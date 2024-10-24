trigger PDFFormat on Billing_Format__c (after insert, after update, before delete) {

    if (Trigger.isAfter && Trigger.isInsert) {
        PDFFormatActions.checkVFPageExists(Trigger.new);
        PDFFormatActions.checkEmailTemplateExists(Trigger.new);
        PDFFormatActions.checkAutomatedEmailDeliveryField(Trigger.new);
        PDFFormatActions.validateOrgWideEmailAddress(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        PDFFormatActions.checkVFPageExists(Trigger.new);
        PDFFormatActions.checkEmailTemplateExists(Trigger.new);
        PDFFormatActions.checkAutomatedEmailDeliveryField(Trigger.new);
        PDFFormatActions.validateOrgWideEmailAddress(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isInsert) {
        PDFFormatActions.setAutomatedEmailDeliveryField(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        PDFFormatActions.setAutomatedEmailDeliveryField(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        PDFFormatActions.preventDeleteIfRelatedRecordsExist(Trigger.oldMap);
    }

}