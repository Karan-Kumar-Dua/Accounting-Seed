trigger PaymentProposalLine on Payment_Proposal_Line__c (before insert, before update, after insert, after update, after delete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        PaymentProposalLineActions.validate(Trigger.new, Trigger.oldMap);
        PaymentProposalLineActions.setPayableAndDefaultAmount(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        PaymentProposalLineActions.validate(Trigger.new, Trigger.oldMap);
        PaymentProposalLineActions.setPayableAndDefaultAmount(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate )){
        PaymentProposalLineActions.setParentPPLTotal(Trigger.new);
    }
    if(Trigger.isAfter && Trigger.isDelete){
        PaymentProposalLineActions.setParentPPLTotal(Trigger.old);
    }
}