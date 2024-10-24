@isTest
public class ContentDocumentActionsTest {
    @TestSetup
	private static void setupTestData() {
		TestDataSuite.getInstance(true);
	}

    @isTest
    private static void testContentDocumentActions(){
        TestDataSuite testData = TestDataSuite.getInstance();
        TestDataSuite testDataBankAccts = testData.createBankAccounts();
        Bank_Account__c bankAccount =  testDataBankAccts.bankAccounts[0];
        System.runAs(testData.users.get(1)) {
            Test.startTest();    
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Test Document';
            cv.PathOnClient = 'TestDocument.pdf';
            cv.VersionData = Blob.valueOf('Test Content');
            cv.IsMajorVersion = true;
            cv.ExtId__c = FinancialSuiteUtils.getUUID();
            insert cv;
            
            Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;
            
            ContentDocumentLink cdl = New ContentDocumentLink();
            cdl.LinkedEntityId = bankAccount.Id;
            cdl.ContentDocumentId = conDocId;
            cdl.ShareType = 'V';
            insert cdl;

            String externalId = [SELECT ExtId__c FROM ContentVersion WHERE Id =: cv.Id].ExtId__c;
        
            bankAccount.Signature_Block__c = externalId;
            bankAccount.Signature_Block_2__c = externalId;

            update bankAccount;

            Bank_Account__c bankAcc = [SELECT Id,Signature_Block__c,Signature_Block_2__c FROM Bank_Account__c WHERE Id = :bankAccount.Id];
            Assert.isNotNull(bankAcc.Signature_Block__c); 
            Assert.isNotNull(bankAcc.Signature_Block_2__c);

            ContentDocument cd = [SELECT Id FROM ContentDocument WHERE Id = :conDocId];
            delete cd;

            bankAcc = [SELECT Id,Signature_Block__c,Signature_Block_2__c FROM Bank_Account__c WHERE Id = :bankAccount.Id];

            Assert.isNull(bankAcc.Signature_Block__c); 
            Assert.isNull(bankAcc.Signature_Block_2__c);
            Test.stopTest();
        }
    }
}