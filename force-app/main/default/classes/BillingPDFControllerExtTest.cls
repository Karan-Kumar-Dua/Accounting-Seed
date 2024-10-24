@IsTest
public class BillingPDFControllerExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBillingPDFSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.BillingProductPDF;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            BillingPDFControllerExt bPdf = new BillingPDFControllerExt(
                new ApexPages.StandardController(testData.billings[0])
            );
            System.assertEquals(2, bPdf.billLines.size());
        }

    }

    @IsTest
    public static void testBillingPDFSortOrder() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            delete [SELECT Id FROM BIlling_Line__c WHERE Billing__c = :testData.billings[0].Id];
            List<Billing_Line__c> billLines = new List<Billing_Line__c>();

            for (Integer i = 5; i != 0; i--) {
                billLines.add(
                    new Billing_Line__c(
                        Billing__c = testData.billings[0].Id,
                        Hours_Units__c = i,
                        Rate__c = 1,
                        Revenue_GL_Account__c = testData.glAccounts[16].Id
                    )
                );
            }
            insert billLines;

            BillingPDFControllerExt bPdf = new BillingPDFControllerExt(
                new ApexPages.StandardController(testData.billings[0])
            );

            PageReference pageRef = Page.BillingProductPDF;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            pageRef.getParameters().put('sortField', GlobalVariables.PACKAGE_QUALIFIER + 'Hours_Units__c');
            Test.setCurrentPage(pageRef);
            Integer lineCount = 4;
            billLines = [SELECT Id, Name FROM Billing_Line__c WHERE Billing__c = :testData.billings[0].Id];
            for (Billing_Line__c billLine : bPdf.queryBillingLinesByBillingId(testData.billings[0].Id)) {
                System.assertEquals(billLine.Name, billLines[lineCount--].Name);
            }
        }
    }

    @IsTest
    public static void testBillingPDFPlatformUser() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        TestDataSuite.assignAdminPermissionSet(testData.platformTestUser.Id);

        System.runAs(testData.platformTestUser) {
            PageReference pageRef = Page.BillingProductPDF;
            pageRef.getParameters().put('id', testData.billings[0].Id);
            Test.setCurrentPage(pageRef);

            BillingPDFControllerExt bPdf = new BillingPDFControllerExt(
                new ApexPages.StandardController(testData.billings[0])
            );
            System.assertEquals(2, bPdf.billLines.size());
        }

    }

    @IsTest
    public static void testGetSortFieldApiNameDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String sortFieldName = null;
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual('Name', resultFieldName);

            sortFieldName = '';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual('Name', resultFieldName);

            sortFieldName = ' ';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual('Name', resultFieldName);

            sortFieldName = 'DoesntExist__c';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual('Name', resultFieldName);

            sortFieldName = 'Name';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual('Name', resultFieldName);
        }
    }

    @IsTest
    public static void testGetSortFieldApiNameCustomField() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String sortFieldName = 'Custom_Sort_Field__c';
            billingLineFieldNames.add(sortFieldName);
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(sortFieldName, resultFieldName);
        }
    }

    @IsTest
    public static void testGetSortFieldApiNameNamespaceCoercion() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            String sortFieldName = 'Hours_Units__c';
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(ns + sortFieldName, resultFieldName);
        }
    }

    @IsTest
    public static void testGetSortFieldApiNamePackagedField() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            String sortFieldName = ns + 'Date__c';
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(sortFieldName, resultFieldName);

            sortFieldName = ns + 'Tax_Rate__c';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(sortFieldName, resultFieldName);
        }
    }

    @IsTest
    public static void testGetSortFieldApiNameStandardField() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String sortFieldName = 'Description';
            productFieldNames.add(sortFieldName);
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(sortFieldName, resultFieldName);
        }
    }

    @IsTest
    public static void testGetSortFieldApiNameProductName() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            String sortFieldName = ns + 'Product__r.Name';
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(sortFieldName, resultFieldName);
        }
    }

    @IsTest
    public static void testGetSortFieldApiNameLookupToName() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            // get the available field names the same way the controller does
            Set<String> billingLineFieldNames = SFDCSecurityUtils.getOnlyCustomAndAccessibleFields(Billing_Line__c.SObjectType);
            Set<String> productFieldNames = BillingPDFControllerExt.getAccessibleProductFields();

            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            String sortFieldName = ns + 'Employee__c';
            String resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(ns + 'Employee__r.Name', resultFieldName);

            sortFieldName = ns + 'Project__c';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(ns + 'Project__r.Name', resultFieldName);

            sortFieldName = ns + 'Project_Task__c';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(ns + 'Project_Task__r.Name', resultFieldName);

            sortFieldName = ns + 'Revenue_GL_Account__c';
            resultFieldName = BillingPDFControllerExt.getSortFieldApiName(sortFieldName, billingLineFieldNames, productFieldNames);
            Assert.areEqual(ns + 'Revenue_GL_Account__r.Name', resultFieldName);
        }
    }

}