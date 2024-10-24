@IsTest
public with sharing class UUIDTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testGetUUID() {
        String uuid = UUID.getUUID();
        Assert.isNotNull(uuid);
    }
    
    @IsTest
    private static void testGenUUID() {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Document';
        cv.PathOnClient = 'TestDocument.pdf';
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        insert cv;
        
        List<ContentVersion> filesList = UUID.generateUUID(new List<ContentVersion>{cv}, 'ExtId__c');
        Assert.isNotNull(filesList);
    }
}