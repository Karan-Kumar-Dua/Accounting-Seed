@isTest
public with sharing class FilePreviewCarouselControllerTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testGetRelatedFilesByRecordId() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) { 

            Accounting_Period__c acctPeriods = [SELECT Id FROM Accounting_Period__c LIMIT 1];
            Date todayDate = System.today();
            acctPeriods.Start_Date__c = Date.newInstance(todayDate.year(), todayDate.month(), 1);
            acctPeriods.End_Date__c = acctPeriods.Start_Date__c.addMonths(1).addDays(-1);
            update acctPeriods;
            
            Account_Payable__c ap = new Account_Payable__c();
            ap.Status__c = 'Draft';
            insert ap;
            
            String fileId = FinancialSuiteUtils.getUUID();
            
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Test Document';
            cv.PathOnClient = 'TestDocument.pdf';
            cv.VersionData = Blob.valueOf('Test Content');
            cv.IsMajorVersion = true;
            cv.AcctSeed__ExtId__c = fileId;
            insert cv;
            
            ContentVersion document = [SELECT ContentDocumentId, ExtId__c FROM ContentVersion WHERE Id =:cv.Id LIMIT 1];
            
            ContentDocumentLink cdl = New ContentDocumentLink();
            cdl.LinkedEntityId = ap.Id;
            cdl.ContentDocumentId = document.ContentDocumentId;
            cdl.shareType = 'V';
            insert cdl;
            
            FilePreviewCarouselController.setDefaultFileId(ap.Id,'Default_File_Id__c',document.ExtId__c);
            
            FilePreviewCarouselController.Params params = new FilePreviewCarouselController.Params();
            params.recordId = ap.Id;
            params.fileId = fileId;
            params.fieldNameForFileID = 'Default_File_Id__c';
            String stringParams = JSON.serialize(params);
            List<FilePreviewCarouselController.RelatedFilesWrapper> relatedFilesWrappers = FilePreviewCarouselController.getRelatedFilesByRecordId(stringParams);
            System.assertEquals(1, relatedFilesWrappers.size());
        }
    }
    
    @IsTest
    private static void testCheckPreviewAvailability() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Boolean previewAvailable = true;

        System.runAs(testData.users[1]) {
            FilePreviewService.FilePreviewWrapper[] fileWrappers = new FilePreviewService.FilePreviewWrapper[]{};
            FilePreviewService.FilePreviewWrapper fileWrapper = new FilePreviewService.FilePreviewWrapper();
            fileWrapper.format = 'Pdf';
            fileWrapper.status = 'NotAvailable';
            fileWrappers.add(fileWrapper);
            
            FilePreviewService.FilePreviewResponse fileResponse = new FilePreviewService.FilePreviewResponse();
            fileResponse.previews = fileWrappers;
            
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Test Document';
            cv.PathOnClient = 'TestDocument.pdf';
            cv.VersionData = Blob.valueOf('Test Content');
            cv.IsMajorVersion = true;
            insert cv;
            
            ContentVersion document = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new SingleRequestMock(200, '', JSON.serialize(fileResponse), new Map<String, String>()));
            previewAvailable = FilePreviewCarouselController.checkPreviewAvailability(document.ContentDocumentId);
            Test.stopTest();
            
            Assert.isFalse(previewAvailable);
        }
    }
}