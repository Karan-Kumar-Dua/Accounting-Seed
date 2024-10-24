@IsTest
private class FileManagerControllerTest {
    
    @TestSetup
    private static void setupTestData() {
        
        TestDataSuite.getInstance(true);
        
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        
        TestDataSuite.getInstance().createBankAccounts();
        
        System.runAs(new User(Id=UserInfo.getUserId())){
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Test Document';
            cv.PathOnClient = 'TestDocument.pdf';
            cv.VersionData = Blob.valueOf('Test Content');
            cv.IsMajorVersion = true;
            insert cv;
        }
    }
    
    @IsTest
    static void testUploadBankAccountSignBlock() {   
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {     
            Test.startTest();
            List<AcctSeed__Bank_Account__c> bankAccountBeforeUpload = [SELECT Id,Signature_Block__c FROM AcctSeed__Bank_Account__c WHERE Name = 'Test Account1' LIMIT 1];
            Assert.isNull(bankAccountBeforeUpload[0].Signature_Block__c);
            
            FileManagerController.FileManagerWrapper fileDetails = new FileManagerController.FileManagerWrapper();
            
            List<ContentDocument> documents = [SELECT Id FROM ContentDocument LIMIT 1];
            
            fileDetails.documentId = documents[0].Id;
            fileDetails.record_id = bankAccountBeforeUpload[0]?.Id;
            fileDetails.object_api_name = bankAccountBeforeUpload[0]?.Id.getSObjectType().getDescribe().getName();
            
            FileManagerController.updateFile(JSON.serialize(fileDetails),'Signature_Block__c');
            
            List<AcctSeed__Bank_Account__c> bankAccountAfterUpload = [SELECT Signature_Block__c FROM AcctSeed__Bank_Account__c WHERE Name = 'Test Account1' LIMIT 1];

            String retrievedFileId = FileManagerController.getFileId(bankAccountBeforeUpload[0]?.Id,bankAccountBeforeUpload[0]?.Id.getSObjectType().getDescribe().getName(),'Signature_Block__c');

            Assert.isNotNull(bankAccountAfterUpload[0].Signature_Block__c);
            Assert.areEqual(retrievedFileId,bankAccountAfterUpload[0].Signature_Block__c);
            
            Test.stopTest();
        }
    }

    @IsTest
    static void testUploadBankAccountSignBlock2() {   
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {     
            Test.startTest();
            List<AcctSeed__Bank_Account__c> bankAccountBeforeUpload = [SELECT Id,Signature_Block_2__c FROM AcctSeed__Bank_Account__c WHERE Name = 'Test Account1' LIMIT 1];
            Assert.isNull(bankAccountBeforeUpload[0].Signature_Block_2__c);
            
            FileManagerController.FileManagerWrapper fileDetails = new FileManagerController.FileManagerWrapper();
            
            List<ContentDocument> documents = [SELECT Id FROM ContentDocument LIMIT 1];
            
            fileDetails.documentId = documents[0].Id;
            fileDetails.record_id = bankAccountBeforeUpload[0]?.Id;
            fileDetails.object_api_name = bankAccountBeforeUpload[0]?.Id.getSObjectType().getDescribe().getName();
            
            FileManagerController.updateFile(JSON.serialize(fileDetails),'Signature_Block_2__c');
            
            List<AcctSeed__Bank_Account__c> bankAccountAfterUpload = [SELECT Signature_Block_2__c FROM AcctSeed__Bank_Account__c WHERE Name = 'Test Account1' LIMIT 1];            
            String retrievedFileId = FileManagerController.getFileId(bankAccountBeforeUpload[0]?.Id,bankAccountBeforeUpload[0]?.Id.getSObjectType().getDescribe().getName(),'Signature_Block_2__c');

            Assert.isNotNull(bankAccountAfterUpload[0].Signature_Block_2__c);
            Assert.areEqual(retrievedFileId,bankAccountAfterUpload[0].Signature_Block_2__c);
            
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testUploadLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            
            List<AcctSeed__Ledger__c> ledgersBeforeUpload = [SELECT Id,Logo__c FROM AcctSeed__Ledger__c WHERE Name = 'Actual' LIMIT 1];
            
            Assert.isNull(ledgersBeforeUpload[0].Logo__c);
            
            FileManagerController.FileManagerWrapper fileDetails = new FileManagerController.FileManagerWrapper();
            
            List<ContentDocument> documents = [SELECT Id FROM ContentDocument LIMIT 1];
            
            fileDetails.documentId = documents[0].Id;
            fileDetails.record_id = ledgersBeforeUpload[0]?.Id;
            fileDetails.object_api_name = ledgersBeforeUpload[0]?.Id.getSObjectType().getDescribe().getName();
            
            FileManagerController.updateFile(JSON.serialize(fileDetails),'Logo__c');
            
            List<AcctSeed__Ledger__c> ledgersAfterUpload = [SELECT Logo__c FROM AcctSeed__Ledger__c WHERE Name = 'Actual' LIMIT 1];
            
            String retrievedFileId = FileManagerController.getFileId(ledgersBeforeUpload[0]?.Id,ledgersBeforeUpload[0]?.Id.getSObjectType().getDescribe().getName(),'Logo__c');
            
            Assert.isNotNull(ledgersAfterUpload[0].Logo__c);
            Assert.areEqual(retrievedFileId,ledgersAfterUpload[0].Logo__c);
            
            Test.stopTest();
        }
    }
}