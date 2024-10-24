@IsTest
public class PDFFormatActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCheckVFPageExistsInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
        
            DMLException dmlEx;
            try {
                Billing_Format__c billFormat = testData.billingFormats[0].clone(false, true);
                billFormat.Visualforce_PDF_Page__c = 'DoesNotExistPageNameIWouldNotUseThisName';
                billFormat.Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName;
                insert billFormat;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(PDFFormatActions.VF_PAGE_ERROR,dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testCheckVFPageExistsUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        DMLException dmlEx;
        try {
            testData.billingFormats[0].Visualforce_PDF_Page__c = 'DoesNotExistPageNameIWouldNotUseThisName';
            update testData.billingFormats[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        
        System.assertEquals(PDFFormatActions.VF_PAGE_ERROR,dmlEx.getDmlMessage(0)); 
    }
    
    @IsTest
    public static void testCheckEmailTemplateExistsInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        DMLException dmlEx;     
        try {
            Billing_Format__c billFormat = testData.billingFormats[0].clone(false,true);
            billFormat.Default_Email_Template__c = 'AcctSeedDoesNotExistThisEmailTemplate';
            billFormat.Visualforce_PDF_Page__c = 'BillingProductPDF';
            insert billFormat;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        
        System.assertEquals(PDFFormatActions.EMAIL_TEMPLATE_ERROR,dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testCheckEmailTemplateExistsUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        DMLException dmlEx;
        try {
            testData.billingFormats[0].Default_Email_Template__c = 'DoesNotExistPageNameIWouldNotUseThisName';
            update testData.billingFormats[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        
        System.assertEquals(PDFFormatActions.EMAIL_TEMPLATE_ERROR,dmlEx.getDmlMessage(0));       
    }

    @IsTest
    public static void testPDFFormatNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Billing_Format__c bf = new Billing_Format__c();

                try {
                    insert bf;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testValidateOrgWideEmailAddress() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List<OrgWideEmailAddress> specificOrgWideEmailAddress = [SELECT Id, Address FROM OrgWideEmailAddress];

        if (specificOrgWideEmailAddress.isEmpty()) {
            return;
        }

        DMLException dmlEx;
        try {
            testData.billingFormats[0].Org_Wide_Email_Address__c = specificOrgWideEmailAddress[0].Address;
            update testData.billingFormats[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(NULL, dmlEx);

        try {
            testData.billingFormats[0].Org_Wide_Email_Address__c = 'test23888329993988test@test.test';
            update testData.billingFormats[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(PDFFormatActions.OWE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventDeleteIfRelatedRecordsExist() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            try {
                delete testData.billingFormats[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(PDFFormatActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfRelatedLedgerRecordExist() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            try {
                delete testData.billingFormats[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(PDFFormatActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

}