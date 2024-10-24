trigger PaymentProposal on Payment_Proposal__c(before insert, before update, before delete, after update ){

    //Payment Proposal sObject is part of the Payment Services feature.  Without it enabled then block all DML to object
    if (Trigger.isBefore){
        PaymentProposalActions.checkFeatureParameterObjectLevelAccess();
    }  

    if (Trigger.isBefore && Trigger.isInsert){
        PaymentProposalActions.validateValueForDateTypeField(Trigger.new );
        PaymentProposalActions.validateCurrencyISOCode(Trigger.new, Trigger.oldMap);
        PaymentProposalActions.validatePPBankAccountEnrollmentStatus(Trigger.new);
        PaymentProposalActions.updateDefaultLedgerOnPaymentProposal(Trigger.New);
    }

    if (Trigger.isBefore && Trigger.isUpdate){
        PaymentProposalActions.validateValueForDateTypeField(Trigger.new );
        PaymentProposalActions.validateCurrencyISOCode(Trigger.new, Trigger.oldMap);
        PaymentProposalActions.validatePPBankAccountEnrollmentStatus(Trigger.new);
        PaymentProposalActions.validatePayableCreditMemo(Trigger.new, Trigger.oldMap);
        PaymentProposalActions.validateCurrencyCodeUpdate(Trigger.new, Trigger.oldMap);
        PaymentProposalActions.updateDefaultLedgerOnPaymentProposal(Trigger.New);
    }

    if (Trigger.isAfter && Trigger.isUpdate){
        PaymentProposalActions.insertOrDeleteParentPPL(Trigger.new, Trigger.oldMap);
    }
}