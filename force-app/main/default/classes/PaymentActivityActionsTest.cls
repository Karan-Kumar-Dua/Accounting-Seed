@IsTest
public with sharing class PaymentActivityActionsTest {

    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testRounding() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Method__c payemntMethod = new Payment_Method__c(
                Customer__c = testData.accounts[0].Id, 
                External_Id__c = 'abc123def456',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card', 
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '5000',
                Type__c = 'Visa',
                Payment_Processor__c = testData.paymentProcessors[0].Id
            );
            insert payemntMethod;

            Payment_Activity__c activity = new Payment_Activity__c(
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Status__c = PaymentActivityHelper.ERROR_STATUS,
                Amount__c = 101.01,
                Fee__c = 1.0241895,
                Payment_Method__c = payemntMethod.Id
            );
            insert activity;

            Map<String,Integer> fieldRounding = new Map<String,Integer>();
            for (SObjectField f : PaymentActivityActions.currencyAndNumberFields.keySet()) {
                fieldRounding.put(f.getDescribe().getName(), PaymentActivityActions.currencyAndNumberFields.get(f));
            }
            
            String activityId = activity.Id;
            String q = 'SELECT Payment_Date__c,' + String.join(new List<String>(fieldRounding.keySet()), ', ') + ' FROM Payment_Activity__c WHERE Id = :activityId';
            
            for (Payment_Activity__c result : (List<Payment_Activity__c>) Database.query(q)) {
                Assert.areEqual(result.Payment_Date__c.hour(), System.now().hour());
                Assert.areEqual(result.Payment_Date__c.minute(), System.now().minute());
                for (String k : fieldRounding.keySet()) {
                    Assert.areEqual(((Decimal)activity.get(k)).setScale(fieldRounding.get(k), System.RoundingMode.HALF_UP) , result.get(k));
                }
            }

            activity.Fee__c = 1.02912945;
            update activity;

            for (Payment_Activity__c result : (List<Payment_Activity__c>) Database.query(q)) {
                for (String k : fieldRounding.keySet()) {
                    Assert.areEqual(((Decimal)activity.get(k)).setScale(fieldRounding.get(k), System.RoundingMode.HALF_UP) , result.get(k));
                }
            }
        }
    }

}