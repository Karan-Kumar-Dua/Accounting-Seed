@IsTest
public with sharing class AbstractStatementManagerTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetPdfPageRefFull() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Billing__c[] bills = [
                SELECT 
                  Id 
                , Name
                , Billing_Contact__c
                , Billing_Contact__r.FirstName
                , Billing_Contact__r.LastName
                , Billing_Contact__r.Email
                , Billing_Format__c
                , Billing_Format__r.Default_Email_Template__c
                , Billing_Format__r.ReplyTo_Email__c
                , Billing_Format__r.Visualforce_PDF_Page__c
                , Billing_Format__r.Org_Wide_Email_Address__c
                , Billing_Format__r.Sort_Field__c
                , Date__c
                , Customer__c
                , Customer__r.Name
                , Proprietary_Billing_Number__c
                FROM Billing__c
                LIMIT 1
            ];

            AbstractStatementManager.StatementSet stmtSet = new AbstractStatementManager.StatementSet(
                bills,
                AbstractStatementManager.StatementType.BILLING,
                TestDataSuite.salesforceUrl
            );

            AbstractStatementManager.Statement stmt = stmtSet.statements[0];

            String expectedUrl = (
                TestDataSuite.salesforceUrl + 
                '/apex/' + 
                bills[0].Billing_Format__r.Visualforce_PDF_Page__c
            );

            // the statement has the correct pdf url
            System.assertEquals(expectedUrl, stmt.urlPDF);

            // a page ref resolves the pdf url correct correctly
            Pagereference pageRef = new Pagereference(stmt.urlPDF);
            System.assertNotEquals(null, pageRef);
            System.assertEquals(expectedUrl, pageRef.getUrl());

            // the statement can be created
            Blob pdf = stmt.getPDF();
            System.assertNotEquals(null, pdf);
            System.assertEquals('test', pdf.toString());
        }
    }

    @IsTest
    private static void testGetPdfPageRefPartial() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Billing__c[] bills = [
                SELECT 
                  Id 
                , Name
                , Billing_Contact__c
                , Billing_Contact__r.FirstName
                , Billing_Contact__r.LastName
                , Billing_Contact__r.Email
                , Billing_Format__c
                , Billing_Format__r.Default_Email_Template__c
                , Billing_Format__r.ReplyTo_Email__c
                , Billing_Format__r.Visualforce_PDF_Page__c
                , Billing_Format__r.Org_Wide_Email_Address__c
                , Billing_Format__r.Sort_Field__c
                , Date__c
                , Customer__c
                , Customer__r.Name
                , Proprietary_Billing_Number__c
                FROM Billing__c
                LIMIT 1
            ];

            AbstractStatementManager.StatementSet stmtSet = new AbstractStatementManager.StatementSet(
                bills,
                AbstractStatementManager.StatementType.BILLING,
                GlobalVariables.APEX_URL_PATH
            );

            AbstractStatementManager.Statement stmt = stmtSet.statements[0];

            String expectedUrl = (
                GlobalVariables.APEX_URL_PATH + 
                GlobalVariables.PACKAGE_QUALIFIER + 
                bills[0].Billing_Format__r.Visualforce_PDF_Page__c
            ).toLowerCase();

            // the statement has the correct pdf url
            System.assertEquals(expectedUrl, stmt.urlPDF);

            // a page ref resolves the pdf url correct correctly
            Pagereference pageRef = new Pagereference(stmt.urlPDF);
            System.assertNotEquals(null, pageRef);
            System.assertEquals(expectedUrl, pageRef.getUrl());

            // the statement can be created
            Blob pdf = stmt.getPDF();
            System.assertNotEquals(null, pdf);
            System.assertEquals('test', pdf.toString());
        }
    }

}