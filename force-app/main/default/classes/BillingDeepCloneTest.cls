@IsTest
public class BillingDeepCloneTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    public static testMethod void testBillingDeepClone() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 12, 1);
            ext.cloneWithLines();
            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Id = :ext.cloneBilling.Id]);
            System.assertEquals(2, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :ext.cloneBilling.Id]);
        }

    }

    public static testMethod void testBillingCreditMemoDeepCloneDefault() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings().setCreditMemoDefaultAmount();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 12, 1);
            ext.makeCreditMemo = true;
            ext.cloneWithLines();
            Billing_Line__c result = [SELECT Rate__c, Hours_Units__c FROM Billing_Line__c WHERE Billing__c = :ext.cloneBilling.Id][0];
            System.assertEquals('Credit Memo', [SELECT Type__c FROM Billing__c WHERE Id = :ext.cloneBilling.Id].Type__c);
            System.assert(result.Rate__c < 0);
            System.assert(result.Hours_Units__c > 0);
        }

    }

    public static testMethod void testBillingCreditMemoDeepCloneQuantity() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings().setCreditMemoDefaultQuantity();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 12, 1);
            ext.makeCreditMemo = true;
            ext.cloneWithLines();
            Billing_Line__c result = [SELECT Rate__c, Hours_Units__c FROM Billing_Line__c WHERE Billing__c = :ext.cloneBilling.Id][0];
            System.assertEquals('Credit Memo', [SELECT Type__c FROM Billing__c WHERE Id = :ext.cloneBilling.Id].Type__c);
            System.assert(result.Rate__c > 0);
            System.assert(result.Hours_Units__c < 0);
        }

    }

    public static testMethod void testCloneCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        Billing_Line__c bl = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 100,
                Rate__c = -100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
        );
        insert bl;

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 12, 1);
            ext.cloneWithLines();
            System.assertEquals('Credit Memo', [SELECT Type__c FROM Billing__c WHERE Id = :ext.cloneBilling.Id].Type__c);
            Test.stopTest();
        }

    }

    private static testMethod void testCloneSoftARCloseBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        Test.startTest();
        Billing_Line__c bl = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 100,
                Rate__c = -100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
        );
        insert bl;
        
        List<Accounting_Period__c> acctPeriods = [Select id, Close_AR__c, Start_Date__c From Accounting_Period__c 
                                                  WHERE Start_Date__c =: Date.newInstance(1991, 10, 1)];
        acctPeriods[0].Close_AR__c = true;
        UPDATE acctPeriods[0];                                        
        
        System.runAs(testData.users[1]) {
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 10, 1); 
            PageReference pg = ext.cloneWithLines();
            
            System.assertEquals(TRUE, pg == NULL);
            System.assertEquals(TRUE, ext.isError); 
            Test.stopTest();
        }
    }

    private static testMethod void testCloneSoftAROpenBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        Billing_Line__c bl = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 100,
                Rate__c = -100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
        );
        insert bl;
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 11, 1); 
            PageReference pg = ext.cloneWithLines();
            
            System.assertEquals(TRUE, pg != NULL);
            System.assertEquals(ext.tempBilling.Date__c, ext.cloneBilling.Date__c); 

            System.assertEquals(ext.tempBilling.Date__c, ext.newBillLines[0].Date__c); 
            System.assertEquals(ext.cloneBilling.Id, ext.newBillLines[0].Billing__c);
            Test.stopTest();
        }
    }
    private static testMethod void testBillingDeepCloneWithExtraFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        
        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c bl = new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 100,
                    Rate__c = -100,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert bl;
            ApexPages.StandardController con = new ApexPages.StandardController(testData.billings[0]);
            BillingDeepClone ext = new BillingDeepClone(con);
            ext.tempBilling.Date__c = Date.newInstance(1991, 11, 1); 
            PageReference pg = ext.cloneWithLines();
            
            Assert.areEqual(TRUE, pg != NULL);
            Assert.areEqual(ext.tempBilling.Date__c, ext.cloneBilling.Date__c); 

            Assert.areEqual(ext.tempBilling.Date__c, ext.newBillLines[0].Date__c); 
            Assert.areEqual(ext.cloneBilling.Id, ext.newBillLines[0].Billing__c);

            //make sure the billing is cloned correctly
            Assert.areEqual(ext.cloneBilling.Billing_Cycle_Start_Date__c, testData.billings[0].Billing_Cycle_Start_Date__c);
            Assert.areEqual(ext.cloneBilling.Billing_Cycle_End_Date__c, testData.billings[0].Billing_Cycle_End_Date__c);
            Assert.areEqual(ext.cloneBilling.Customer__c, testData.billings[0].Customer__c);
            Assert.areEqual(ext.cloneBilling.Status__c, testData.billings[0].Status__c);
            Assert.areEqual(ext.cloneBilling.Billing_Format__c, testData.billings[0].Billing_Format__c);
            Assert.areEqual(ext.cloneBilling.Billing_Street__c, testData.billings[0].Billing_Street__c);
            Assert.areEqual(ext.cloneBilling.Billing_City__c, testData.billings[0].Billing_City__c);
            Assert.areEqual(ext.cloneBilling.Billing_State__c, testData.billings[0].Billing_State__c);
            Assert.areEqual(ext.cloneBilling.Billing_Country__c, testData.billings[0].Billing_Country__c);
            Assert.areEqual(ext.cloneBilling.Billing_PostalCode__c, testData.billings[0].Billing_PostalCode__c);
            Assert.areEqual(ext.cloneBilling.Shipping_Street__c, testData.billings[0].Shipping_Street__c);
            Assert.areEqual(ext.cloneBilling.Shipping_City__c, testData.billings[0].Shipping_City__c);
            Assert.areEqual(ext.cloneBilling.Shipping_State__c, testData.billings[0].Shipping_State__c);
            Assert.areEqual(ext.cloneBilling.Shipping_Country__c, testData.billings[0].Shipping_Country__c);
            Assert.areEqual(ext.cloneBilling.Shipping_PostalCode__c, testData.billings[0].Shipping_PostalCode__c);
           
            //make sure the billing lines are cloned correctly
            Assert.areEqual(ext.newBillLines[2].Billing__c, ext.cloneBilling.Id);
            Assert.areEqual(ext.newBillLines[2].Hours_Units__c, bl.Hours_Units__c);
            Assert.areEqual(ext.newBillLines[2].Rate__c, bl.Rate__c);
            Assert.areEqual(ext.newBillLines[2].Revenue_GL_Account__c, bl.Revenue_GL_Account__c);
            
            Test.stopTest();
        }
    }

}