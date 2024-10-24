@IsTest
public with sharing class PaymentActivityUpdateUseCaseTest {
    
    private static final String PENDING = PaymentActivityHelper.PENDING_STATUS;
    private static final String SUCCESS = PaymentActivityHelper.SUCCESS_STATUS;
    private static final String ERROR = PaymentActivityHelper.ERROR_STATUS;
    private static final String VOIDED = PaymentActivityHelper.VOID_STATUS;
    private static final String DECLINED = PaymentActivityHelper.DECLINED_STATUS;

    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testIsVoidRequired() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            Payment_Activity__c oldActivity = new Payment_Activity__c();
            Payment_Activity__c newActivity = new Payment_Activity__c();

            Boolean isVoidRequired;

            // Pending -> Void (No CR)
            oldActivity.Status__c = PENDING;
            newActivity.Status__c = VOIDED;
            isVoidRequired = PaymentActivityUpdateUseCase.isVoidRequired(newActivity, oldActivity);
            Assert.isFalse(isVoidRequired);

            oldActivity.Cash_Receipt__c = FinancialSuiteUtils.getFakeId(Cash_Receipt__c.SObjectType);
            newActivity.Cash_Receipt__c = oldActivity.Cash_Receipt__c;

            // Pending -> Success
            oldActivity.Status__c = PENDING;
            newActivity.Status__c = SUCCESS;
            isVoidRequired = PaymentActivityUpdateUseCase.isVoidRequired(newActivity, oldActivity);
            Assert.isFalse(isVoidRequired);

            // Pending -> Pending
            oldActivity.Status__c = PENDING;
            newActivity.Status__c = PENDING;
            isVoidRequired = PaymentActivityUpdateUseCase.isVoidRequired(newActivity, oldActivity);
            Assert.isFalse(isVoidRequired);

            // Pending -> Error
            oldActivity.Status__c = PENDING;
            newActivity.Status__c = ERROR;
            isVoidRequired = PaymentActivityUpdateUseCase.isVoidRequired(newActivity, oldActivity);
            Assert.isTrue(isVoidRequired);

            // Pending -> Void
            oldActivity.Status__c = PENDING;
            newActivity.Status__c = VOIDED;
            isVoidRequired = PaymentActivityUpdateUseCase.isVoidRequired(newActivity, oldActivity);
            Assert.isTrue(isVoidRequired);

            // Success -> Void
            oldActivity.Status__c = SUCCESS;
            newActivity.Status__c = VOIDED;
            isVoidRequired = PaymentActivityUpdateUseCase.isVoidRequired(newActivity, oldActivity);
            Assert.isTrue(isVoidRequired);
        }
    }

    @IsTest
    static void testIsStatusChangeSupported() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            Payment_Activity__c oldActivity = new Payment_Activity__c();

            Payment_Activity__c newActivity = new Payment_Activity__c();

            Boolean isStatusChangeSupported;

            oldActivity.Status__c = PENDING;
            newActivity.Status__c = PENDING;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = PENDING;
            newActivity.Status__c = DECLINED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = PENDING;
            newActivity.Status__c = SUCCESS;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = PENDING;
            newActivity.Status__c = ERROR;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = PENDING;
            newActivity.Status__c = VOIDED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = DECLINED;
            newActivity.Status__c = DECLINED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = SUCCESS;
            newActivity.Status__c = SUCCESS;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = SUCCESS;
            newActivity.Status__c = VOIDED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = ERROR;
            newActivity.Status__c = ERROR;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = VOIDED;
            newActivity.Status__c = VOIDED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isTrue(isStatusChangeSupported);

            oldActivity.Status__c = PENDING;
            newActivity.Status__c = 'Unknown';
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = DECLINED;
            newActivity.Status__c = SUCCESS;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = DECLINED;
            newActivity.Status__c = VOIDED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = DECLINED;
            newActivity.Status__c = ERROR;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = DECLINED;
            newActivity.Status__c = PENDING;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = SUCCESS;
            newActivity.Status__c = PENDING;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = SUCCESS;
            newActivity.Status__c = DECLINED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = SUCCESS;
            newActivity.Status__c = ERROR;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = ERROR;
            newActivity.Status__c = PENDING;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = ERROR;
            newActivity.Status__c = SUCCESS;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = ERROR;
            newActivity.Status__c = DECLINED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = ERROR;
            newActivity.Status__c = VOIDED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = VOIDED;
            newActivity.Status__c = PENDING;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);
            
            oldActivity.Status__c = VOIDED;
            newActivity.Status__c = DECLINED;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = VOIDED;
            newActivity.Status__c = ERROR;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);

            oldActivity.Status__c = VOIDED;
            newActivity.Status__c = SUCCESS;
            isStatusChangeSupported = PaymentActivityUpdateUseCase.isStatusChangeSupported(newActivity, oldActivity);
            Assert.isFalse(isStatusChangeSupported);
        }
    }

}