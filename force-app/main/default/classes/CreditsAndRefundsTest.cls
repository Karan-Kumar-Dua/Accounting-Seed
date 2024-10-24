@IsTest
public with sharing class CreditsAndRefundsTest {
    public CreditsAndRefundsTest() {

    }
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    //=========================   CREDITS - Credit Memo Tests   ===========================================
    @IsTest
    private static void testgetCreditMemoFromBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
                BillingModel bm = CreditsAndRefunds.getCreditMemoFromBilling(testData.billings.get(0).Id);
                Billing.create(bm);
            Test.stopTest();

            Billing__c clonedBill = [SELECT Id, Type__c FROM Billing__c WHERE Id = :bm.bill.Id];
            System.assertEquals('Credit Memo', clonedBill.Type__c);
         }
    }


//=========================   REFUNDS - Funding Credit Memo Tests   ===========================================
    @IsTest
    private static void testFundingCreditMemoValidateOptionsFail(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult result = CreditsAndRefunds.createAndApplyFundingCreditMemo(NULL);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_NO_INPUT_DATA);
          
        }
    }

    @IsTest
    private static void testFundingCreditMemoValidateRefundAmount(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.cashReceipts[0].Id);
            credRefundOpts.refundAmount = -1;
            ServiceResult result = CreditsAndRefunds.createAndApplyFundingCreditMemo(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_LESS_THAN_ZERO);
          
        }
    }

    @IsTest
    private static void testFundingCreditMemoValidateOptionsNegativeBalance(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
    
        System.runAs(testData.users.get(1)) {
            Test.startTest();

            TriggerObserver.getInstance().unlockField(Cash_Receipt__c.Amount__c);
        
            CashReceiptPostHandler crph = new CashReceiptPostHandler();
            crph.unpost(new List<Id>{testData.cashReceipts[0].Id});
            testData.cashReceipts[0].Amount__c = -1;
            update testData.cashReceipts[0];

            TriggerObserver.purgeUnlockedFields(Cash_Receipt__c.Amount__c);

            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.cashReceipts[0].Id);
            credRefundOpts.refundAmount = 1000000;
            ServiceResult result = CreditsAndRefunds.createAndApplyFundingCreditMemo(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_NEGATIVE_BALANCE);
          
        }
        
    }

    @IsTest
    private static void testFundingCreditMemoValidateOptionsRefundAmountFail(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.cashReceipts[0].Id);
            credRefundOpts.refundAmount = 1000000;
            ServiceResult result = CreditsAndRefunds.createAndApplyFundingCreditMemo(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_AMOUNT_GREATER_BALANCE);
          
        }
    }

    @IsTest
    private static void testFundingCreditMemoValidateOptionsInvalidDate(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.cashReceipts[0].Id);
            credRefundOpts.refundAmount = 1;
            credRefundOpts.refundDate = Date.newInstance(1900, 01, 01);

            ServiceResult result = CreditsAndRefunds.createAndApplyFundingCreditMemo(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_REFUND_DATE_INVALID);
          
        }
        
    }

    @IsTest
    private static void testFundingCreditMemoSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
                CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.cashReceipts[0].Id);
                credRefundOpts.refundDate = credRefundOpts.sourceRecordDate;
                ServiceResult result = CreditsAndRefunds.createAndApplyFundingCreditMemo(credRefundOpts);
            Test.stopTest();

            System.assertEquals(true, result.isSuccess);
            
            Billing__c creditMemo = [SELECT Id, Type__c, Customer__c, Date__c, Ledger__c 
                                    FROM Billing__c 
                                    WHERE Id = :result.data];
            system.assertNotEquals(NULL, CreditMemo);
            System.assertEquals(creditMemo.Customer__c, credRefundOpts.customer);
            System.assertEquals(creditMemo.Date__c, credRefundOpts.refundDate);
            System.assertEquals(creditMemo.Ledger__c, credRefundOpts.ledger);
           

            Billing_Line__c creditMemoLine = [SELECT Id, Rate__c, Revenue_GL_Account__c 
                                                FROM Billing_Line__c 
                                                WHERE Billing__c = :creditMemo.Id];
            
            System.assertNotEquals(NULL, creditMemoLine);
            System.assertEquals(creditMemoLine.Rate__c, credRefundOpts.refundAmount * -1);
            System.assertEquals(creditMemoLine.Revenue_GL_Account__c, credRefundOpts.creditGLAccount);


            Billing_Cash_Receipt__c BCR = [SELECT Id, Billing__c, Cash_Receipt__c, Applied_Amount__c 
                                            FROM Billing_Cash_Receipt__c 
                                            WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id];
            
            System.assertEquals(BCR.Cash_Receipt__c, testData.cashReceipts[0].Id);
            System.assertEquals(BCR.Billing__c, creditMemo.Id);
            System.assertEquals(BCR.Applied_Amount__c, credRefundOpts.refundAmount);

            List<Transaction__c> Trans = [SELECT Id FROM Transaction__c WHERE Billing__c = :creditMemo.Id];
            System.assertNotEquals(0, Trans.Size());
          
        }
        
    }

    @IsTest
    private static void testFundingCreditMemoSuccess_MC(){

    }

    //=========================   REFUNDS - Refund Cash Rceipt Tests   ===========================================
    @IsTest
    private static void testRefundCashReceiptOptionsFail(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(NULL);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(Label.ERR_NO_INPUT_DATA, result.errors[0].detail);
          
        }
    }

    @IsTest
    private static void testRefundCashReceiptValidateFromBillingInvoice(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.billings[0].Id);
            credRefundOpts.refundAmount = 1;
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_INVALID_TYPE);
          
        }
    }

    @IsTest
    private static void testRefundCashReceiptValidateOptionsRefundAmountFail(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.billings[2].Id);
            credRefundOpts.refundAmount = 1000000;
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_AMOUNT_GREATER_CM_BALANCE);
          
        }
    }

    @IsTest
    private static void testRefundCashReceiptValidateOptionsEmptyBankAccountFail(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.billings[2].Id);
            credRefundOpts.bankAccount = null;
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_REQUIRED_BANK_ACCOUNT);

        }
    }

    @IsTest
    private static void testRefundCashReceiptValidateOptionsNotBankAccountFail(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.billings[2].Id);
            credRefundOpts.bankAccount = testData.glAccounts[2].Id;
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(credRefundOpts);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(result.errors[0].detail, Label.ERR_REFUND_BANK_ACCOUNT_MUST_ENABLED);

        }
    }

    @IsTest
    private static void testRefundCashReceiptSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.billings[2].Id);
            credRefundOpts.refundDate = credRefundOpts.sourceRecordDate;
            credRefundOpts.bankAccount = testData.glAccounts[0].Id;
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(credRefundOpts);
            Test.stopTest();

            System.assertEquals(true, result.isSuccess);

            Billing__c refundCM = [SELECT Id, Balance__c, Received_Amount__c,  Funded_Amount__c FROM Billing__c WHERE Id = :testData.billings[2].Id];
            System.assertEquals(refundCM.Received_Amount__c, credRefundOpts.refundAmount * -1 );
            System.assertEquals(0, refundCM.Balance__c);

            Cash_Receipt__c refundCR = [SELECT Id, Account__c, Amount__c, Receipt_Date__c, Applied_Amount__c, Balance__c, Check_Number__c, Payment_Type__c,
                                        Alternate_Payee_Name__c, Payee_Street__c, Payee_City__c, Payee_State__c, Payee_Postal_Code__c, Payee_Country__c
                                    FROM Cash_Receipt__c 
                                    WHERE Id = :result.data];

            Account customer = [SELECT Alternate_Payee_Name__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                                    FROM Account
                                    WHERE Id = :refundCR.Account__c];

            System.assertNotEquals(NULL, refundCR);
            System.assertEquals(refundCR.Amount__c, credRefundOpts.refundAmount * -1);
            System.assertEquals(refundCR.Receipt_Date__c, credRefundOpts.refundDate);
            System.assertEquals(refundCR.Applied_Amount__c, credRefundOpts.refundAmount * -1);
            System.assertEquals(0, refundCR.Balance__c);
            System.assertNotEquals(NULL, refundCR.Check_Number__c);
            System.assertEquals(CreditsAndRefunds.PAYMENT_TYPE_CHECK, refundCR.Payment_Type__c);
            System.assertEquals(customer.Alternate_Payee_Name__c, refundCR.Alternate_Payee_Name__c);
            System.assertEquals(customer.BillingStreet, refundCR.Payee_Street__c);
            System.assertEquals(customer.BillingCity, refundCR.Payee_City__c);
            System.assertEquals(customer.BillingState, refundCR.Payee_State__c);
            System.assertEquals(customer.BillingPostalCode, refundCR.Payee_Postal_Code__c);
            System.assertEquals(customer.BillingCountry, refundCR.Payee_Country__c);


            Billing_Cash_Receipt__c BCR = [SELECT Id, Billing__c, Billing__r.Id, Cash_Receipt__c, Applied_Amount__c 
                                            FROM Billing_Cash_Receipt__c 
                                            WHERE Billing__c = :testData.billings[2].Id
                                            AND Cash_Receipt__c = :refundCR.Id];
            
            System.assertNotEquals(NULL, BCR);
            System.assertEquals(BCR.Applied_Amount__c, credRefundOpts.refundAmount * -1);

            List<Transaction__c> Trans = [SELECT Id, Amount__c FROM Transaction__c WHERE Cash_Receipt__c = :refundCR.Id];
            System.assertNotEquals(0, Trans.Size());
            for(Transaction__c t : Trans){
                System.assertEquals(math.abs(t.Amount__c), math.abs(credRefundOpts.refundAmount));
            }

           
          
        }
    }

    //=========================   REFUNDS - Refund CR from CR Test  ===========================================
    @IsTest
    private static void testRefundFromCashReceiptSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
                CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.cashReceipts[0].Id);
                credRefundOpts.refundDate = credRefundOpts.sourceRecordDate;
                ServiceResult result = CreditsAndRefunds.createRefundForCashReceipt(credRefundOpts);
            Test.stopTest();

            System.assertEquals(true, result.isSuccess);



            Cash_Receipt__c refundCR = [SELECT Id, Account__c, Amount__c, Receipt_Date__c, Applied_Amount__c, Balance__c, Payment_Type__c,
                                            Alternate_Payee_Name__c, Payee_Street__c, Payee_City__c, Payee_State__c, Payee_Postal_Code__c, Payee_Country__c
                                        FROM Cash_Receipt__c 
                                        WHERE Id = :result.data];

            Account customer = [SELECT Alternate_Payee_Name__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                                        FROM Account
                                        WHERE Id = :refundCR.Account__c];

            System.assertEquals(refundCR.Amount__c, credRefundOpts.refundAmount * -1);
            System.assertEquals(refundCR.Receipt_Date__c, credRefundOpts.refundDate);
            System.assertEquals(refundCR.Applied_Amount__c, credRefundOpts.refundAmount * -1);
            System.assertEquals(0, refundCR.Balance__c);
            System.assertEquals(CreditsAndRefunds.PAYMENT_TYPE_CHECK, refundCR.Payment_Type__c);
            System.assertEquals(customer.Alternate_Payee_Name__c, refundCR.Alternate_Payee_Name__c);
            System.assertEquals(customer.BillingStreet, refundCR.Payee_Street__c);
            System.assertEquals(customer.BillingCity, refundCR.Payee_City__c);
            System.assertEquals(customer.BillingState, refundCR.Payee_State__c);
            System.assertEquals(customer.BillingPostalCode, refundCR.Payee_Postal_Code__c);
            System.assertEquals(customer.BillingCountry, refundCR.Payee_Country__c);

            Billing_Cash_Receipt__c BCR = [SELECT Id, Billing__c, Billing__r.Id, Cash_Receipt__c, Applied_Amount__c 
            FROM Billing_Cash_Receipt__c 
            WHERE Cash_Receipt__c = :refundCR.Id];
            System.assertEquals(BCR.Cash_Receipt__c, refundCR.Id);
            System.assertEquals(BCR.Applied_Amount__c, credRefundOpts.refundAmount * -1);


            
            Billing__c fundingCM = [SELECT Id, Type__c, Customer__c, Date__c, Ledger__c, Balance__c, Received_Amount__c
                                    FROM Billing__c 
                                    WHERE Id = :BCR.Billing__c];
            System.assertEquals(fundingCM.Customer__c, credRefundOpts.customer);
            System.assertEquals(fundingCM.Date__c, credRefundOpts.refundDate);
            System.assertEquals(fundingCM.Ledger__c, credRefundOpts.ledger);
            //System.assertEquals(0, fundingCM.Balance__c);
            //System.assertEquals(fundingCM.Received_Amount__c, credRefundOpts.refundAmount * -1);
           

            Billing_Line__c fundingCMLine = [SELECT Id, Rate__c, Revenue_GL_Account__c 
                                                FROM Billing_Line__c 
                                                WHERE Billing__c = :fundingCM.Id];
            System.assertEquals(fundingCMLine.Rate__c , credRefundOpts.refundAmount * -1 );
            System.assertEquals(fundingCMLine.Revenue_GL_Account__c, credRefundOpts.creditGLAccount);


            Billing_Cash_Receipt__c BCR2 = [SELECT Id, Billing__c, Cash_Receipt__c, Applied_Amount__c 
                                            FROM Billing_Cash_Receipt__c 
                                            WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id];
            System.assertEquals(BCR2.Cash_Receipt__c, testData.cashReceipts[0].Id);
            System.assertEquals(BCR2.Billing__c, fundingCM.Id);
            System.assertEquals(BCR2.Applied_Amount__c, credRefundOpts.refundAmount );

           
        }
    }
}