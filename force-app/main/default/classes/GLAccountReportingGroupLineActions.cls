public with sharing class GLAccountReportingGroupLineActions {

    public static final String DUPLICATED_GL_ACCOUNT_IN_REPORTING_GROUP = Label.ERR_DUPLICATED_GL_ACCOUNT_IN_REPORTING_GROUP;

    public static void validateUniquenessOfGLAccountInGLAccountReportingGroup(List<GL_Account_Reporting_Group_Line__c> newLines) {
        Set<Id> glAccountReportingGroupIds = new Set<Id>();
        Map<Id, Set<Id>> glAccountReportingGroupIdToGlAccountIds = new Map<Id, Set<Id>>();

        //First, validate new records between each other
        for (GL_Account_Reporting_Group_Line__c newLine : newLines) {

            glAccountReportingGroupIds.add(newLine.GL_Account_Reporting_Group__c);

            if (glAccountReportingGroupIdToGlAccountIds.containsKey(newLine.GL_Account_Reporting_Group__c)
                    && glAccountReportingGroupIdToGlAccountIds.get(newLine.GL_Account_Reporting_Group__c).contains(newLine.GL_Account__c)) {

                newLine.GL_Account__c.addError(DUPLICATED_GL_ACCOUNT_IN_REPORTING_GROUP);
            }
            else if (glAccountReportingGroupIdToGlAccountIds.containsKey(newLine.GL_Account_Reporting_Group__c)
                        && !glAccountReportingGroupIdToGlAccountIds.get(newLine.GL_Account_Reporting_Group__c).contains(newLine.GL_Account__c)) {

                glAccountReportingGroupIdToGlAccountIds.get(newLine.GL_Account_Reporting_Group__c).add(newLine.GL_Account__c);
            }
            else {
                glAccountReportingGroupIdToGlAccountIds.put(
                    newLine.GL_Account_Reporting_Group__c,
                    new Set<Id>{newLine.GL_Account__c}
                );
            }
        }

        //Then, check for already existed records with same GL Account lookup value
        glAccountReportingGroupIdToGlAccountIds = new Map<Id, Set<Id>>();
        for (GL_Account_Reporting_Group__c repGroup : DomainUtils.getGlAccountReportingGroupByIdWithRelatedLines(
                glAccountReportingGroupIds, new Map<Id, GL_Account_Reporting_Group_Line__c>(newLines).keySet())) {

            Set<Id> alreadyExistedGlAccountId = new Set<Id>();
            for (GL_Account_Reporting_Group_Line__c existedLine : repGroup.GL_Account_Reporting_Group_Lines__r) {
                alreadyExistedGlAccountId.add(existedLine.GL_Account__c);
            }
            glAccountReportingGroupIdToGlAccountIds.put(repGroup.Id, alreadyExistedGlAccountId);
        }

        for (GL_Account_Reporting_Group_Line__c newLine : newLines) {
            if (glAccountReportingGroupIdToGlAccountIds.get(newLine.GL_Account_Reporting_Group__c).contains(newLine.GL_Account__c)) {
                newLine.GL_Account__c.addError(DUPLICATED_GL_ACCOUNT_IN_REPORTING_GROUP);
            }
        }
    }

}