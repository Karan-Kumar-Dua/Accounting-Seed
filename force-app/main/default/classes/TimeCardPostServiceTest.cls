@IsTest
private class TimeCardPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testAPIPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<PostResult> results = TimeCardPostService.postTimeCards(testData.timeCards);

            System.assertEquals(
                16, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c IN :testData.timeCards
                ]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c = :testData.timeCards[0].Id
                    GROUP BY Time_Card_Day__r.Time_Card_Line__r.Time_Card__c
                ][0].get('sum')
            );

            results = TimeCardPostService.unpostTimeCards(testData.timeCards);
            Test.stopTest();

            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Time_Card_Day__r.Time_Card_Line__r.Time_Card__c IN :testData.timeCards
                ]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Status__c FROM Time_Card__c WHERE Id = :testData.timeCards[0].Id].Status__c
            );
        }

    }
}