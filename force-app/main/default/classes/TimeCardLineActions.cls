public with sharing class TimeCardLineActions {
    public static Set<Id> timeCardLineIds;
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static void setTimeCardLinesFromBillings(Map<Id,Billing__c> billingMap) {
        setTimeCardLinesFromBillingLines(DomainUtils.getBillingLinesByMasterId(billingMap.keySet()));
    }

    public static void setTimeCardLinesFromBillingLines(Map<Id,Billing_Line__c> billLineMap) {
        timeCardLineIds = new Set<Id>(DomainUtils.getBillingLinesWithTimeCardDaysById(billLineMap.keySet()));
    }

    public static void setTimeCardLineNonBilled() {
        List<Time_Card_Line__c> timeCardLines = new List<Time_Card_Line__c>();
        for (Time_Card_Line__c tcl : DomainUtils.getTimeCardLinesById(timeCardLineIds)) {
            tcl.Billed__c = false;
            timeCardLines.add(tcl);
        }

        SFDCSecurityUtils.updateProxy(timeCardLines);
    }

}