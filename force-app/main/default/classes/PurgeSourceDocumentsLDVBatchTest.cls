@IsTest
private class PurgeSourceDocumentsLDVBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPurgeBatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            for (Billing__c billing : testData.billings) {
                billing.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
            }

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(testData.billings, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            List<Billing__c> billingsToCheckStatus = [
                SELECT Id
                FROM Billing__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            ];
            System.assertEquals(false, billingsToCheckStatus.isEmpty());


            PurgeSourceDocumentsLDVBatch batch = new PurgeSourceDocumentsLDVBatch();
            Database.executeBatch(batch);
            Test.stopTest();

            billingsToCheckStatus = [
                SELECT Id
                FROM Billing__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            ];
            System.assertEquals(true, billingsToCheckStatus.isEmpty());
        }
    }
    @IsTest
    private static void testPurgeBatchCheckEmailCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            for (Billing__c billing : testData.billings) {
                billing.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
            }

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(testData.billings, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            List<Billing__c> billingsToCheckStatus = [
                SELECT Id,Ledger__c
                FROM Billing__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            ];
            
            
            List<Transaction_Group__c> txnGroups = new List<Transaction_Group__c>();

            //create transaction groups for all the billings
            for(Billing__c bill : billingsToCheckStatus){
                txnGroups.add(new Transaction_Group__c(
                    Billing__c = bill.Id,
                    Status__c = TransactionGroupActions.STATUS_PROCESSING,
                    Batch_Id__c = bill.Id,
                    Job_Type__c = 'Test Job',
                    Line_Count__c = 0,
                    Lines_Processed__c = 0,
                    Ledger__c = bill.Ledger__c
                ));
            }
            INSERT txnGroups;

            PurgeSourceDocumentsLDVBatch batch = new PurgeSourceDocumentsLDVBatch();
            Database.executeBatch(batch);

            Test.stopTest();

            //create email body to apply asserts
            String emailBody = Label.INF_PURGE_DOCUMENT_STUCK_JOB_IS_COMPLETED_BODY
            + '\n' + Label.COMMON_RECORDS_PROCESSED + ': ' + String.valueOf(txnGroups.size())
            + '\n' + Label.COMMON_RECORDS_SUCCEEDED + ': ' + String.valueOf(txnGroups.size())
            + '\n' + Label.COMMON_RECORDS_FAILED + ': ' + String.valueOf(0);

            List<EmailMessage> sentEmails = [SELECT Id, ToAddress, Subject, HtmlBody,TextBody FROM EmailMessage];
            //make sure the email record is created with the specified details
            Assert.areEqual(1, sentEmails.size());
            Assert.areNotEqual(null,sentEmails[0]);
            Assert.areEqual(UserInfo.getUserEmail(), sentEmails[0].ToAddress);
            Assert.areEqual(Label.INF_PURGE_DOCUMENT_STUCK_JOB_IS_COMPLETED_SUBJECT, sentEmails[0].Subject);
            Assert.areEqual(emailBody, sentEmails[0].TextBody);

            //all the transaction groups should be deleted for the billings
            Assert.areEqual(0, [SELECT Id,Billing__c FROM Transaction_Group__c WHERE Billing__c IN: billingsToCheckStatus].size());

            billingsToCheckStatus = [
                SELECT Id
                FROM Billing__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            ];
            System.assertEquals(true, billingsToCheckStatus.isEmpty());
        }
    }
    @IsTest
    private static void testPurgeBatchCheckEmailCreatedAndExtraRecordDeleted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            for (Billing__c billing : testData.billings) {
                billing.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
            }

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(testData.billings, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            List<Billing__c> billingsToCheckStatus = [
                SELECT Id,Ledger__c
                FROM Billing__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            ];
            
            
            List<Transaction_Group__c> txnGroups = new List<Transaction_Group__c>();

            //create transaction groups for all the billings
            for(Billing__c bill : billingsToCheckStatus){
                txnGroups.add(new Transaction_Group__c(
                    Billing__c = bill.Id,
                    Status__c = TransactionGroupActions.STATUS_PROCESSING,
                    Batch_Id__c = bill.Id,
                    Job_Type__c = 'Test Job',
                    Line_Count__c = 0,
                    Lines_Processed__c = 0,
                    Ledger__c = bill.Ledger__c
                ));
            }

            Cash_Receipt__c cReciept = new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 400,
                Status__c = 'Approved',
                Receipt_Date__c = System.today(),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '12345',
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );

            INSERT cReciept;

            txnGroups.add(new Transaction_Group__c(
                Cash_Receipt__c = cReciept.Id,
                Status__c = TransactionGroupActions.STATUS_PROCESSING,
                Batch_Id__c = cReciept.Id,
                Job_Type__c = 'Test Job',
                Line_Count__c = 0,
                Lines_Processed__c = 0,
                Ledger__c = billingsToCheckStatus[0].Ledger__c
            ));

            INSERT txnGroups;

            Assert.areEqual(6, [SELECT Id,Billing__c FROM Transaction_Group__c].size());

            PurgeSourceDocumentsLDVBatch batch = new PurgeSourceDocumentsLDVBatch();
            Database.executeBatch(batch);

            Test.stopTest();

            //create email body to apply asserts
            String emailBody = Label.INF_PURGE_DOCUMENT_STUCK_JOB_IS_COMPLETED_BODY
            + '\n' + Label.COMMON_RECORDS_PROCESSED + ': ' + String.valueOf(txnGroups.size())
            + '\n' + Label.COMMON_RECORDS_SUCCEEDED + ': ' + String.valueOf(txnGroups.size())
            + '\n' + Label.COMMON_RECORDS_FAILED + ': ' + String.valueOf(0);

            List<EmailMessage> sentEmails = [SELECT Id, ToAddress, Subject, HtmlBody,TextBody FROM EmailMessage];
            //make sure the email record is created with the specified details
            Assert.areEqual(1, sentEmails.size());
            Assert.areNotEqual(null,sentEmails[0]);
            Assert.areEqual(UserInfo.getUserEmail(), sentEmails[0].ToAddress);
            Assert.areEqual(Label.INF_PURGE_DOCUMENT_STUCK_JOB_IS_COMPLETED_SUBJECT, sentEmails[0].Subject);
            Assert.areEqual(emailBody, sentEmails[0].TextBody);

            //all the transaction groups should be deleted for the billings
            Assert.areEqual(0, [SELECT Id,Billing__c FROM Transaction_Group__c WHERE Billing__c IN: billingsToCheckStatus].size());

            billingsToCheckStatus = [
                SELECT Id
                FROM Billing__c
                WHERE Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
            ];
            System.assertEquals(true, billingsToCheckStatus.isEmpty());
        }
    }
}