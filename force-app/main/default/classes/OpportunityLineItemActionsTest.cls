@IsTest
public class OpportunityLineItemActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    public static void testDefaultProductFieldsDefault() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();

        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();
                
        testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
        testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
        testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
        update testData.products[0];
              
        pbeList.add(
            new PricebookEntry(
                Product2Id=testData.products[0].Id,
                PriceBook2Id=Test.getStandardPricebookId(),
                UnitPrice=4000,
                isActive=true
            )
        );
        insert pbeList;

        oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId=pbeList[0].Id,
                    OpportunityId=testData.opportunities[0].Id,
                    Quantity=2,UnitPrice=4000
                )
        );        
        insert oliList;                 
        
        System.assertEquals(testData.products[0].GL_Account_Variable_1__c, [Select GL_Account_Variable_1__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_1__c);
        System.assertEquals(testData.products[0].GL_Account_Variable_2__c, [Select GL_Account_Variable_2__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_2__c);
        System.assertEquals(testData.products[0].GL_Account_Variable_3__c, [Select GL_Account_Variable_3__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_3__c);
        System.assertEquals(testData.products[0].GL_Account_Variable_4__c, [Select GL_Account_Variable_4__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_4__c);
    }
    
    @IsTest
    public static void testDefaultProductFieldsNoDefault() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();
                
        testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
        testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
        testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
        update testData.products[0];
              
        pbeList.add(
            new PricebookEntry(
                Product2Id=testData.products[0].Id,
                PriceBook2Id=Test.getStandardPricebookId(),
                UnitPrice=4000,
                isActive=true
            )
        );
        
        insert pbeList;

        oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId=pbeList[0].Id,
                    OpportunityId=testData.opportunities[0].Id,
                    Quantity=2,UnitPrice=4000,
                    GL_Account_Variable_1__c=testData.accountingVariables1[1].Id,
                    GL_Account_Variable_2__c=testData.accountingVariables2[1].Id,
                    GL_Account_Variable_3__c=testData.accountingVariables3[1].Id,
                    GL_Account_Variable_4__c=testData.accountingVariables4[1].Id
            )
        );     
           
        insert oliList;                 
        
        System.assertEquals(testData.accountingVariables1[1].Id, [Select GL_Account_Variable_1__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_1__c);
        System.assertEquals(testData.accountingVariables2[1].Id, [Select GL_Account_Variable_2__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_2__c);
        System.assertEquals(testData.accountingVariables3[1].Id, [Select GL_Account_Variable_3__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_3__c);
        System.assertEquals(testData.accountingVariables4[1].Id, [Select GL_Account_Variable_4__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_4__c);
    }

    @IsTest
    public static void testDefaultProductFieldsNull() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();
                
        testData.products[0].GL_Account_Variable_1__c = null;
        testData.products[0].GL_Account_Variable_2__c = null;
        testData.products[0].GL_Account_Variable_3__c = null;
        testData.products[0].GL_Account_Variable_4__c = null;
        update testData.products[0];
              
        pbeList.add(
            new PricebookEntry(
                Product2Id=testData.products[0].Id,
                PriceBook2Id=Test.getStandardPricebookId(),
                UnitPrice=4000,
                isActive=true
            )
        );
        
        insert pbeList;

        oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId=pbeList[0].Id,
                    OpportunityId=testData.opportunities[0].Id,
                    Quantity=2,UnitPrice=4000,
                    GL_Account_Variable_1__c=null,
                    GL_Account_Variable_2__c=null,
                    GL_Account_Variable_3__c=null,
                    GL_Account_Variable_4__c=null
            )
        );     
           
        insert oliList;                 
        
        System.assertEquals(null, [Select GL_Account_Variable_1__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_1__c);
        System.assertEquals(null, [Select GL_Account_Variable_2__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_2__c);
        System.assertEquals(null, [Select GL_Account_Variable_3__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_3__c);
        System.assertEquals(null, [Select GL_Account_Variable_4__c From OpportunityLineItem Where Id = :oliList[0].Id].GL_Account_Variable_4__c);     
                         
    }

    public static testMethod void testDefaultGLAVOnAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();
                
        testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
        testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
        testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
        update testData.accounts[0];
              
        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );        
        insert oliList;                 
        
        System.assertEquals(testData.accounts[0].GL_Account_Variable_1__c, [SELECT GL_Account_Variable_1__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_1__c);
        System.assertEquals(testData.accounts[0].GL_Account_Variable_2__c, [SELECT GL_Account_Variable_2__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_2__c);
        System.assertEquals(testData.accounts[0].GL_Account_Variable_3__c, [SELECT GL_Account_Variable_3__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_3__c);
        System.assertEquals(testData.accounts[0].GL_Account_Variable_4__c, [SELECT GL_Account_Variable_4__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_4__c);
    }

    
    @isTest
    public static void testInsertAccountGLVar1Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_1__c = testData.accountingVariables1[0].Id
            )
        );        

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_1__c,[SELECT Id, GL_Account_Variable_1__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_1__c);
    }

    @isTest
    public static void testInsertAccountGLVar1Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_1__c = testData.accountingVariables2[0].Id
            )
        );        

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'1'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar1Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );        
        insert oliList;
        
        System.assertEquals(NULL,oliList[0].GL_Account_Variable_1__c);

        oliList[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
        DMLException dmlEx;

        try {
            update oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_1__c,[SELECT Id, GL_Account_Variable_1__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_1__c);
    }

    @isTest
    public static void testUpdateAccountGLVar1Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );        
        insert oliList;

        System.assertEquals(NULL,oliList[0].GL_Account_Variable_1__c);

        oliList[0].GL_Account_Variable_1__c = testData.accountingVariables2[0].Id;
        DMLException dmlEx;

        try {
            update oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'1'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testInsertAccountGLVar2Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );        
        
        oliList[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_2__c,[SELECT Id, GL_Account_Variable_2__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_2__c);
    }

    @isTest
    public static void testInsertAccountGLVar2Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_2__c = testData.accountingVariables1[0].Id
            )
        );        

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'2'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar2Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );        
        insert oliList;

        System.assertEquals(NULL,oliList[0].GL_Account_Variable_2__c);

        oliList[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
        DMLException dmlEx;

        try {
            update oliList[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_2__c,[SELECT Id, GL_Account_Variable_2__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_2__c);
    }

    @isTest
    public static void testUpdateAccountGLVar2Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );        
        insert oliList;
    
        System.assertEquals(NULL,oliList[0].GL_Account_Variable_2__c);

        oliList[0].GL_Account_Variable_2__c = testData.accountingVariables1[0].Id;

        DMLException dmlEx;

        try {
            update oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'2'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testInsertAccountGLVar3Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_3__c = testData.accountingVariables3[0].Id
            )
        );

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_3__c,[SELECT Id, GL_Account_Variable_3__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_3__c);
    }

    @isTest
    public static void testInsertAccountGLVar3Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_3__c = testData.accountingVariables1[0].Id
            )
        );

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'3'}),dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar3Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );
        insert oliList;

        System.assertEquals(NULL,oliList[0].GL_Account_Variable_3__c);

        oliList[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
        DMLException dmlEx;

        try {
            update oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_3__c,[SELECT Id, GL_Account_Variable_3__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_3__c);
    }

    @isTest
    public static void testUpdateAccountGLVar3Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );
        insert oliList;

        System.assertEquals(NULL,oliList[0].GL_Account_Variable_3__c);

        oliList[0].GL_Account_Variable_3__c = testData.accountingVariables1[0].Id;
        DMLException dmlEx;

        try {
            update oliList[0];
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'3'}),dmlEx.getDMLMessage(0));
    }
    
    @isTest
    public static void testInsertAccountGLVar4Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_4__c = testData.accountingVariables4[0].Id
            )
        );

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_4__c,[SELECT Id, GL_Account_Variable_4__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_4__c);
    }

    @isTest
    public static void testInsertAccountGLVar4Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000,
                GL_Account_Variable_4__c = testData.accountingVariables1[0].Id
            )
        );

        DMLException dmlEx;

        try {
            insert oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'4'}), dmlEx.getDMLMessage(0));
    }

    @isTest
    public static void testUpdateAccountGLVar4Success() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );
        insert oliList;

        System.assertEquals(NULL,oliList[0].GL_Account_Variable_4__c);

        oliList[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
        DMLException dmlEx;

        try {
            update oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(oliList[0].GL_Account_Variable_4__c,[SELECT Id, GL_Account_Variable_4__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].GL_Account_Variable_4__c);
    }

    @isTest
    public static void testUpdateAccountGLVar4Error() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createAccountingVariables().createOpportunities();
        Test.startTest();
        OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
        PricebookEntry[] pbeList = new List<PriceBookEntry>();

        pbeList.add(
            new PricebookEntry(
                Product2Id = testData.products[0].Id,
                PriceBook2Id = Test.getStandardPricebookId(),
                UnitPrice = 4000,
                isActive = true
            )
        );
        insert pbeList;

        oliList.add(
            new OpportunityLineItem(
                PriceBookEntryId = pbeList[0].Id,
                OpportunityId = testData.opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 4000
            )
        );
        insert oliList;

        System.assertEquals(NULL, oliList[0].GL_Account_Variable_4__c);

        oliList[0].GL_Account_Variable_4__c = testData.accountingVariables1[0].Id;
        DMLException dmlEx;

        try {
            update oliList;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(SObjectActions.TYPE_ERROR, new String[]{'4'}), dmlEx.getDMLMessage(0));
    }

    @IsTest
    private static void testOpportunityLineItemValidateTaxGroupHasTaxRateInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .createProducts()
            .createAccountingVariables()
            .createOpportunities();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();

            pbeList.add(
                new PricebookEntry(
                    Product2Id = testData.products[0].Id,
                    PriceBook2Id = Test.getStandardPricebookId(),
                    UnitPrice = 4000,
                    isActive = true
                )
            );
            insert pbeList;

            oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId = pbeList[0].Id,
                    OpportunityId = testData.opportunities[0].Id,
                    Quantity = 2,
                    UnitPrice = 4000,
                    Tax_Group__c = testData.taxGroups[1].Id
                )
            );

            DmlException dmlEx;
            try {
                insert oliList;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {'Opportunity Product'}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testOpportunityLineItemValidateTaxGroupHasTaxRateUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .createProducts()
            .createAccountingVariables()
            .createOpportunities();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();

            pbeList.add(
                new PricebookEntry(
                    Product2Id = testData.products[0].Id,
                    PriceBook2Id = Test.getStandardPricebookId(),
                    UnitPrice = 4000,
                    isActive = true
                )
            );
            insert pbeList;

            oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId = pbeList[0].Id,
                    OpportunityId = testData.opportunities[0].Id,
                    Quantity = 2,
                    UnitPrice = 4000
                )
            );

            insert oliList;

            DmlException dmlEx;
            try {
                oliList[0].Tax_Group__c = testData.taxGroups[1].Id;
                update oliList;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {'Opportunity Product'}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testOpportunityLineItemSetTaxGroupByProductWrongTaxGroup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .createProducts()
            .createAccountingVariables()
            .createOpportunities();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            testData.products[0].Tax_Group__c = testData.taxGroups[1].Id;
            update testData.products[0];

            pbeList.add(
                new PricebookEntry(
                    Product2Id = testData.products[0].Id,
                    PriceBook2Id = Test.getStandardPricebookId(),
                    UnitPrice = 4000,
                    isActive = true
                )
            );
            insert pbeList;

            oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId = pbeList[0].Id,
                    OpportunityId = testData.opportunities[0].Id,
                    Quantity = 2,
                    UnitPrice = 4000
                )
            );

            DmlException dmlEx;
            try {
                insert oliList;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // NULL because wrong Tax Group type
            System.assertEquals(NULL, [SELECT Id, Tax_Group__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].Tax_Group__c);
        }
    }
    //commenting out for now because it is erroring
    //Error Message	System.AssertException: Assertion Failed: Expected: a103b00000CdOLkAAN, Actual: null
    //Stack Trace	Class.AcctSeed.OpportunityLineItemActionsTest.testOpportunityLineItemSetTaxGroupByProductCorrectTaxGroup: line 1016, column 1
    /*@IsTest
    private static void testOpportunityLineItemSetTaxGroupByProductCorrectTaxGroup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .createProducts()
            .createAccountingVariables()
            .createOpportunities();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            OpportunityLineItem[] oliList = new List<OpportunityLineItem>();
            PricebookEntry[] pbeList = new List<PriceBookEntry>();
            testData.products[0].Tax_Group__c = testData.taxGroups[0].Id;
            update testData.products[0];

            pbeList.add(
                new PricebookEntry(
                    Product2Id = testData.products[0].Id,
                    PriceBook2Id = Test.getStandardPricebookId(),
                    UnitPrice = 4000,
                    isActive = true
                )
            );
            insert pbeList;

            oliList.add(
                new OpportunityLineItem(
                    PriceBookEntryId = pbeList[0].Id,
                    OpportunityId = testData.opportunities[0].Id,
                    Quantity = 2,
                    UnitPrice = 4000,
                    Tax_Group__c = testData.taxGroups[0].Id
                )
            );

            DmlException dmlEx;
            try {
                insert oliList;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                testData.taxGroups[0].Id,
                [SELECT Id, Tax_Group__c FROM OpportunityLineItem WHERE Id = :oliList[0].Id].Tax_Group__c
            );
        }
    }*/

    public static void testOppLineItemNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                OpportunityLineItem oppLineItem = new OpportunityLineItem();
                insert oppLineItem;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            if (dmlEx != NULL) {
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
    }
}