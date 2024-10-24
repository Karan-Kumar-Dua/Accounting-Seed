@IsTest
private class ScheduledRevExpFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new ScheduledRevExpenseFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.scheduledRevenues[0].Amount__c = 554;
                update testData.scheduledRevenues[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new ScheduledRevExpenseFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.scheduledRevenues[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldStatusField() {
        TestDataSuite testData = TestDataSuite.getInstance().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            List<PostResult> postResults =
                postHandler.unpost(new List<Scheduled_Revenue_Expense__c>{testData.scheduledRevenues[0]});
            System.assertEquals(true, postResults[0].isSuccess);

            SourceDocumentUpdateFieldValidator sfu = new ScheduledRevExpenseFieldUpdateValidator();
            Scheduled_Revenue_Expense__c cd = [SELECT Id, Status__c FROM Scheduled_Revenue_Expense__c WHERE Id = :testData.scheduledRevenues[0].Id LIMIT 1];

            DMLException dmlEx;
            try {
                cd.Status__c = 'Posted';
                update cd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new ScheduledRevExpenseFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.scheduledRevenues[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }
}