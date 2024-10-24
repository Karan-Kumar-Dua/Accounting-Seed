@IsTest
public with sharing class FilePreviewServiceTest{
    @TestSetup
    private static void setupTestData(){
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testCheckPreviewAvailability(){
        TestDataSuite testData = TestDataSuite.getInstance();
        Boolean previewAvailable = true;
        System.runAs(testData.users[1]){
            
            FilePreviewService.FilePreviewWrapper[] fileWrappers = new FilePreviewService.FilePreviewWrapper[]{  };
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