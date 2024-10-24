@IsTest
public class ContentDocumentLinkActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testContentDocumentLinkActions() {
        Account acc = new Account();
        acc.Name = 'Test';
        insert acc;
        
        AcctSeed__Accounting_Period__c pay1 = new AcctSeed__Accounting_Period__c();
        pay1.AcctSeed__Close_AP__c = true;
        pay1.AcctSeed__Start_Date__c = Date.today();
        pay1.AcctSeed__End_Date__c = Date.today()+5;
        pay1.Name = '2024-07';
        insert pay1;
        
        AcctSeed__Account_Payable__c pay = new AcctSeed__Account_Payable__c();
        pay.AcctSeed__Status__c = 'Approved';
        pay.AcctSeed__Payee_Reference__c = 'Test';
        pay.AcctSeed__Vendor__c = acc.Id;
        pay.AcctSeed__Accounting_Period__c = pay1.Id;
        insert pay;

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Document';
        cv.PathOnClient = 'TestDocument.pdf';
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        insert cv;
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;
        
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = pay.Id;
        cdl.ContentDocumentId = conDocId;
        cdl.ShareType = 'V';
        insert cdl;
        
        Assert.isNotNull([SELECT ExtId__c FROM ContentVersion WHERE Id =:cv.Id].ExtId__c);
    }
}