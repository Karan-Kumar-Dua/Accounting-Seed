@IsTest
public with sharing class RefundHelperTest{
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testGetObjectNameOfRecordForCashReceipt(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Cash_Receipt__c testCashReceiptObject = testData.createCashReceipts().cashReceipts[0];
            Id crId = testCashReceiptObject.Id;
            String expectedObjectName = 'AcctSeed__Cash_Receipt__c';
            Test.startTest();
            String actualObjectName = RefundHelper.getObjectNameOfRecord(crId);
            Test.stopTest();
            System.assertEquals(expectedObjectName, actualObjectName, 'Expected and Actual object name is not matching');
        }
    }

    @isTest
    private static void testGetObjectNameOfRecordForCreditMemo(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Billing__c testBillingObject = testData.createBillings().billings[0];
            Id billId = testBillingObject.Id;
            String expectedObjectName = 'AcctSeed__Billing__c';
            Test.startTest();
            String actualObjectName = RefundHelper.getObjectNameOfRecord(billId);
            Test.stopTest();
            System.assertEquals(expectedObjectName, actualObjectName, 'Expected and Actual object name is not matching');
        }
    }

    @isTest
    private static void testGetObjectNameOfRecordForException(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Boolean exceptionOccurred = false;
            Test.startTest();
            String actualObjectName = null;
            String wrongId = 'ABCD1234';
            try{
                actualObjectName = RefundHelper.getObjectNameOfRecord(wrongId);
            } catch (Exception ex){
                exceptionOccurred = true;
            }
            Test.stopTest();
            System.assertEquals(null, actualObjectName, 'An Exception was not thrown assert 1');
            System.assert(exceptionOccurred, 'An Exception was not thrown assert 2');
        }
    }

    @isTest
    private static void testCreateRefundForCashReceiptWithError(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Cash_Receipt__c testCashReceiptObject = testData.createCashReceipts().cashReceipts[0];
            Id crId = testCashReceiptObject.Id;

            String paramValues = '{"refundAmountInput":"200","refundDateInput":"2022-3-14","bankAccount":"a0i0R000002gHYUQA2","paymentTypeCombobox":"Check","referenceTextArea":"CR-00000 refund","memoTextArea":"undefined"}';
            String objectName = 'AcctSeed__Cash_Receipt__c';
            Test.startTest();
            AbstractLWCHelper.SaveResponse res = RefundHelper.createRefund(paramValues, objectName, crId, new Map<String, Object>());
            Test.stopTest();
            System.assert(Label.ERR_MISSING_VALUE.contains(res.errors[0].detail));
        }
    }

    @isTest
    private static void testCreateRefundForCreditMemoWithError(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Billing__c testBillingObject = testData.createBillings().billings[0];
            Id billId = testBillingObject.Id;

            String paramValues = '{"refundAmountInput":"50","refundDateInput":"2022-3-15","bankAccount":"a0i0R000002gHYUQA2","paymentTypeCombobox":"Check","referenceTextArea":"00000001 refund","memoTextArea":"undefined"}';
            String objectName = 'AcctSeed__Billing__c';
            Test.startTest();
            AbstractLWCHelper.SaveResponse res = RefundHelper.createRefund(paramValues, objectName, billId, new Map<String, Object>());
            Test.stopTest();

            System.assertEquals(Label.ERR_REFUND_INVALID_TYPE, res.errors[0].detail);
        }
    }

    @isTest
    private static void testCreateRefundForException(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Boolean exceptionOccurred = false;
            String paramValues = '{""}';
            String objectName = 'AcctSeed__Cash_Receipt__c';
            Test.startTest();
            RefundHelper.RefundData refundDataObject = null;
            AbstractLWCHelper.SaveResponse res;
            try{
                res = RefundHelper.createRefund(paramValues, objectName, null, new Map<String, Object>());
            } catch (Exception ex){
                exceptionOccurred = true;
            }
            Test.stopTest();
            System.assertEquals(null, refundDataObject, 'An Exception was not thrown assert 1');
            System.assert(exceptionOccurred, 'An Exception was not thrown assert 2');
        }
    }

    @isTest
    private static void testCreateRefundForCashReceipt(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        System.runAs(testData.users.get(1)){
            Test.startTest();
            RefundHelper.RefundData refundData = new RefundHelper.RefundData();
            refundData.refundAmountInput = 24.99;
            refundData.refundDateInput = testData.cashReceipts[0].Receipt_Date__c;
            refundData.bankAccount = testData.glAccounts[0].Id;
            refundData.paymentTypeCombobox = 'Check';
            refundData.referenceTextArea = 'Ref test';
            refundData.memoTextArea = 'Test refund check';

            String paramValues = JSON.serialize(refundData);
            String objectName = 'AcctSeed__Cash_Receipt__c';
            Id recordId = testData.cashReceipts[0].Id;

            Integer checkNumber = 134576756;
            AbstractLWCHelper.SaveResponse res = RefundHelper.createRefund(paramValues, objectName, recordId, new Map<String, Object>{'AcctSeed__Check_Number__c' => checkNumber});
            Test.stopTest();

            // response contians expected data
            System.assertNotEquals(null, res);
            System.assert(res.errors.isEmpty());
            System.assert(res.isSuccess);
            System.assert(res.result != null && !res.result.isEmpty());
        
            // validate BCR
            Id refundId = res.result[0].Id;
            List<Billing_Cash_Receipt__c> bcr = [
                SELECT Applied_Amount__c, Applied_Date__c, Cash_Receipt__r.Check_Number__c
                FROM Billing_Cash_Receipt__c
                WHERE Cash_Receipt__c = :refundId
            ];
            System.assert(bcr != null && bcr.size() == 1);
            System.assertEquals(refundData.refundAmountInput * -1, bcr[0].Applied_Amount__c);
            System.assertEquals(refundData.refundDateInput, bcr[0].Applied_Date__c);
            System.assertEquals(checkNumber, bcr[0].Cash_Receipt__r.Check_Number__c);
        }
    }

    @isTest
    private static void testCreateRefundForCreditMemo(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        System.runAs(testData.users.get(1)){
            Test.startTest();
            RefundHelper.RefundData refundData = new RefundHelper.RefundData();
            refundData.refundAmountInput = 15.00;
            refundData.refundDateInput = testData.billings[3].Date__c;
            refundData.bankAccount = testData.glAccounts[0].Id;
            refundData.paymentTypeCombobox = 'Check';
            refundData.referenceTextArea = 'Ref test';
            refundData.memoTextArea = 'Test refund check';

            String paramValues = JSON.serialize(refundData);
            String objectName = 'AcctSeed__Billing__c';
            Id recordId = testData.billings[3].Id;
            
            AbstractLWCHelper.SaveResponse res = RefundHelper.createRefund(paramValues, objectName, recordId, new Map<String, Object>());
            Test.stopTest();

            // response contians expected data
            System.assertNotEquals(null, res);
            System.assert(res.errors.isEmpty(), res.errors);
            System.assert(res.isSuccess);
            System.assert(res.result != null && !res.result.isEmpty());
        
            // validate BCR
            Id refundId = res.result[0].Id;
            List<Billing_Cash_Receipt__c> bcr = [
                SELECT Applied_Amount__c, Applied_Date__c
                FROM Billing_Cash_Receipt__c
                WHERE Cash_Receipt__c = :refundId
            ];
            System.assert(bcr != null && bcr.size() == 1);
            System.assertEquals(refundData.refundAmountInput * -1, bcr[0].Applied_Amount__c);
            System.assertEquals(refundData.refundDateInput, bcr[0].Applied_Date__c);
        }
    }
}