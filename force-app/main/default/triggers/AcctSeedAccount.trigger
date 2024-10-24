trigger AcctSeedAccount on Account (before insert, before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isInsert) {

        AcctSeedAccountActions.checkFeatureParameterFieldLevelAccessInsert();
        AcctSeedAccountActions.setAccountingActive(Trigger.new);
        AcctSeedAccountActions.setAndPreventEnablePaymentService(Trigger.new, null);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        AcctSeedAccountActions.apAutomationPostMessage(Trigger.new,null);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {

        AcctSeedAccountActions.checkFeatureParameterFieldLevelAccessUpdate();
        AcctSeedAccountActions.setAccountingActive(Trigger.new);
        AcctSeedAccountActions.setAndPreventEnablePaymentService(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        AcctSeedAccountActions.apAutomationPostMessage(Trigger.new,Trigger.oldMap);
    }
}