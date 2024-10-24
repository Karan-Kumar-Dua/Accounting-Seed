@IsTest
public class BankReconciliationActionsTest {
    
    private static final String WORKING = BankReconciliation.WORKING;
    private static final String COMPLETED = BankReconciliation.COMPLETED;
    private static final String IN_PROGRESS = BankReconciliation.IN_PROGRESS;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBankReconciliationModifyLockedFieldsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BankReconciliationFieldUpdateValidator();
            DMLException dmlEx;
            try {
                testData.bankReconciliations[0].Bank_Account__c = testData.glAccounts[29].Id;
                update testData.bankReconciliations[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testBankReconciliationModifyLockedPostedFieldsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BankReconciliationFieldUpdateValidator();
            DMLException dmlEx;
            Bank_Reconciliation2__c brec = [SELECT 
                                                    Id, 
                                                    Uncleared_Amount__c                                           
                                                FROM 
                                                    Bank_Reconciliation2__c 
                                                WHERE 
                                                    Id = :testData.bankReconciliations[0].Id 
                                                LIMIT 1];

            if (brec.Uncleared_Amount__c > 0) {
            brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
            brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }            
            //change this once the real logic is in place to calculate the GL Balance
            brec.GL_Ending_Balance__c = 29950;                                             
            update brec;

            BankReconciliation.complete(brec.Id);
            Test.getEventBus().deliver();
            Test.stopTest();
            
            try {
                brec.UnCleared_Deposits__c = 10050.99;
                update brec;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            String expectedMessage = String.format(
                SourceDocumentUpdateFieldValidator.ALTERNATE_POSTED_UPDATE_ERROR, 
                new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), BankReconciliation.COMPLETED}
            );
            System.assertEquals(expectedMessage, dmlEx.getDmlMessage(0));
        }

    }
 
    @IsTest
    public static void testBankReconciliationSetDefaultFieldValuesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c br = testData.bankReconciliations[0].clone(false, true);
            br.Cleared_Deposits__c = 4576;
            br.Cleared_Disbursements__c = 23456;
            br.End_Date__c = testData.acctPeriods[6].Start_Date__c+30;
            insert br;
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            System.assertEquals(0, [SELECT Id, Cleared_Deposits__c FROM Bank_Reconciliation2__c WHERE Id = :br.Id].Cleared_Deposits__c);
            System.assertEquals(0, [SELECT Id, Cleared_Disbursements__c FROM Bank_Reconciliation2__c WHERE Id = :br.Id].Cleared_Disbursements__c);
            System.assertEquals(IN_PROGRESS, [SELECT Id, Status__c FROM Bank_Reconciliation2__c WHERE Id = :br.Id].Status__c);
        }

    }

    @IsTest
    public static void testBankReconciliationNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            Bank_Reconciliation2__c br = new Bank_Reconciliation2__c();
            try {
                insert br;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testBankReconciliationNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users[1]) {
                DMLException dmlEx;
                Bank_Reconciliation2__c br = new Bank_Reconciliation2__c();
                try {
                    insert br;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    private static void testBankReconciliationUpdateDifferenceFail() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try{
                Test.startTest();
                testData.bankReconciliations[0].Cleared_Deposits__c = 50.00;
                testData.bankReconciliations[0].Status__c = COMPLETED;
                update testData.bankReconciliations[0];
                Test.stopTest();
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(BankReconciliationActions.STATUS_CHANGE_DIFFERENCE_NOT_ZERO_ERROR, dmlEx.getDmlMessage(0));                       
        }
    }

    @IsTest
    private static void testBankReconciliationUpdateStatusCompleted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }            
                                       
            update brec;
            BankReconciliation.complete(brec.Id);

            System.assertEquals(
                WORKING, [
                    SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[0].Id
                ].Status__c
            );
            Test.getEventBus().deliver();
            Test.stopTest();
            List<EventBusSubscriber> brEvents = [
                SELECT
                    Name, Position, Retries, LastError
                FROM
                    EventBusSubscriber
                WHERE Topic = 'AcctSeed__AS_Commit_Event__e'
                AND Type = 'ApexTrigger'
            ];
            System.assertEquals(1, brEvents.size());
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[0].Id].Status__c);
        }
    }

    @IsTest
    private static void testBankReconciliationUpdateStatusInProgress() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec = [
                SELECT 
                    Id,
                    Uncleared_Amount__c,
                    Cleared_Disbursements__c,
                    Cleared_Deposits__c,
                    Status__c
                FROM Bank_Reconciliation2__c 
                WHERE Id = :testData.bankReconciliations[0].Id 
                LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }

            System.assertEquals(IN_PROGRESS, brec.Status__c);
            update brec;
            BankReconciliation.complete(brec.Id);
            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Status__c);
            Test.getEventBus().deliver();
            Test.stopTest();

            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Status__c);
            BankReconciliation.undoComplete(brec.Id);
            
            Bank_Reconciliation2__c actual = [
                SELECT 
                    UnCleared_Deposits__c
                  , UnCleared_Payments__c
                  , GL_Ending_Balance__c
                  , Status__c
                  , Error__c
                FROM Bank_Reconciliation2__c 
                WHERE Id = :brec.Id
            ];
            System.assertEquals(null, actual.Error__c);
            System.assertEquals(IN_PROGRESS, actual.Status__c);
            System.assertEquals(0, actual.UnCleared_Deposits__c);
            System.assertEquals(0, actual.UnCleared_Payments__c);
            System.assertEquals(0, actual.GL_Ending_Balance__c);
        }
    }

    @IsTest
    private static void testBankReconciliationLegacyBRStatusChangeException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[7].Id
                LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            //change this once the real logic is in place to calculate the GL Balance
            brec.GL_Ending_Balance__c = 29950; 
            brec.Status__c = COMPLETED;                        
            DMLException dmlEx;
            try {
                update brec;            
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.LEGACY_BR_STATUS_CHANGED, dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    private static void testBankReconciliationCreatePreviousDifferentType() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[2].Id
                LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            //change this once the real logic is in place to calculate the GL Balance
            brec.GL_Ending_Balance__c = 29950;                         
            update brec;

            BankReconciliation.complete(brec.Id);

            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[2].Id].Status__c);
            Test.getEventBus().deliver();
            Test.stopTest();
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[2].Id].Status__c);
            
            Bank_Reconciliation2__c brecNext = new Bank_Reconciliation2__c(
                End_Date__c = testData.acctPeriods[6].Start_Date__c + 30,
                Bank_Account__c = testData.glAccounts[29].Id,
                Beginning_Balance__c = 1000,
                Ending_Balance__c = 20000,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Status__c = IN_PROGRESS,
                Type__c = BankReconciliation.CREDIT_CARD_TYPE
            );
            BankReconciliationActions.bypassDefaultStatusWorking = true;
            insert brecNext;
            System.assertEquals(BankReconciliation.BANK_TYPE, [SELECT Type__c FROM Bank_Reconciliation2__c WHERE Id = :brecNext.Id].Type__c);
        }
    }

    @IsTest
    private static void testBankReconciliationCreateSubsequentRecCompletedException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[2].Id
                LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            //change this once the real logic is in place to calculate the GL Balance
            brec.GL_Ending_Balance__c = 29950;                      
            update brec;

            BankReconciliation.complete(brec.Id);

            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[2].Id].Status__c);
            Test.getEventBus().deliver();
            Test.stopTest();
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[2].Id].Status__c);
            
            DMLException dmlEx;
            try {
                Bank_Reconciliation2__c brecPrevious = new Bank_Reconciliation2__c(
                    End_Date__c = testData.acctPeriods[0].Start_Date__c+30,
                    Bank_Account__c = testData.glAccounts[29].Id,
                    Beginning_Balance__c = 1000,
                    Ending_Balance__c = 20000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Status__c = IN_PROGRESS,
                    Type__c = BankReconciliation.BANK_TYPE
                );
                BankReconciliationActions.bypassDefaultStatusWorking = true;
                insert brecPrevious;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.CREATE_BREC_SUBSEQUENT_COMPLETED_ERROR, dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    private static void testBankReconciliationCreateDuplicateBRECException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DMLException dmlEx;
            try {
                Bank_Reconciliation2__c brecDuplicate = new Bank_Reconciliation2__c(
                    End_Date__c = testData.bankReconciliations[2].End_Date__c,
                    Bank_Account__c = testData.bankReconciliations[2].Bank_Account__c,
                    Beginning_Balance__c = 1000,
                    Ending_Balance__c = 20000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Status__c = IN_PROGRESS,
                    Type__c = testData.bankReconciliations[2].Type__c
                );
                insert brecDuplicate;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.CREATE_BREC_EXISTING_BREC_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeCompletedPreviousInProgressException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :testData.bankReconciliations[3].Id LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            //change this once the real logic is in place to calculate the GL Balance
            brec.GL_Ending_Balance__c = 29950; 
            brec.Status__c = COMPLETED;                        
            
            DMLException dmlEx;
            try {
                update brec;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.STATUS_CHANGE_COMPLETED_PREVIOUS_IN_PROGRESS_ERROR, dmlEx.getDmlMessage(0));            
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeCompletedPreviousWorkingException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Bank_Reconciliation2__c brecPrev = [SELECT
                                                    Id,
                                                    Uncleared_Amount__c
                                                FROM
                                                    Bank_Reconciliation2__c
                                                WHERE
                                                    Id = :testData.bankReconciliations[2].Id
                                                LIMIT 1];
            if (brecPrev.Uncleared_Amount__c > 0) {
                brecPrev.Cleared_Deposits__c = brecPrev.Uncleared_Amount__c;
            } else if (brecPrev.Uncleared_Amount__c < 0) {
                brecPrev.Cleared_Disbursements__c = brecPrev.Uncleared_Amount__c;
            }
            //change this once the real logic is in place to calculate the GL Balance
            brecPrev.GL_Ending_Balance__c = 29950; 
            update brecPrev;
            BankReconciliation.complete(brecPrev.Id);
            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[2].Id].Status__c);

            Test.startTest();
            Bank_Reconciliation2__c brec = [SELECT 
                                                Id, 
                                                Uncleared_Amount__c                                                
                                            FROM 
                                                Bank_Reconciliation2__c 
                                            WHERE 
                                                Id = :testData.bankReconciliations[3].Id 
                                            LIMIT 1];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            //change this once the real logic is in place to calculate the GL Balance
            brec.GL_Ending_Balance__c = 29950; 
            brec.Status__c = COMPLETED;                        
            
            DMLException dmlEx;
            try {
                update brec;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.STATUS_CHANGE_COMPLETED_PREVIOUS_WORKING_ERROR, dmlEx.getDmlMessage(0));            
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeInProgressSubsequentCompletedException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec1 = [
                SELECT Id, Uncleared_Amount__c                                                
                FROM Bank_Reconciliation2__c 
                WHERE Id = :testData.bankReconciliations[2].Id
            ];
            if (brec1.Uncleared_Amount__c > 0) {
                brec1.Cleared_Deposits__c = brec1.Uncleared_Amount__c;
            } else if (brec1.Uncleared_Amount__c < 0) {
                brec1.Cleared_Disbursements__c = brec1.Uncleared_Amount__c;
            }

            BankReconciliationActions.bypassDefaultStatusWorking = true;                      
            update brec1;    
            BankReconciliation.complete(brec1.Id);        

            EventBusTestUtils.deliverAllEvents();
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Status__c);

            BankReconciliationActions.bypassDefaultStatusWorking = false;                      
            Bank_Reconciliation2__c brec2 = [
                SELECT Id, Uncleared_Amount__c                                                
                FROM Bank_Reconciliation2__c 
                WHERE Id = :testData.bankReconciliations[3].Id
            ];
            if (brec2.Uncleared_Amount__c > 0) {
                brec2.Cleared_Deposits__c = brec2.Uncleared_Amount__c;
            } else if (brec2.Uncleared_Amount__c < 0) {
                brec2.Cleared_Disbursements__c = brec2.Uncleared_Amount__c;
            }
                     
            update brec2;
            BankReconciliation.complete(brec2.Id); 

            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec2.Id].Status__c);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec2.Id].Status__c);

            DMLException dmlEx;
            try {
                brec1.Status__c = IN_PROGRESS;
                update brec1;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.STATUS_CHANGE_IN_PROGRESS_SUBSEQUENT_COMPLETED_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeMultipleRecordsException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Bank_Reconciliation2__c> brecs = [SELECT 
                                                Id, 
                                                Uncleared_Amount__c                                                
                                            FROM 
                                                Bank_Reconciliation2__c 
                                            WHERE 
                                                Id = :testData.bankReconciliations[2].Id OR Id = :testData.bankReconciliations[3].Id];
            for (Bank_Reconciliation2__c brec : brecs) {
                if (brec.Uncleared_Amount__c > 0) {
                    brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
                } else if (brec.Uncleared_Amount__c < 0) {
                    brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
                }
                //change this once the real logic is in place to calculate the GL Balance
                brec.GL_Ending_Balance__c = 29950; 
                brec.Override_Beginning_Balance__c = true;
                brec.Status__c = COMPLETED;                        
            }                                                
            
            DMLException dmlEx;
            try {
                update brecs;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.TOO_MANY_STATUS_CHANGES_ERROR, dmlEx.getDmlMessage(0));        
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeUpdateSubsequentBeginningBalance() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Double subsequentBankRecBeginningBalance = [SELECT Beginning_Balance__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[3].Id].Beginning_Balance__c;        
            Bank_Reconciliation2__c brec1 = [SELECT 
                                                Id, 
                                                Uncleared_Amount__c                                                
                                            FROM 
                                                Bank_Reconciliation2__c 
                                            WHERE 
                                                Id = :testData.bankReconciliations[2].Id 
                                            LIMIT 1];
            
            if (brec1.Uncleared_Amount__c > 0) {
                brec1.Cleared_Deposits__c = brec1.Uncleared_Amount__c;
            } else if (brec1.Uncleared_Amount__c < 0) {
                brec1.Cleared_Disbursements__c = brec1.Uncleared_Amount__c;
            }                 
            brec1.GL_Ending_Balance__c = 29950;
            update brec1;
            BankReconciliation.complete(brec1.Id);
            Test.getEventBus().deliver();            
            Test.stopTest();  
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Status__c);         
            Double subsequentBankRecBeginningBalanceAfterUpdate = [SELECT Beginning_Balance__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[3].Id].Beginning_Balance__c;
            System.assertNotEquals(subsequentBankRecBeginningBalance, subsequentBankRecBeginningBalanceAfterUpdate);
            System.assertEquals(subsequentBankRecBeginningBalanceAfterUpdate, [SELECT Ending_Balance__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[2].Id].Ending_Balance__c);
            
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeNotUpdateSubsequentBeginningBalance() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.bankReconciliations[3].Override_Beginning_Balance__c = true;
            update testData.bankReconciliations[3];

            Double subsequentBankRecBeginningBalance = [
                SELECT Beginning_Balance__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :testData.bankReconciliations[3].Id
            ].Beginning_Balance__c;

            Bank_Reconciliation2__c brec1 = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[2].Id
                LIMIT 1
            ];
            
            if (brec1.Uncleared_Amount__c > 0) {
                brec1.Cleared_Deposits__c = brec1.Uncleared_Amount__c;
            } else if (brec1.Uncleared_Amount__c < 0) {
                brec1.Cleared_Disbursements__c = brec1.Uncleared_Amount__c;
            }                    
            brec1.GL_Ending_Balance__c = 29950;
            update brec1;
            BankReconciliation.complete(brec1.Id);
            Test.getEventBus().deliver();            
            Test.stopTest();   
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Status__c);        
            Double subsequentBankRecBeginningBalanceAfterUpdate = [
                SELECT Beginning_Balance__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :testData.bankReconciliations[3].Id
            ].Beginning_Balance__c;
            System.assertEquals(subsequentBankRecBeginningBalance, subsequentBankRecBeginningBalanceAfterUpdate);
            System.assertNotEquals(
                subsequentBankRecBeginningBalanceAfterUpdate, [
                    SELECT Ending_Balance__c
                    FROM Bank_Reconciliation2__c
                    WHERE Id = :testData.bankReconciliations[2].Id
                ].Ending_Balance__c
            );
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeInProgressDifferenceException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec1 = [SELECT 
                                                Id, 
                                                Uncleared_Amount__c                                                
                                            FROM 
                                                Bank_Reconciliation2__c 
                                            WHERE 
                                                Id = :testData.bankReconciliations[2].Id 
                                            LIMIT 1];
            if (brec1.Uncleared_Amount__c > 0) {
                brec1.Cleared_Deposits__c = brec1.Uncleared_Amount__c;
            } else if (brec1.Uncleared_Amount__c < 0) {
                brec1.Cleared_Disbursements__c = brec1.Uncleared_Amount__c;
            }
            update brec1;  
            BankReconciliation.complete(brec1.Id);
            Test.getEventBus().deliver();
            Test.stopTest();
            System.assertEquals(COMPLETED, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Status__c);

            brec1.Cleared_Deposits__c = 0;
            brec1.Cleared_Disbursements__c = 0;
            brec1.Status__c = IN_PROGRESS;                       

            DMLException dmlEx;
            try {
                update brec1;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.STATUS_CHANGE_IN_PROGRESS_ERROR , dmlEx.getDmlMessage(0)); 
        }
    }

    @IsTest
    private static void testBankReconciliationStatusChangeInProgressWithErrorClearValue() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec1 = [SELECT 
                                                Id, 
                                                Uncleared_Amount__c                                                
                                            FROM 
                                                Bank_Reconciliation2__c 
                                            WHERE 
                                                Id = :testData.bankReconciliations[2].Id 
                                            LIMIT 1];

            if (brec1.Uncleared_Amount__c > 0) {
                brec1.Cleared_Deposits__c = brec1.Uncleared_Amount__c;
            } else if (brec1.Uncleared_Amount__c < 0) {
                brec1.Cleared_Disbursements__c = brec1.Uncleared_Amount__c;
            }
            brec1.Error__c = 'Error';
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.Error__c});
            update brec1;
            BankReconciliation.setStatus(brec1.Id, BankReconciliation.Status.WORKING);              
            Test.getEventBus().deliver();
            System.assertEquals('Error', [SELECT Error__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Error__c);
            
            BankReconciliation.setStatus(brec1.Id, BankReconciliation.Status.IN_PROGRESS);
            Test.stopTest();
            System.assertEquals(NULL, [SELECT Error__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Error__c);            
        }
    }

    @IsTest
    private static void testBankReconciliationPreventStatusChangeCompletedWithErrorException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c brec1 = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[2].Id
                LIMIT 1
            ];

            if (brec1.Uncleared_Amount__c > 0) {
                brec1.Cleared_Deposits__c = brec1.Uncleared_Amount__c;
            } else if (brec1.Uncleared_Amount__c < 0) {
                brec1.Cleared_Disbursements__c = brec1.Uncleared_Amount__c;
            }
            brec1.Error__c = 'Error';
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.Error__c});
            update brec1;  
            TriggerObserver.reset();
            BankReconciliation.setStatus(brec1.Id, BankReconciliation.Status.WORKING); 
            Test.getEventBus().deliver();
            System.assertEquals('Error', [SELECT Error__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Error__c);
            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec1.Id].Status__c);                 
            
            ServiceResult result = BankReconciliation.setStatus(brec1.Id, BankReconciliation.Status.COMPLETED);
            System.assert(!result.isSuccess);
            System.assert(!result.errors.isEmpty());
            System.assertEquals(BankReconciliationActions.STATUS_CHANGE_COMPLETED_WITH_EXCEPTION_ERROR, result.errors[0].detail);
        }
    }

    @IsTest
    static void testCreateBRECTooManyRelatedRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BankReconciliationActions.RECORD_COUNT_LIMIT = 3;
            
            DmlException dmlEx;
            try {
                insert new Bank_Reconciliation2__c(
                    End_Date__c = System.today().addDays(30),
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                );
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            //this check has been removed from the trigger logic, so this test will change to confirm that there is no error when there are too many records
            Integer recordCount = testData.CashDisbursements.size() + testData.CashReceipts.size() + testData.BankDeposits.size() + testData.journalEntryLines.size();
            System.assertEquals(
                null,
                dmlEx
            );
        }
    }

    @IsTest
    private static void testBankReconciliationCreate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();
            

        System.runAs(testData.users[1]) {
            
            testData.cashDisbursements[6].Cleared_Date__c = System.today().addDays(5); 
            //setting CD #7 to later than the end date of the brec so that it won't be included
            testData.cashDisbursements[7].Cleared_Date__c = System.today().addDays(75);               

            List<Cash_Disbursement__C> cds = new List<Cash_Disbursement__c> {testData.cashDisbursements[6], testData.cashDisbursements[7]};

            update cds;
            
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(cds);
            System.assertEquals(true, postResults[0].isSuccess);
            

            Test.startTest();            
            Bank_Reconciliation2__c brec = new Bank_Reconciliation2__c(
                End_Date__c = System.today().addDays(30),
                Bank_Account__c = testData.glAccounts[0].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 19790,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE,
                Override_Beginning_Balance__c = true
            );
            insert brec;

            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Status__c);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();            
            System.assertEquals(IN_PROGRESS, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Status__c);
            System.assertEquals(brec.Id, [SELECT Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[6].Id].Bank_Reconciliation__c);
            System.assertEquals(NULL, [SELECT Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[7].Id].Bank_Reconciliation__c);
            System.assertEquals(210.00, [SELECT Cleared_Disbursements__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Cleared_Disbursements__c);            
            System.assertEquals(0.00, [SELECT Cleared_Deposits__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Cleared_Deposits__c);
            System.assertEquals(0, [SELECT Uncleared_Amount__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Uncleared_Amount__c);
            System.assertEquals(BankReconciliation.BANK_TYPE, [SELECT Type__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Type__c);

        }
    }

    @IsTest
    private static void testBankReconciliationCreateWhileJobRunningException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();
            

        System.runAs(testData.users[1]) {
            
            testData.cashDisbursements[6].Cleared_Date__c = System.today().addDays(5);               
            update testData.cashDisbursements[6];
            
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c> {testData.cashDisbursements[6]});
            System.assertEquals(true, postResults[0].isSuccess);
            

            Test.startTest();            
            Bank_Reconciliation2__c brec = new Bank_Reconciliation2__c(
                End_Date__c = System.today().addDays(30),
                Bank_Account__c = testData.glAccounts[0].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 19790,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert brec;

            System.assertEquals(WORKING, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Status__c);
            DMLException dmlEx;
            try {
                Bank_Reconciliation2__c brec2 = new Bank_Reconciliation2__c(
                    End_Date__c = System.today().addDays(31),
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 19790,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                );
                insert brec2;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankReconciliationActions.CREATE_BREC_WHILE_JOB_RUNNING_ERROR, dmlEx.getDmlMessage(0)); 

        }
    }

    @IsTest
    private static void testVerifyUnclearedBankRecLinesCreatedWhenBRECCompletedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits();
        Test.startTest();
        testData.createProjects()
            .createProjectTasks()
            .createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            update brec;            
            
            BankReconciliation.complete(brec.Id);

            System.assertEquals(
                WORKING, [
                    SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[0].Id
                ].Status__c
            );
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();
            BankReconciliationModel model = BankReconciliation.retrieve(brec.Id, false, true);
            System.assertEquals(model.recordCount, [SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c].size());
        }
    }

    @IsTest
    private static void testBankReconciliationOpeningBalancePopulatedOverrideFalse() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c br = testData.bankReconciliations[0].clone(false, true);
            br.End_Date__c = br.End_Date__c + 1;
            br.Override_Beginning_Balance__c = false;
            br.Beginning_Balance__c = null;
            insert br;
            Test.stopTest();
            Bank_Reconciliation2__c expected = [SELECT Id, Ending_Balance__c FROM Bank_Reconciliation2__c WHERE Id =: testData.bankReconciliations[0].Id];
            System.assertEquals(expected.Ending_Balance__c, [SELECT Id, Beginning_Balance__c FROM Bank_Reconciliation2__c WHERE Id =: br.Id].Beginning_Balance__c);
        }
    }

    @IsTest
    static void testVerifyUnclearedBankRecLinesDeletedWhenBRECInProgressSuccess() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];
            
            //create some Uncleared Bank Reconciliation Lines to be deleted below
			ServiceResult sr = BankReconciliation.createUnclearedBankReconciliationLines(brec.Id);
            System.assertNotEquals(0, [SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c].size());
            
            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }            
            update brec;  
            
            Test.stopTest();
            BankReconciliationActions.bypassDefaultStatusWorking = true;
            BankReconciliation.complete(brec.Id);
            BankReconciliationActions.bypassDefaultStatusWorking = false;
            
            BankReconciliation.undoComplete(brec.Id);
            EventBusTestUtils.deliverAllEvents();
            System.assertEquals(0, [SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c].size());
        }
    }

    @IsTest
    private static void testBankRePopulatedOverrideTrue() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c br = testData.bankReconciliations[0].clone(false, true);
            br.End_Date__c = br.End_Date__c + 1;
            br.Override_Beginning_Balance__c = true;
            br.Beginning_Balance__c = null;
            try {
                insert br;
            } catch (DmlException e) {
                System.assert(e.getDmlMessage(0).contains(BankReconciliationActions.BEGINNING_BALANCE_REQUIRED));
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void testValidateTypeRequiredForModernBR() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Reconciliation2__c br = testData.bankReconciliations[0].clone(false, true);
            br.End_Date__c = br.End_Date__c + 1;
            br.Type__c = null;
            try {
                insert br;
            } catch (DmlException e) {
                System.assert(e.getDmlMessage(0).contains(BankReconciliationActions.TYPE_FIELD_REQUIRED_FOR_MODERN_BR));
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void testClearJobCanRun() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            System.assertEquals(false, AccountingSettingsHandler.isAutoClearJobDisabled());
        }
    }

}