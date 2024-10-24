@IsTest
public without sharing class TestDataSuite {

    public List<User> users;
    public User adminTestUser;
    public User platformTestUser;
    public User currentTestUser;
    public Accounting_Settings__c settings;
    public List<Ledger__c> ledgers;
    public List<Ledger_Hierarchy__c> ledgerHierarchies;
    public List<Accounting_Period__c> acctPeriods;
    public List<GL_Account__c> glAccounts;
    public Ledger_Custom_Settings__c ledgerSettings;
    public List<Billing_Format__c> billingFormats;
    public List<Account> accounts;
    public List<Account> personAccounts;
    public List<Contact> contacts;
    public List<Account_Payable__c> payables;
    public List<Account_Payable_Line__c> payableLines;
    public List<Billing__c> billings;
    public List<Billing_Line__c> billingLines;
    public List<Billing_Rates__c> billingRates;
    public List<Cash_Receipt__c> cashReceipts;
    public List<Cash_Disbursement__c> cashDisbursements;
    public List<Cash_Disbursement_Batch__c> cashDisbursementBatch;
    public List<AP_Disbursement__c> apDisbursements;
    public List<AP_Aging_History__c> apAgingHistories;
    public List<Accounting_Variable__c> accountingVariables1;
    public List<Accounting_Variable__c> accountingVariables2;
    public List<Accounting_Variable__c> accountingVariables3;
    public List<Accounting_Variable__c> accountingVariables4;
    public List<Billing_Aging_History__c> billingAgingHistories;
    public List<Expense_Report__c> expenseReports;
    public List<Expense_Line__c> expenses;
    public List<Project__c> projects;
    public List<Project_Task__c> projectTasks;
    public List<GL_Account__c> glAccountsExpense;
    public List<Recurring_Account_Payable__c> recurringPayables;
    public List<Recurring_Account_Payable_Line__c> recurringPayableLines;
    public List<Recurring_Billing__c> recurringBillings;
    public List<Recurring_Billing_Line__c> recurringBillingLines;
    public List<Recurring_Journal_Entry__c> recurringJournalEntries;
    public List<Recurring_Journal_Entry_Line__c> recurringJournalEntryLines;
    public List<GL_Account__c> cashFlowCategories;
    public List<Scheduled_Revenue_Expense__c> scheduledRevenues;
    public List<Journal_Entry__c> journalEntries;
    public List<Journal_Entry_Line__c> journalEntryLines;
    public List<Bank_Deposit__c> bankDeposits;
    public List<Bank_Disbursement__c> bankDisbursements;
    public List<Bank_Reconciliation2__c> bankReconciliations;
    public List<Product2> products;
    public List<Product_Part__c> productParts;
    public List<Opportunity> opportunities;
    public List<Time_Card_Period__c> periods;
    public List<Time_Card__c> timeCards;
    public List<Time_Card_Line__c> timeCardLines;
    public List<Time_Card_Day__c> timeCardDays;
    public List<Account_Tax__c> accountTaxes;
    public List<Fixed_Asset__c> fixedAssets;
    public List<Financial_Report_Result__c> financialReportResults;
    public List<GL_Account_Reporting_Group__c> glReportingGroups;
    public List<GL_Account_Reporting_Group_Line__c> glReportingGroupLines;
    public List<Financial_Report_Definition__c> reportDefs;
    public List<Financial_Report_Row__c> reportRows;
    public List<Financial_Report_Column__c> reportCols;
    public List<Tax_Group__c> taxGroups;
    public List<Tax_Rate__c> taxRates;
    public List<Bank_Transaction__c> bankTransactions;
    public List<GL_Account_Mapping__c> glams;
    public List<Bank_Rule__c> bankRules;
    public List<Bank_Rule_Condition__c> bankRuleConditions;
    public List<Bank_Rule_Action__c> bankRuleActions;
    public List<Bank_Rule_GLAM__c> bankRuleGLAMs;
    public List<Period_Task__c> periodTasks;
    public List<Exchange_Rate__c> exchangeRateTables;
    public List<Address__c> addressObjects;
    public List<Payment_Processor__c> paymentProcessors;
    public List<BDC_Access_Tokens__c> bdcAccessTokens;
    public List<Bank_Account__c> bankAccounts;
    public List<Payment_Proposal__c> paymentProposals;
    public List<Payment_Proposal_Line__c> paymentProposalLines;

    private static Id personAccountRecordTypeId;
    private static Boolean isPersonAccountsEnabled;   

    public class TestDataSuiteException extends Exception {}

    public static String salesforceUrl = URL.getOrgDomainUrl().toExternalForm();

    public static Boolean isPersonAccountsEnabled() {
        // set to static variable so only one lookup is required
        if (isPersonAccountsEnabled == null) {
            isPersonAccountsEnabled = Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');
        }
        return isPersonAccountsEnabled;
    }

    public static Id getPersonAccountRecordTypeId() {
        // set to static variable so only one lookup is required
        if (isPersonAccountsEnabled() && personAccountRecordTypeId == null) {
            RecordType t = [
                SELECT Id 
                FROM RecordType 
                WHERE Name = 'Person Account' 
                AND SObjectType='Account'];
            personAccountRecordTypeId = t?.Id;
        }
        return personAccountRecordTypeId;
    }

    public static User createTestUser() {
        User testUser = createTestUserImpl();
        insert testUser;
        return testUser;
    }

    private static User createTestUserImpl() {
        User testUser = new User(
            alias = 'testUser',
            email = 'email@fakemail.com',
            emailencodingkey = 'UTF-8',
            lastname = 'TestUser',
            languagelocalekey = Userinfo.getLanguage(),
            localesidkey = Userinfo.getLocale(),
            profileid = UserInfo.getProfileId(),
            timezonesidkey = Userinfo.getTimeZone().getID(),
            username = 'acctseed.test.usernamed@as.com' + DateTime.now().getTime()
        );

        if (UserInfo.isMultiCurrencyOrganization()) {
            List<SObject> corporateCurrency = Database.query('SELECT IsoCode FROM CurrencyType WHERE IsCorporate = true LIMIT 1');
            testUser.put('DefaultCurrencyIsoCode', (String) corporateCurrency[0].get('IsoCode'));
        }

        return testUser;
    }

    private static User createPlatformTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User'];
        User testPlatformUser = new User(
            Alias = 'standt',
            Email = 'acctseed.standarduser@as.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AcctSeedPlatform',
            LanguageLocaleKey = UserInfo.getLanguage(),
            LocaleSidKey = Userinfo.getLocale(),
            ProfileId = p.Id,
            TimeZoneSidKey = Userinfo.getTimeZone().getID(),
            UserName = 'acctseed.standardPlatformUser@testorg.acctseed.com' + DateTime.now().getTime()
        );
        return testPlatformUser;
    }

    private static User createSysAdminTestUser() {
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User sysAdminUser = new User(
            Alias = 'sysAdmin',
            Email = 'sysAdmin.email@fakemail.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AcctSeedSysAdmin',
            LanguageLocaleKey = UserInfo.getLanguage(),
            LocaleSidKey = Userinfo.getLocale(),
            ProfileId = sysAdminProfile.Id,
            TimeZoneSidKey = Userinfo.getTimeZone().getID(),
            Username = 'acctSeed.sysAdmin.username@as.acctseed.com' + DateTime.now().getTime()
        );
        return sysAdminUser;
    }

    public static void addStdFieldsPermissions(Id permissionSetId, Map<SObjectType, List<String>> sobjectToFieldsMap) {
        List<FieldPermissions> stdFieldsPermissions = new List<FieldPermissions>();
        for (SObjectType soType : sobjectToFieldsMap.keySet()) {
            FieldPermissions stdFieldPermission = new FieldPermissions();
            stdFieldPermission.ParentId = permissionSetId;
            stdFieldPermission.SobjectType = String.valueOf(soType);
            stdFieldPermission.PermissionsRead = true;
            for (String fieldToken : sobjectToFieldsMap.get(soType)) {
                stdFieldPermission.Field = fieldToken;
                stdFieldsPermissions.add(stdFieldPermission.clone());
            }
        }
        insert stdFieldsPermissions;
    }

    public static void assignAdminPermissionSet(Id userId) {
        assignAdminPermissionSet(userId, false);
    }

    public static void assignAdminPermissionSet(Id userId, Boolean extendedPermissions) {
        PermissionSet permissionSetClone;
        PermissionSet permissionSet = [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name = 'AS_Full_Admin'
            LIMIT 1
        ];

        if (extendedPermissions) {
            permissionSetClone = clonePermissionSet(permissionSet);
            cloneFieldsPermissions(permissionSet.Id, permissionSetClone.Id);

            TestDataSuite.addStdFieldsPermissions(
                permissionSetClone.Id,
                new Map<SObjectType, List<String>>{
                    Opportunity.SObjectType => new List<String>{
                        'Opportunity.Amount',
                        'Opportunity.Account'
                    },
                    OpportunityLineItem.SObjectType => new List<String>{
                        'OpportunityLineItem.ServiceDate',
                        'OpportunityLineItem.Description',
                        'OpportunityLineItem.Discount',
                        'OpportunityLineItem.ListPrice',
                        'OpportunityLineItem.Subtotal',
                        'OpportunityLineItem.TotalPrice'
                    }
                }
            );
        }

        PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = extendedPermissions ? permissionSetClone.Id : permissionSet.Id
        );

        //prevent duplicates
        List<PermissionSetAssignment> existedPermissionSetAssignments = [
            SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSetId = :(extendedPermissions ? permissionSetClone.Id : permissionSet.Id)
        ];

        if (existedPermissionSetAssignments.isEmpty()) {
            insert permissionSetAssignment;
        }
    }

    public static PermissionSet clonePermissionSet(PermissionSet permissionSetForClone) {
        PermissionSet permissionSetClone = permissionSetForClone.clone(false, true);
        permissionSetClone.Name = 'AS_Full_Admin_Clone';
        permissionSetClone.Label = 'AS Full Admin Clone';

        insert permissionSetClone;
        return permissionSetClone;
    }

    public static void cloneFieldsPermissions(Id permissionSetId, Id clonedPermissionSetId) {
        List<FieldPermissions> fpList = new List<FieldPermissions>();

        for (FieldPermissions fp : [SELECT Id, ParentId, SobjectType, Field, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE ParentId = :permissionSetId]) {
            FieldPermissions clonedFp = fp.clone(false, true);
            clonedFp.ParentId = clonedPermissionSetId;
            fpList.add(clonedFp);
        }

        insert fpList;
    }

    @TestVisible
    private static TestDataSuite instance;

    public static TestDataSuite getInstance() {
        return getInstance(false);
    }

    public static TestDataSuite getInstance(Boolean isBaseInitNeeded) {
        if (instance == NULL) {
            instance = new TestDataSuite(isBaseInitNeeded, true);
        }
        return instance;
    }

    public static TestDataSuite getInstance(Boolean isBaseInitNeeded, Boolean isCreateStandardObjectData) {
        if (instance == NULL) {
            instance = new TestDataSuite(isBaseInitNeeded, isCreateStandardObjectData);
        }
        return instance;
    }

    public static TestDataSuite getInstance(Boolean isBaseInitNeeded, Boolean isCreateStandardObjectData, Boolean includeStandardFieldPerms) {
        if (instance == NULL) {
            instance = new TestDataSuite(isBaseInitNeeded, isCreateStandardObjectData, includeStandardFieldPerms);
        }
        return instance;
    }

    private TestDataSuite(Boolean isBaseInitNeeded) {
        init(isBaseInitNeeded, true, false);
    }

    private TestDataSuite(Boolean isBaseInitNeeded, Boolean isCreateStandardObjectData) {
        init(isBaseInitNeeded, isCreateStandardObjectData, false);
    }

    private TestDataSuite(Boolean isBaseInitNeeded, Boolean isCreateStandardObjectData, Boolean includeStandardFieldPerms) {
        init(isBaseInitNeeded, isCreateStandardObjectData, includeStandardFieldPerms);
    }

    //Create base set of test data
    private void init(Boolean isBaseInitNeeded, Boolean isCreateStandardObjectData, Boolean includeStandardFieldPerms) {
        users = new List<User>();

        if (isBaseInitNeeded) {
            List<User> newUsers = new List<User>();
            adminTestUser = TestDataSuite.createSysAdminTestUser();
            users.add(adminTestUser);
            newUsers.add(adminTestUser);

            currentTestUser = [SELECT Id,Email, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            users.add(currentTestUser);

            platformTestUser = TestDataSuite.createPlatformTestUser();
            users.add(platformTestUser);
            newUsers.add(platformTestUser);

            insert newUsers;
            //split transaction to avoid Mixed DML exception
            System.runAs(users[0]) {
                TestDataSuite.assignAdminPermissionSet(users[1].Id, includeStandardFieldPerms);
            }
            AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT, 25);
            //all test data will be created in the current user context
            //current user is bound with AS_Full_Admin permissions set at this point
            System.runAs(users[1]) {
                createAccountingPeriods();
                createGLAccounts();
                createBillingFormats();
                createLedgers();
                createAccountingSettings();

                if (isCreateStandardObjectData) {
                    createAccounts();
                    createContacts();
                    createOpportunities();
                }
            }
        }
        else {
            adminTestUser = [SELECT Id, Name FROM User WHERE LastName = 'AcctSeedSysAdmin'];
            users.add(adminTestUser);
            currentTestUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            users.add(currentTestUser);
            platformTestUser = [SELECT Id, Name FROM User WHERE LastName = 'AcctSeedPlatform' LIMIT 1];
            users.add(platformTestUser);

            acctPeriods = AccountingPeriodHandler.getInstance().getAllAccountingPeriods();
            glAccounts = [SELECT Id, Name, Type__c, Bank__c, Sub_Type_1__c, Sub_Type_2__c FROM GL_Account__c ORDER BY Id ASC LIMIT 50000];
            billingFormats = [SELECT Id FROM Billing_Format__c ORDER BY Id ASC LIMIT 50000];
            ledgers = [
                SELECT  Id, Type__c, Tax_Settings__c, Default_Bank_Account__c, Default_Billing_Format__c,
                        Billing_Outstanding_Statement_Format__c, Billing_Activity_Statement_Format__c
                FROM Ledger__c ORDER BY Id ASC LIMIT 50000
            ];
            ledgerSettings = Ledger_Custom_Settings__c.getOrgDefaults();
            settings = AccountingSettingsHandler.getAccountingSettings();
            accounts = [
                SELECT  Id,
                        Name,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c
                FROM Account
                ORDER BY Id ASC
                LIMIT 50000
            ];
            taxGroups = [
                SELECT Id, Name, Combined_Tax_Rate__c, Reverse_Charge__c, Tax_Type__c, Tax_Rate_Count__c, Description__c, External_Id2__c
                FROM Tax_Group__c
                LIMIT 50000
            ];
            taxRates = [
                SELECT
                    Id, Name, Tax_Group__c, Tax_Rate__c, Purchase_Tax_Expense_GL_Account__c,
                    Sales_Tax_Liability_GL_Account__c, Tax_Group_External_ID__c, Description__c
                FROM Tax_Rate__c
                LIMIT 50000
            ];
            contacts = [SELECT Id, Name FROM Contact ORDER BY Id ASC LIMIT 50000];
            opportunities = [SELECT Id, Name FROM Opportunity ORDER BY Id ASC LIMIT 50000];
            AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT, 25);
        }
        String permissionName = includeStandardFieldPerms ? 'AS_Full_Admin_Clone' : 'AS_Full_Admin';
        List<PermissionSetAssignment> permissionSetAssignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :users[1].Id
            AND PermissionSetId = :[SELECT Id FROM PermissionSet WHERE Name = :permissionName].Id
        ];
        System.assert(!permissionSetAssignments.isEmpty());
    }

    public static void getOneSecondDelayByDateTime(Datetime startTime) {
        while (System.now().getTime() - startTime.getTime() < 1000) { }
    }

    public static BillingCreateService.BillingModel getBillingModel() {
        BillingCreateService.BillingModel result = new BillingCreateService.BillingModel();
        result.billingDate = Date.newInstance(1991, 10, 12);
        result.dueDate = Date.newInstance(1991, 10, 20);
        result.billingLines = new List<BillingCreateService.BillingLineModel>();
        BillingCreateService.BillingLineModel line = new BillingCreateService.BillingLineModel();
        line.billingLineDate = Date.newInstance(1991, 10, 12);
        line.unitPrice = 10.00;
        line.quantity = 1;
        line.listPrice = 15.00;
        result.billingLines.add(line);
        return result;
    }

    public static Boolean isOpportunityProductStandardFieldAccessible() {
        return OpportunityLineItem.Discount.getDescribe().isAccessible()
                && OpportunityLineItem.TotalPrice.getDescribe().isAccessible()
                && OpportunityLineItem.Subtotal.getDescribe().isAccessible();
    }

    public TestDataSuite enableMultiCurrency() {
        if (UserInfo.isMultiCurrencyOrganization()) {
            try {
                settings.Enable_Multi_Currency__c = true;
                AccountingSettingsActions.isPreventUpdateOverride = true;
                SFDCSecurityUtils.updateProxy(settings);
                AccountingSettingsActions.isPreventUpdateOverride = false;
                AccountingSettingsHandler.resetAccountingSettings();

                List<GL_Account_Default__c> currencyDefs = new List<GL_Account_Default__c>();
                for (Id ledgerId : LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().keySet()) {
                    GL_Account_Default__c def = new GL_Account_Default__c(
                        Ledger__c = ledgerId,
                        GL_Account__c = glAccounts[27].Id,
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT
                    );
                    currencyDefs.add(def);
                }

                SFDCSecurityUtils.insertProxy(currencyDefs);
            }
            catch (Exception ex) {
                throw new TestDataSuiteException('Multi currency is not enabled in this organization');
            }
        }
        else {
            throw new TestDataSuiteException('Multi currency is not enabled in this organization');
        }

        return this;
    }

    public TestDataSuite disableProductCosting() {
        AccountingSettingsHandler.setEnableProductCosting(false);
        return this;
    }

    public TestDataSuite setInventoryValuationStandardCost() {
        AccountingSettingsHandler.getAccountingSettings().Inventory_Variance_GL_Account__c = glAccounts[13].Id;
        GL_Account_Default__c inventoryDef = new GL_Account_Default__c(
            GL_Account_Specification__c = GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT,
            GL_Account__c = glAccounts[13].Id,
            Ledger__c = ledgers[0].Id
        );
        insert inventoryDef;
        AccountingSettingsHandler.setInventoryValuationStandardCost();
        return this;
    }

    public TestDataSuite setInventoryValuationAverageCost() {
        AccountingSettingsHandler.setInventoryValuationAverageCost();
        return this;
    }

    public TestDataSuite setERPEnabled() {
        AccountingSettingsHandler.setIsERPEnabled(true);
        return this;
    }

    public TestDataSuite setERPDisabled() {
       AccountingSettingsHandler.setIsERPEnabled(false);
       return this;
    }

    public TestDataSuite setNPSPEnabled() {
        AccountingSettingsHandler.setIsNPSPEnabled(true);
        return this;
    }

    public TestDataSuite setNPSPDisabled() {
       AccountingSettingsHandler.setIsNPSPEnabled(false);
       return this;
    }

    public TestDataSuite setGlobalAutomatedMatchEnabled() {
        AccountingSettingsHandler.setGlobalAutomatedMatch(true);
        return this;
    }

    public TestDataSuite setCashInDefaultMatchingSetting(Integer days) {
        AccountingSettingsHandler.setCashInDefaultMatchingSetting(days);
        return this;
    }

    public TestDataSuite setCashInDefaultSourceRecordType(String sourceRecordName) {
        AccountingSettingsHandler.setCashInDefaultSourceRecordType(sourceRecordName);
        return this;
    }

    public TestDataSuite setCashOutDefaultMatchingSetting(Integer days) {
        AccountingSettingsHandler.setCashOutDefaultMatchingSetting(days);
        return this;
    }

    public TestDataSuite setCashOutDefaultSourceRecordType(String sourceRecordName) {
        AccountingSettingsHandler.setCashOutDefaultSourceRecordType(sourceRecordName);
        return this;
    }

    public TestDataSuite enablePrePopulateAccountInfo() {
        Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
        settings.Pre_Populate_Account_Info__c = true;
        AccountingSettingsHandler.updateSettingsAndReset();
        return this;
    }

    public TestDataSuite setCreditMemoDefaultAmount() {
        AccountingSettingsHandler.setCreditMemoDefault(AccountingSettingsHandler.AMOUNT_VALUE);
        return this;
    }

    public TestDataSuite setCreditMemoDefaultQuantity() {
        AccountingSettingsHandler.setCreditMemoDefault(AccountingSettingsHandler.QUANTITY_VALUE);
        return this;
    }

    public TestDataSuite enableLDVMode() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.LARGE_DATA_VOLUME_MODE, true);
        return this;
    }

    public TestDataSuite disableLDVMode() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.LARGE_DATA_VOLUME_MODE, false);
        return this;
    }

    public TestDataSuite setAvaVATSelected() {
        System.runAs(users[1]) {
            if (!AccountingSettingsHandler.isAvaVATReportingEnabled()) {
                AccountingSettingsHandler.setIsAvaVATInstalled(true);
                AccountingSettingsHandler.setIsAvaVATReportingEnabled(true);
                
                List<GL_Account__c> inputOutputGLAccounts = new List<GL_Account__c>();
                // 31
                inputOutputGLAccounts.add(
                    new GL_Account__c(
                        Name = 'Input VAT GL Account',
                        Active__c = true,
                        Bank__c = false,
                        Type__c = 'Balance Sheet',
                        Sub_Type_1__c = 'Liabilities',
                        Sub_Type_2__c = 'Current Liabilities',
                        GL_Category__c = 'Input VAT'
                    )
                );

                // 32
                inputOutputGLAccounts.add(
                    new GL_Account__c(
                        Name = 'Output VAT GL Account',
                        Active__c = true,
                        Bank__c = false,
                        Type__c = 'Balance Sheet',
                        Sub_Type_1__c = 'Liabilities',
                        Sub_Type_2__c = 'Current Liabilities',
                        GL_Category__c = 'Output VAT'
                    )
                );

                insert inputOutputGLAccounts;
                glAccounts.addAll(inputOutputGLAccounts);

                if (taxGroups == NULL || taxGroups.size() == 0) {
                    createTaxGroups();
                }

                List<Tax_Group__c> vatTaxGroups = new List<Tax_Group__c>();

                // 3
                vatTaxGroups.add(
                    new Tax_Group__c(
                        Name = 'PurchaseTaxGroupReverseCharge',
                        Tax_Type__c = 'Sales and Purchase',
                        External_Id2__c = 'TestExternalID123456789',
                        Reverse_Charge__c = true
                    )
                );
                    
                // 4
                vatTaxGroups.add(
                    new Tax_Group__c(
                        Name = 'PurchaseTaxGroupReverseCharge',
                        Tax_Type__c = 'Sales and Purchase',
                        External_Id2__c = 'TestExternalID1234567890'
                    )
                );

                insert vatTaxGroups;
                taxGroups.addAll(vatTaxGroups);

                List<Tax_Rate__c> vatTaxRates = new List<Tax_Rate__c>();
                vatTaxRates.add(
                    new Tax_Rate__c(
                        Name = 'PurchaseReverseCharge',
                        Tax_Group__c = vatTaxGroups[0].Id,
                        Tax_Rate__c = 20,
                        Sales_Tax_Liability_GL_Account__c = inputOutputGLAccounts[1].Id,
                        Purchase_Tax_Expense_GL_Account__c = inputOutputGLAccounts[0].Id
                    )
                );

                vatTaxRates.add(
                    new Tax_Rate__c(
                        Name = 'PurchaseReverseCharge',
                        Tax_Group__c = vatTaxGroups[1].Id,
                        Tax_Rate__c = 20,
                        Sales_Tax_Liability_GL_Account__c = inputOutputGLAccounts[1].Id,
                        Purchase_Tax_Expense_GL_Account__c = inputOutputGLAccounts[0].Id
                    )
                );

                insert vatTaxRates;
                taxRates.addAll(vatTaxRates);

                AccountingSettingsHandler.resetAccountingSettings();
            }
        }
        return this;
    }

    public TestDataSuite setAvaVATReportingEnabled() {
        AccountingSettingsHandler.setIsAvaVATInstalled(true);             // vat reporting installed
        AccountingSettingsHandler.setIsAvaVATReportingEnabled(true);    // vat retporting enabled in accounting settings
        return this;
    }

    public TestDataSuite setAvaVATReportingDisabled() {
       AccountingSettingsHandler.setIsAvaVATInstalled(false);
       AccountingSettingsHandler.setIsAvaVATReportingEnabled(false);
       return this;
    }

    public TestDataSuite disableAutoPostSourceDocuments() {
        AccountingSettingsHandler.setAutoPostSourceDocuments(false);
        return this;
    }

    public TestDataSuite enableAutoPostSourceDocuments() {
        AccountingSettingsHandler.setAutoPostSourceDocuments(true);
        return this;
    }

    public TestDataSuite setHeaderLevelPost() {
        AccountingSettingsHandler.setHeaderLevelPost();
        return this;
    }

    public TestDataSuite setLineLevelPost() {
        AccountingSettingsHandler.setLineLevelPost();
        return this;
    }

    private void createAccountingPeriods() {
        acctPeriods = new List<Accounting_Period__c>();

        // 0
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1991-10',
                Start_Date__c = Date.newInstance(1991, 10, 1),
                End_Date__c = Date.newInstance(1991, 10, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        // 1
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1991-11',
                Start_Date__c = Date.newInstance(1991, 11, 1),
                End_Date__c = Date.newInstance(1991, 11, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        // 2
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1991-12',
                Start_Date__c = Date.newInstance(1991, 12, 1),
                End_Date__c = Date.newInstance(1991, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        // 3
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1992-01',
                Start_Date__c = Date.newInstance(1992, 1, 1),
                End_Date__c = Date.newInstance(1992, 1, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        // 4
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1992-02',
                Start_Date__c = Date.newInstance(1992, 2, 1),
                End_Date__c = Date.newInstance(1992, 2, 29),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        //5 - FR
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1992-03',
                Start_Date__c = Date.newInstance(1992, 3, 1),
                End_Date__c = Date.newInstance(1992, 3, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        //6 - FR
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '1992-04',
                Start_Date__c = Date.newInstance(1992, 4, 1),
                End_Date__c = Date.newInstance(1992, 4, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        insert acctPeriods;
    }

    private void createBillingFormats() {
        billingFormats = new List<Billing_Format__c>();
        EmailTemplate defaultTemplate = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1];
        // 0
        billingFormats.add(
            new Billing_Format__c(
                Name = 'Default Billing Product',
                Visualforce_PDF_Page__c = 'BillingProductPDF',
                Default_Email_Template__c = defaultTemplate.DeveloperName,
                Type__c = 'Billing',
                Sort_Field__c = 'Name'
            )
        );
        // 1
        billingFormats.add(
            new Billing_Format__c(
                Name = 'Default Billing Service',
                Visualforce_PDF_Page__c = 'BillingServicePDF',
                Default_Email_Template__c = defaultTemplate.DeveloperName,
                Type__c = 'Billing',
                Sort_Field__c = 'Name'
            )
        );
        // 2
        billingFormats.add(
            new Billing_Format__c (
                Name = 'Default Billing Outstanding Statement',
                Visualforce_PDF_Page__c = 'BillingOutstandingStatementPDF',
                Default_Email_Template__c = defaultTemplate.DeveloperName,
                ReplyTo_Email__c = 'test3463464364646@gmail.com',
                Type__c = 'Outstanding Statement'
            )
        );
        // 3
        billingFormats.add(
            new Billing_Format__c (
                Name = 'Default Billing Activity Statement',
                Visualforce_PDF_Page__c = 'BillingActivityStatementPDF',
                Default_Email_Template__c = defaultTemplate.DeveloperName,
                ReplyTo_Email__c = 'test3463464364646@gmail.com',
                Type__c = 'Activity Statement'
            )
        );
        // 4
        billingFormats.add(
            new Billing_Format__c (
                Name = 'Default Purchase Order',
                Visualforce_PDF_Page__c = 'BillingServicePDF',
                Default_Email_Template__c = defaultTemplate.DeveloperName,
                Type__c = 'Purchase Order',
                Sort_Field__c = 'Name'
            )
        );
        // 5
        billingFormats.add(
            new Billing_Format__c (
                Name = 'Default Packing Slip',
                Visualforce_PDF_Page__c = 'BillingServicePDF',
                Default_Email_Template__c = defaultTemplate.DeveloperName,
                Type__c = 'Packing Slip',
                Sort_Field__c = 'Name'
            )
        );

        insert billingFormats;
    }

    private void createLedgers() {
        ledgers = new List<Ledger__c>();

        if (addressObjects == null) {
            createAddressObjects();
        }
        if (products == null) {
            createProducts();
        }

        Tax_Settings__c taxSetting = new Tax_Settings__c();
        taxSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
        taxSetting.Origin_Address__c = addressObjects[0].Id;
        taxSetting.Sales_Tax_GL_Account__c = glAccounts[28].Id;
        taxSetting.Sales_Tax_Product__c = products[5].Id;
        taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
        taxSetting.Tax_Rounding_Threshold__c = '0.02';
        insert taxSetting;

        ledgers.add(
            new Ledger__c(
                Name = 'Actual',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                Type__c = 'Transactional',
                Default_Bank_Account__c = glAccounts[0].Id,
                Default_Billing_Format__c = billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );

        ledgers.add(
            new Ledger__c(
                Name = 'Budget',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                Type__c = 'Budget'
            )
        );

        ledgers.add(
            new Ledger__c(
                Name = 'Actual 2',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                Type__c = 'Transactional',
                Default_Bank_Account__c = glAccounts[0].Id,
                Default_Billing_Format__c = billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );

        ledgers.add(
            new Ledger__c(
                Name = 'Actual 3',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_CASH,
                Type__c = 'Transactional',
                Default_Bank_Account__c = glAccounts[0].Id,
                Default_Billing_Format__c = billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );

        ledgers.add(
            new Ledger__c(
                Name = 'Actual 4',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH,
                Type__c = 'Transactional',
                Default_Bank_Account__c = glAccounts[0].Id,
                Default_Billing_Format__c = billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );

        if (AccountingSettingsHandler.isERPEnabled()) {
            ledgers[0].Default_Purchase_Order_Format__c = billingFormats[4].Id;
            ledgers[2].Default_Purchase_Order_Format__c = billingFormats[4].Id;
            ledgers[3].Default_Purchase_Order_Format__c = billingFormats[4].Id;
            ledgers[4].Default_Purchase_Order_Format__c = billingFormats[4].Id;
            ledgers[0].Default_Packing_Slip_Format__c = billingFormats[5].Id;
            ledgers[2].Default_Packing_Slip_Format__c = billingFormats[5].Id;
            ledgers[3].Default_Packing_Slip_Format__c = billingFormats[5].Id;
            ledgers[4].Default_Packing_Slip_Format__c = billingFormats[5].Id;
        }

        insert ledgers;

        ledgerSettings = new Ledger_Custom_Settings__c(Ledger_Id__c = ledgers[0].Id);

        insert ledgerSettings;
    }

    public TestDataSuite createLedgerWithPaymentEnabled() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        System.runAs(users.get(1)) {

        ledgers = new List<Ledger__c>();

        if (addressObjects == null) {
            createAddressObjects();
        }
        if (products == null) {
            createProducts();
        }

        Address__c address = [SELECT Id,City__c FROM Address__c WHERE City__c = 'Odessa'][0];

        Tax_Settings__c taxSetting = new Tax_Settings__c();
        taxSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
        taxSetting.Origin_Address__c =address.Id;
        taxSetting.Sales_Tax_GL_Account__c = glAccounts[28].Id;
        taxSetting.Sales_Tax_Product__c = products[5].Id;
        taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
        taxSetting.Tax_Rounding_Threshold__c = '0.02';
        insert taxSetting;

        ledgers.add(
            new Ledger__c(
                Name = 'Actual',
                Type__c = 'Transactional',
                Default_Bank_Account__c = glAccounts[0].Id,
                Address__c = addressObjects[0].Id,
                Enrolled_in_Payment_Services__c = true,
                Default_Billing_Format__c = billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );


        insert ledgers;
    }

        return this;
    }

    private void createGLAccounts() {
        glAccounts = new List<GL_Account__c>();
        // 0
        glAccounts.add(
            new GL_Account__c(
                Name = '1000-Cash',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = true,
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Cash'
            )
        );

        // 1
        glAccounts.add(
            new GL_Account__c(
                Name = '1205-Unapplied A/R',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Cash'
            )
        );

        // 2
        glAccounts.add(
            new GL_Account__c(
                Name = '1200-Accounts Receivable',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );

        // 3
        glAccounts.add(
            new GL_Account__c(
                Name = '1600-Work In Process',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );

        // 4
        glAccounts.add(
            new GL_Account__c(
                Name = '2000-Accounts Payable',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );

        // 5
        glAccounts.add(
            new GL_Account__c(
                Name = '2010-Vouchers Payable',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );

        // 6
        glAccounts.add(
            new GL_Account__c(
                Name = '2020-Accrued Expenses',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );


        // 7
        glAccounts.add(
            new GL_Account__c(
                Name = '3000-Owners Equity',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'
            )
        );

        // 8
        glAccounts.add(
            new GL_Account__c(
                Name = '3050-Retained Earnings',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'
            )
        );

        // 9
        glAccounts.add(
            new GL_Account__c(
                Name = '3060-Current Year Earnings',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'
            )
        );

        // 10
        glAccounts.add(
            new GL_Account__c(
                Name = '4000-Product Revenue',
                Active__c = true,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Product Revenue',
                Sub_Type_2__c = 'Product Family 1'
            )
        );

        // 11
        glAccounts.add(
            new GL_Account__c(
                Name = '4010-Services Revenue',
                Active__c = true,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Service Revenue',
                Sub_Type_2__c = 'Service Family 1'
            )
        );

        // 12
        glAccounts.add(
            new GL_Account__c(
                Name = '5000-Cost of Goods Sold',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Cost of Goods Sold',
                Sub_Type_2__c = 'Materials'
            )
        );

        // 13
        glAccounts.add(
            new GL_Account__c(
                Name = '5010-Inventory Cost Variance',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Cost of Goods Sold',
                Sub_Type_2__c = 'Materials'
            )
        );

        // 14
        glAccounts.add(
            new GL_Account__c(
                Name = '5040-Vendor Payment Discounts',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Cost of Goods Sold',
                Sub_Type_2__c = 'Materials'
            )
        );

        // 15
        glAccounts.add(
            new GL_Account__c(
                Name = '5050-Labor',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Labor',
                Sub_Type_2__c = 'Salary & Wages'
            )
        );

        // 16
        glAccounts.add(
            new GL_Account__c(
                Name = '6000-Marketing Expense',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Sales & Marketing',
                Sub_Type_2__c = 'Marketing Events'
            )
        );

        // 17
        glAccounts.add(
            new GL_Account__c(
                Name = '7000-Facilities Expense',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Facilities',
                Sub_Type_2__c = 'Rent'
            )
        );

        // 18
        glAccounts.add(
            new GL_Account__c(
                Name = '7050-Telecommunications',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Facilities',
                Sub_Type_2__c = 'Utilities'
            )
        );

        // 19
        glAccounts.add(
            new GL_Account__c(
                Name = 'zLabor Clearing',
                Active__c = true,
                Type__c = 'Expense'
            )
        );

        // 20
        glAccounts.add(
            new GL_Account__c(
                Name = 'zProject Labor',
                Active__c = true,
                Type__c = 'Expense'
            )
        );

        // 21
        glAccounts.add(
            new GL_Account__c(
                Name = '4900-Customer Payment Discounts',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Product Revenue',
                Sub_Type_2__c = 'Product Family 1'
            )
        );

        // 22
        glAccounts.add(
            new GL_Account__c(
                Name = '1500-Inventory',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );

        // 23
        glAccounts.add(
            new GL_Account__c(
                Name = '1400-Prepaid Expenses',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );
        // 24
        glAccounts.add(
            new GL_Account__c(
                Name = '1700-Accumulated Depreciation',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Fixed Assets'
            )
        );
        // 25
        glAccounts.add(
            new GL_Account__c(
                Name = '2500-Deferred Revenue',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );
        // 26
        glAccounts.add(
            new GL_Account__c(
                Name = '3900-Opening Balances',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'
            )
        );
        // 27
        glAccounts.add(
            new GL_Account__c(
                Name = '6500-Depreciation Expense',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Expense',
                Sub_Type_1__c = 'General & Administrative',
                Sub_Type_2__c = 'Software'
            )
        );
        // 28
        glAccounts.add(
            new GL_Account__c(
                Name = 'Avalara GL Account',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );
        //29
        glAccounts.add(
            new GL_Account__c(
                Name = '1001-Cash2',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = true,
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Cash'
            )
        );
        //30
        glAccounts.add(
            new GL_Account__c(
                Name = '2030-Accrued Payroll',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = false,
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );
        //31
        glAccounts.add(
            new GL_Account__c(
                Name = '1450-Deferred Expenses',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = false,
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );

        insert glAccounts;
    }

    public TestDataSuite createFRGLAccounts() {

        List<GL_Account__c> result = new List<GL_Account__c>();

        // 29 Use for FR Test
        result.add(
            new GL_Account__c(
                Name = '1000-Bank of America Account 5347',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = true,
                Sub_Type_1__c = 'Assets'
            )
        );
        // 30 Use for FR Test
        result.add(
            new GL_Account__c(
                Name = '5000-Labor',
                Active__c = true,
                Type__c = 'Expense',
                Bank__c = true
            )
        );
        // 31 Use for FR Test
        result.add(
            new GL_Account__c(
                Name = '6010-Mileage',
                Active__c = true,
                Type__c = 'Expense',
                Used_In_Expense_Reports__c = true,
                Mileage_Account__c = true,
                Mileage_Rate__c = .5
            )
        );
        // 32 Use for FR Test
        result.add(
            new GL_Account__c(
                Name = '4000-Consulting Revenue',
                Active__c = true,
                Type__c = 'Revenue'
            )
        );
        // 33 Use for FR Test
        result.add(
            new GL_Account__c(
                Name = '2000-Accounts Payable',
                Active__c = true,
                Type__c = 'Revenue'
            )
        );

        insert result;
        glAccounts.addAll(result);

        return this;
    }

    private void createAccountingSettings() {
        settings = new Accounting_Settings__c(
            Labor_GL_Account__c = glAccounts[19].Id,
            Payment_Discount_GL_Account__c = glAccounts[14].Id,
            Default_Ledger__c = ledgers[0].Id,
            Default_Project_Task_Labor_GL_Account__c = glAccounts[20].Id,
            Enable_Product_Costing__c = true,
            Work_in_Process_GL_Account__c = glAccounts[3].Id,
            Vouchers_Payable_GL_Account__c = glAccounts[5].Id,
            Customer_Payment_Adjustment_GL_Account__c = glAccounts[21].Id,
            Display_Billable_Flag_in_Time_Card_Entry__c = true,
            Enable_Billing_Period_Sensitive_Aging__c = true,
            Enable_AP_Period_Sensitive_Aging__c = true,
            Prepaid_Expense_GL_Account__c = glAccounts[23].Id,
            Legacy_Default_Ledger__c = ledgers[0].Id,
            Default_Credit_GL_Account_Expense__c = glAccounts[27].Id,
            Default_Credit_GL_Account_Revenue__c = glAccounts[10].Id,
            Default_Debit_GL_Account_Revenue__c = glAccounts[23].Id,
            Hub_UserName__c = 'abc@gmail.com'
        );

        insert settings;
    }

    public void createAccounts() {
        accounts = new List<Account>();
        accounts.add(
            new Account(
                Name = 'Test Account',
                Credit_Card_Vendor__c = true
            )
        );

        accounts.add(
            new Account(
                Name = 'Acme Account',
                Credit_Card_Vendor__c = true
            )
        );
        
        accounts.add(
            new Account(
                Name = 'Accounting Seed',
                Accounting_Active__c = true,
                Accounting_Type__c = 'Customer & Vendor',
                BillingStreet = '999 Billing Street',
                BillingCity = 'BillingCity',
                BillingState = 'CA',
                BillingPostalCode = '94104',
                BillingCountry = 'US',
                ShippingStreet = '888 Shipping Street',
                ShippingCity = 'ShippingCity',
                ShippingState = 'CA',
                ShippingPostalCode = '90100',
                ShippingCountry = 'US'
            )
        );

        insert accounts;
    }

    public TestDataSuite createPersonAccounts() {
        if (isPersonAccountsEnabled()) {
            System.runAs(users[1]) {
                personAccounts = new List<Account>();

                Map<String,Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();

                Account personAccount = new Account(
                    Accounting_Type__c = 'Customer & Vendor',
                    Accounting_Active__c = true
                );
                // Check Person Account fields exist.
                // The code will not deply if we reference Person Account fields 
                // in a non-Person Account org.
                if (fields.get('RecordTypeId') != null) {
                    personAccount.put('RecordTypeId', getPersonAccountRecordTypeId());
                }
                if (fields.get('FirstName') != null) {
                    personAccount.put('FirstName', 'Accounting');
                }
                if (fields.get('LastName') != null) {
                    personAccount.put('LastName', 'Seed');
                }

                personAccounts.add(
                    personAccount
                );

                insert personAccounts;
            }
        }
        return this;
    }

    public void createContacts() {
        contacts = new List<Contact>();
        contacts.add(
            new Contact(
                FirstName = 'John',
                LastName = 'Doe',
                AccountId = accounts[0].Id
            )
        );

        contacts.add(
            new Contact(
                FirstName = 'Jane',
                LastName = 'Doe',
                AccountId = accounts[0].Id
            )
        );

        contacts.add(
            new Contact(
                FirstName = 'Mike',
                LastName = 'Black',
                AccountId = accounts[1].Id
            )
        );

        insert contacts;
    }

    public TestDataSuite createPayables() {
        return createPayables(false);
    }

    public TestDataSuite createPayables(Boolean doPost) {
        System.runAs(users[1]) {
            payables = new List<Account_Payable__c>();
            //0
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[0].Start_Date__c,
                    Due_Date__c = acctPeriods[0].End_Date__c,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //1
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '234sdfigojjnklsndlfg',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[0].Start_Date__c,
                    Due_Date__c = acctPeriods[0].End_Date__c,
                    Contact__c = contacts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //2
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345dfgjpdfkgjdklfgjdfklgfd',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[0].Start_Date__c,
                    Due_Date__c = acctPeriods[0].End_Date__c,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = acctPeriods[0].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //3
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '23453456345345345345435345345345345345345345',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[1].Start_Date__c,
                    Due_Date__c = acctPeriods[1].End_Date__c,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = acctPeriods[1].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //4
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '234534563453453453454353453453453453trewtre',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[1].Start_Date__c,
                    Due_Date__c = acctPeriods[1].End_Date__c,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[1].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //5
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '234534563453453453454353453453453453treasdfsdfasdfsadfsdfeswtre',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[1].Start_Date__c,
                    Due_Date__c = acctPeriods[1].End_Date__c,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[1].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //6
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfhhfsoinuy',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[0].Start_Date__c,
                    Due_Date__c = acctPeriods[0].End_Date__c,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Ledger__c = ledgers[0].Id
                )
            );
            //7
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfhhfssgasdgsddsoinuy',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriods[0].Start_Date__c,
                    Due_Date__c = acctPeriods[0].End_Date__c,
                    Vendor__c = accounts[0].Id,
                    Discount_Amount__c = 0,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Ledger__c = ledgers[0].Id
                )
            );

            insert payables;

            payableLines = new List<Account_Payable_Line__c>();
            //0
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[0].Id,
                    Amount__c = 45,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //1
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[0].Id,
                    Amount__c = 55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //2
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[0].Id,
                    Amount__c = 65,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //3
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[1].Id,
                    Amount__c = 45,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //4
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[1].Id,
                    Amount__c = 55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //5
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[1].Id,
                    Amount__c = 60,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //6
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[2].Id,
                    Amount__c = 45,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //7
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[2].Id,
                    Amount__c = 55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //8
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[2].Id,
                    Amount__c = 55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //9
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[3].Id,
                    Amount__c = 55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //10
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[3].Id,
                    Amount__c = 55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //11
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[4].Id,
                    Amount__c = -55,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //12
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[5].Id,
                    Amount__c = 120,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //13
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[6].Id,
                    Amount__c = 0,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );
            //14
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[7].Id,
                    Amount__c = 100,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = glAccounts[16].Id
                )
            );

            insert payableLines;

            if (doPost) {
                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(this.payables);
                System.assertEquals(true, postResults[0].isSuccess);
            }
        }

        return this;
    }

    public TestDataSuite createBillings() {
        return createBillings(false);
    }

    public TestDataSuite createBillings(Boolean doPost) {
        System.runAs(users[1]) {
            billings = new List<Billing__c>();
            // 0
            billings.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = acctPeriods[0].End_Date__c+3,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Customer__c = accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Billing_Format__c = billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30,
                    Billing_Street__c = '999 Billing Street',
                    Billing_City__c = 'BillingCity',
                    Billing_State__c = 'CA',
                    Billing_Country__c = 'US',
                    Billing_PostalCode__c = '94104',
                    Shipping_Street__c = '888 Shipping Street',
                    Shipping_City__c = 'ShippingCity',
                    Shipping_State__c = 'CA',
                    Shipping_Country__c = 'US',
                    Shipping_PostalCode__c = '90100'
                )
            );
            // 1
            billings.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = acctPeriods[0].End_Date__c+3,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Customer__c = accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Billing_Format__c = billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30
                )
            );
            // 2
            billings.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = acctPeriods[0].End_Date__c+3,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Customer__c = accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Billing_Format__c = billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30
                )
            );
            // 3
            billings.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = acctPeriods[0].End_Date__c+3,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Customer__c = accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Billing_Format__c = billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30
                )
            );
            // 4
            billings.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = acctPeriods[0].End_Date__c+3,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Customer__c = accounts[0].Id,
                    Status__c = 'Approved',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Billing_Format__c = billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30
                )
            );

            insert billings;

            billingLines = new List<Billing_Line__c>();
            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[0].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[0].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 25,
                    Rate__c = 10,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[1].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[1].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 25,
                    Rate__c = 10,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[2].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = -25,
                    Rate__c = 10,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[3].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = -25,
                    Rate__c = 10,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[4].Id,
                    Date__c = acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 0,
                    Rate__c = 1,
                    Revenue_GL_Account__c = glAccounts[10].Id
                )
            );

            insert billingLines;

            if (doPost) {
                AbstractPostHandler postHandler = new BillingPostHandler();
                List<PostResult> postResults = postHandler.post(this.billings);
                System.assertEquals(true, postResults[0].isSuccess);
            }
        }

        return this;
    }

    public TestDataSuite createCashDisbursementBatches() {
        System.runAs(users[1]) {
            cashDisbursementBatch = new List<Cash_Disbursement_Batch__c>();
            cashDisbursementBatch.add(
                new Cash_Disbursement_Batch__c(
                    Starting_Check_Number__c = 1,
                    Name = 'Test Batch'
                )
            );

            cashDisbursementBatch.add(
                new Cash_Disbursement_Batch__c(
                    Starting_Check_Number__c = 2,
                    Name = 'Test Batch 2'
                )
            );

            insert cashDisbursementBatch;
        }
        return this;
    }

    public TestDataSuite createCashDisbursements() {
        return createCashDisbursements(false);
    }

    public TestDataSuite createCashDisbursements(Boolean doPost) {
        System.runAs(users[1]) {

            System.assertNotEquals(NULL, cashDisbursementBatch, 'CDBs must be created first.');
            System.assertNotEquals(true, cashDisbursementBatch.isEmpty(), 'CDBs must be created first.');

            cashDisbursements = new List<Cash_Disbursement__c>();
            //0
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Amount__c = 0,
                    Source__c = 'Payable',
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[4].Id,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 0'
                )
            );
            //1
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Amount__c = 0,
                    Source__c = 'Payable',
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[4].Id,
                    Contact__c = contacts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 2'
                )
            );
            //2
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Amount__c = 0,
                    Source__c = 'Payable',
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[4].Id,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 3'
                )
            );
            //3
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[1].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Amount__c = 0,
                    Source__c = 'Payable',
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[4].Id,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 4'
                )
            );
            //4
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[1].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Source__c = 'Manual',
                    Amount__c = 50,
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[23].Id,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 5'
                )
            );
            //5
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[1].Id,
                    Disbursement_Date__c = acctPeriods[1].Start_Date__c,
                    Type__c = 'Check',
                    Source__c = 'Manual',
                    Amount__c = 60,
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[23].Id,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[1].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 6'
                )
            );
            //6
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[1].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Source__c = 'Manual',
                    Amount__c = 210,
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[23].Id,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 6'
                )
            );
            //7
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[1].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Source__c = 'Manual',
                    Amount__c = 0,
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[23].Id,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 7'
                )
            );
            //8
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[1].Id,
                    Disbursement_Date__c = acctPeriods[0].Start_Date__c,
                    Type__c = 'Check',
                    Amount__c = 100,
                    Bank_Account__c = glAccounts[0].Id,
                    Debit_GL_Account__c = glAccounts[23].Id,
                    Vendor__c = accounts[0].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Reference__c = 'the reference 8'
                )
            );
            insert cashDisbursements;

            if (doPost) {
                AbstractPostHandler postHandler = new CashDisbursementPostHandler();
                List<PostResult> postResults = postHandler.post(this.cashDisbursements);
                System.assertEquals(true, postResults[0].isSuccess);
            }
        }

        return this;
    }

    public TestDataSuite createApDisbursements() {
        System.runAs(users[1]) {
            apDisbursements = new List<AP_Disbursement__c>();
            //0
            apDisbursements.add(
                new AP_Disbursement__c(
                    Account_Payable__c = payables[0].Id,
                    Cash_Disbursement__c = cashDisbursements[0].Id,
                    Paid_Amount__c = 10
                )
            );
            //1
            apDisbursements.add(
                new AP_Disbursement__c(
                    Account_Payable__c = payables[1].Id,
                    Cash_Disbursement__c = cashDisbursements[1].Id,
                    Paid_Amount__c = 20
                )
            );
            //2
            apDisbursements.add(
                new AP_Disbursement__c(
                    Account_Payable__c = payables[2].Id,
                    Cash_Disbursement__c = cashDisbursements[2].Id,
                    Paid_Amount__c = 30
                )
            );
            //3
            apDisbursements.add(
                new AP_Disbursement__c(
                    Account_Payable__c = payables[5].Id,
                    Cash_Disbursement__c = cashDisbursements[5].Id,
                    Paid_Amount__c = 60
                )
            );
            //4
            apDisbursements.add(
                new AP_Disbursement__c(
                    Account_Payable__c = payables[2].Id,
                    Cash_Disbursement__c = cashDisbursements[4].Id,
                    Paid_Amount__c = 45
                )
            );
            //5
            apDisbursements.add(
                new AP_Disbursement__c(
                    Account_Payable__c = payables[7].Id,
                    Cash_Disbursement__c = cashDisbursements[8].Id,
                    Paid_Amount__c = 100
                )
            );
            insert apDisbursements;
        }
        return this;
    }

    public TestDataSuite createAPAgingHistories() {
        System.runAs(users.get(1)) {
            apAgingHistories = new List<AP_Aging_History__c>();

            apAgingHistories.add(
                new AP_Aging_History__c(
                    Accounting_Period__c = acctPeriods.get(2).Id,
                    Account_Payable__c = payables.get(0).Id,
                    Amount__c = 27.60
                )
            );

            apAgingHistories.add(
                new AP_Aging_History__c(
                    Accounting_Period__c = acctPeriods.get(0).Id,
                    Account_Payable__c = payables.get(0).Id,
                    Amount__c = 37.60
                )
            );

            apAgingHistories.add(
                new AP_Aging_History__c(
                    Accounting_Period__c = acctPeriods.get(4).Id,
                    Account_Payable__c = payables.get(0).Id,
                    Amount__c = 47.60
                )
            );

            insert apAgingHistories;
        }

        return this;
    }

    public TestDataSuite createAccountingVariables() {
        System.runAs(users.get(1)) {
            accountingVariables1 = new List<Accounting_Variable__c>();

            accountingVariables1.add(
                new Accounting_Variable__c(
                    Name = 'Sales',
                    Active__c = true,
                    Type__c = 'GL Account Variable 1'
                )
            );

            accountingVariables1.add(
                new Accounting_Variable__c(
                    Name = 'Marketing',
                    Active__c = true,
                    Type__c = 'GL Account Variable 1'
                )
            );

            insert accountingVariables1;

            //Set up Accounting Variables 2
            accountingVariables2 = new List<Accounting_Variable__c>();

            accountingVariables2.add(
                new Accounting_Variable__c(
                    Name = 'Northeast Division',
                    Active__c = true,
                    Type__c = 'GL Account Variable 2'
                )
            );

            accountingVariables2.add(
                new Accounting_Variable__c(
                    Name = 'Central Division',
                    Active__c = true,
                    Type__c = 'GL Account Variable 2'
                )
            );

            insert accountingVariables2;

            //Set up Accounting Variables 3
            accountingVariables3 = new List<Accounting_Variable__c>();

            accountingVariables3.add(
                new Accounting_Variable__c(
                    Name = 'Executive',
                    Active__c = true,
                    Type__c = 'GL Account Variable 3'
                )
            );

            accountingVariables3.add(
                new Accounting_Variable__c(
                    Name = 'Administrative',
                    Active__c = true,
                    Type__c = 'GL Account Variable 3'
                )
            );

            insert accountingVariables3;

            //Set up Accounting Variables 4
            accountingVariables4 = new List<Accounting_Variable__c>();

            accountingVariables4.add(
                new Accounting_Variable__c(
                    Name = 'USA',
                    Active__c = true,
                    Type__c = 'GL Account Variable 4'
                )
            );

            accountingVariables4.add(
                new Accounting_Variable__c(
                    Name = 'Canada',
                    Active__c = true,
                    Type__c = 'GL Account Variable 4'
                )
            );

            insert accountingVariables4;
        }

        return this;
    }

    public TestDataSuite createCashReceipts() {
        System.runAs(users.get(1)) {
            cashReceipts = new List<Cash_Receipt__c>();
            //0
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accounts.get(0).Id,
                    Amount__c = 400,
                    Payment_Reference__c = '0000000432',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriods.get(1).Start_Date__c,
                    Accounting_Period__c = acctPeriods.get(1).Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccounts.get(0).Id,
                    Credit_GL_Account__c = glAccounts.get(1).Id
                )
            );
            //1
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accounts.get(0).Id,
                    Amount__c = 500,
                    Payment_Reference__c = '0000000432',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriods.get(1).Start_Date__c,
                    Accounting_Period__c = acctPeriods.get(1).Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccounts.get(0).Id
                )
            );
            //2
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accounts.get(0).Id,
                    Amount__c = 300,
                    Payment_Reference__c = '0000000432',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriods.get(0).Start_Date__c,
                    Accounting_Period__c = acctPeriods.get(0).Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccounts.get(0).Id
                )
            );

            insert cashReceipts;
        }

        return this;
    }

    public TestDataSuite createBillingAgingHistories() {
        System.runAs(users.get(1)) {
            billingAgingHistories = new List<Billing_Aging_History__c>();

            billingAgingHistories.add(
                new Billing_Aging_History__c(
                    Accounting_Period__c = acctPeriods.get(2).Id,
                    Billing__c = billings.get(0).Id,
                    Amount__c = 27.60
                )
            );

            billingAgingHistories.add(
                new Billing_Aging_History__c(
                    Accounting_Period__c = acctPeriods.get(0).Id,
                    Billing__c = billings.get(0).Id,
                    Amount__c = 37.60
                )
            );

            billingAgingHistories.add(
                new Billing_Aging_History__c(
                    Accounting_Period__c = acctPeriods.get(4).Id,
                    Billing__c = billings.get(0).Id,
                    Amount__c = 47.60
                )
            );

            insert billingAgingHistories;
        }

        return this;
    }

    public TestDataSuite createExpenseReports() {
        System.runAs(users.get(1)) {
            expenseReports = new List<Expense_Report__c>();

            expenseReports.add(
                new Expense_Report__c(
                    Ledger__c = ledgers[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Status__c = 'Approved'
                )
            );

            expenseReports.add(
                new Expense_Report__c(
                    Ledger__c = ledgers[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Status__c = 'Approved'
                )
            );

            insert expenseReports;
        }

        return this;
    }

    public TestDataSuite createProjects() {
        System.runAs(users.get(1)) {
            projects = new List<Project__c>();

            projects.add(
                new Project__c(
                    Name = 'Test Project',
                    Account__c = accounts.get(0).Id,
                    Status__c = 'Active'
                )
            );

            projects.add(
                new Project__c(
                    Name = 'Test Template Project',
                    Account__c = accounts.get(0).Id,
                    Status__c = 'Active',
                    Template_Project__c = true
                )
            );

            insert projects;
        }

        return this;
    }

    public TestDataSuite createProjectTasks() {
        System.runAs(users.get(1)) {
            projectTasks = new List<Project_Task__c>();

            projectTasks.add(
                new Project_Task__c(
                    Name = 'Test Project Task 1',
                    Project__c = projects.get(0).Id,
                    Status__c = 'Active'
                )
            );

            projectTasks.add(
                new Project_Task__c(
                    Name = 'Test Project Task 2',
                    Project__c = projects.get(0).Id,
                    Status__c = 'Active'
                )
            );

            projectTasks.add(
                new Project_Task__c(
                    Name = 'Test Template Project Task',
                    Project__c = projects.get(1).Id,
                    Status__c = 'Active'
                )
            );

            insert projectTasks;
        }

        return this;
    }

    public TestDataSuite createGLAccountExpenses() {
        System.runAs(users.get(1)) {
            glAccountsExpense = new List<GL_Account__c>();

            // 0
            glAccountsExpense.add(
                new GL_Account__c(
                    Name = '6050-Travel Expenses',
                    Active__c = true,
                    Used_In_Expense_Reports__c = true,
                    Type__c = 'Expense',
                    Expense_Report_Name__c = 'Travel Expenses',
                    Billing_Description__c = 'Travel Expenses',
                    TM_Revenue_Conversion__c = glAccounts.get(11).Id,
                    Sub_Type_1__c = 'Sales & Marketing',
                    Sub_Type_2__c = 'Sales Travel',
                    Mileage_Rate__c = 0.3
                )
            );

            // 1
            glAccountsExpense.add(
                new GL_Account__c(
                    Name = '6060-Meals and Entertainment',
                    Active__c = true,
                    Type__c = 'Expense',
                    Used_In_Expense_Reports__c = true,
                    Expense_Report_Name__c = 'Meals and Entertainment',
                    Billing_Description__c = 'Meals and Entertainment',
                    TM_Revenue_Conversion__c = glAccounts.get(11).Id,
                    Sub_Type_1__c = 'Sales & Marketing',
                    Sub_Type_2__c = 'Sales Travel',
                    Mileage_Rate__c = 0.3
                )
            );

            // 2
            glAccountsExpense.add(
                new GL_Account__c(
                    Name = '6070-Mileage',
                    Active__c = true,
                    Type__c = 'Expense',
                    Used_In_Expense_Reports__c = true,
                    Expense_Report_Name__c = 'Mileage',
                    Billing_Description__c = 'Mileage',
                    Mileage_Account__c = true,
                    Mileage_Rate__c = .52,
                    TM_Revenue_Conversion__c = glAccounts.get(11).Id,
                    Sub_Type_1__c = 'Sales & Marketing',
                    Sub_Type_2__c = 'Sales Travel'
                )
            );

            insert glAccountsExpense;
        }

        return this;
    }

    public TestDataSuite createExpenseLines() {
        System.runAs(users.get(1)) {
            expenses = new List<Expense_Line__c>();
            //0
            expenses.add(
                new Expense_Line__c(
                    Date__c = System.today(),
                    Expense_Report__c = expenseReports.get(0).Id,
                    Project__c = projects.get(0).Id,
                    Project_Task__c = projectTasks.get(0).Id,
                    Expense_GL_Account__c = glAccountsExpense.get(2).Id,
                    Miles__c = 50,
                    Amount__c = 0
                )
            );
            //1
            expenses.add(
                new Expense_Line__c(
                    Date__c = System.today(),
                    Expense_Report__c = expenseReports.get(0).Id,
                    Project__c = projects.get(0).Id,
                    Project_Task__c = projectTasks.get(0).Id,
                    Expense_GL_Account__c = glAccountsExpense.get(1).Id,
                    Amount__c = 50
                )
            );
            //2
            expenses.add(
                new Expense_Line__c(
                    Date__c = System.today(),
                    Expense_Report__c = expenseReports.get(1).Id,
                    Project__c = projects.get(0).Id,
                    Project_Task__c = projectTasks.get(0).Id,
                    Expense_GL_Account__c = glAccountsExpense.get(2).Id,
                    Miles__c = 50,
                    Mileage_Origin__c = 'Las Vegas, NV',
                    Mileage_Destination__c = 'Las Vegas, NM',
                    Amount__c = 0
                )
            );
            //3
            expenses.add(
                new Expense_Line__c(
                    Date__c = System.today(),
                    Expense_Report__c = expenseReports.get(1).Id,
                    Project__c = projects.get(0).Id,
                    Project_Task__c = projectTasks.get(0).Id,
                    Expense_GL_Account__c = glAccountsExpense.get(2).Id,
                    Miles__c = 50,
                    Mileage_Origin__c = 'Las Vegas, NV',
                    Mileage_Destination__c = 'Las Vegas, NM',
                    Amount__c = 0
                )
            );
            //4
            expenses.add(
                new Expense_Line__c(
                    Date__c = System.today(),
                    Expense_Report__c = expenseReports.get(1).Id,
                    Project__c = projects.get(0).Id,
                    Project_Task__c = projectTasks.get(0).Id,
                    Expense_GL_Account__c = glAccountsExpense.get(1).Id,
                    Amount__c = 50,
                    Credit_Card_Vendor__c = accounts.get(0).Id,
                    Employee_Reimburse__c = false
                )
            );
            //5
            expenses.add(
                new Expense_Line__c(
                    Date__c = System.today(),
                    Expense_Report__c = expenseReports.get(1).Id,
                    Project__c = projects.get(0).Id,
                    Project_Task__c = projectTasks.get(0).Id,
                    Expense_GL_Account__c = glAccountsExpense.get(0).Id,
                    Amount__c = 150,
                    Credit_Card_Vendor__c = accounts.get(0).Id,
                    Employee_Reimburse__c = false
                )
            );

            insert expenses;
        }

        return this;
    }

    public TestDataSuite createRecurringAccountPayables() {
        System.runAs(users.get(1)) {
            recurringPayables = new List<Recurring_Account_Payable__c>();

            recurringPayables.add(
                new Recurring_Account_Payable__c(
                    Name = 'Test Recurring Payable 1',
                    Vendor__c = accounts.get(0).Id,
                    Next_Account_Payable_Date__c = Date.newInstance(1991, 12, 31),
                    Account_Payable_Frequency__c = 'Monthly',
                    Status__c = 'Active'
                )
            );

            recurringPayables.add(
                new Recurring_Account_Payable__c(
                    Name = 'Test Recurring Payable 2',
                    Vendor__c = accounts.get(1).Id,
                    Next_Account_Payable_Date__c = Date.newInstance(1992, 1, 31),
                    Account_Payable_Frequency__c = 'Monthly',
                    Status__c = 'Active'
                )
            );

            insert recurringPayables;
        }

        return this;
    }

    public TestDataSuite createRecurringAccountPayableLines() {
        System.runAs(users.get(1)) {
            recurringPayableLines = new List<Recurring_Account_Payable_Line__c>();

            recurringPayableLines.add(
                new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c= recurringPayables.get(0).Id,
                    Quantity__c = 2,
                    Amount2__c = 3446,
                    Expense_GL_Account__c = glAccounts.get(11).Id,
                    Internal_Comment__c = 'test comment 1'
                )
            );

            recurringPayableLines.add(
                new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = recurringPayables.get(0).Id,
                    Quantity__c = 3,
                    Amount2__c = 2346,
                    Expense_GL_Account__c = glAccounts.get(11).Id,
                    Internal_Comment__c = 'test comment 2'
                )
            );

            recurringPayableLines.add(
                new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = recurringPayables.get(1).Id,
                    Quantity__c = 2,
                    Amount2__c = 3446,
                    Expense_GL_Account__c = glAccounts.get(11).Id,
                    Internal_Comment__c = 'test comment 3'
                )
            );

            recurringPayableLines.add(
                new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = recurringPayables.get(1).Id,
                    Quantity__c = 3,
                    Amount2__c = 2346,
                    Expense_GL_Account__c = glAccounts.get(11).Id,
                    Internal_Comment__c = 'test comment 4'
                )
            );

            insert recurringPayableLines;
        }

        return this;
    }


    public TestDataSuite createRecurringBilling() {
        System.runAs(users.get(1)) {
            recurringBillings = new List<Recurring_Billing__c>();

            recurringBillings.add(
                new Recurring_Billing__c(
                    Name = 'Test Recurring Billing 1',
                    Customer__c = accounts[0].Id,
                    Next_Billing_Date__c = Date.newInstance(1991, 12, 31),
                    Opportunity__c = opportunities[0].Id,
                    Billing_Frequency__c = 'Monthly',
                    Status__c = 'Active',
                    Billing_Contact__c = contacts[0].Id,
                    PO_Number__c = '111111',
                    Comment__c = 'test comment 1',
                    Ledger__c = ledgers[0].Id
                )
            );

            recurringBillings.add(
                new Recurring_Billing__c(
                    Name = 'Test Recurring Billing 2',
                    Customer__c = accounts[1].Id,
                    Next_Billing_Date__c = Date.newInstance(1992, 1, 31),
                    Billing_Frequency__c = 'Monthly',
                    Opportunity__c = opportunities[0].Id,
                    Status__c = 'Active',
                    Billing_Contact__c = contacts[1].Id,
                    PO_Number__c = '222222',
                    Comment__c = 'test comment 2',
                    Ledger__c = ledgers[0].Id
                )
            );

            insert recurringBillings;
        }

        return this;
    }

    public TestDataSuite createRecurringBillingLines() {
        System.runAs(users.get(1)) {
            recurringBillingLines = new List<Recurring_Billing_Line__c>();

            recurringBillingLines.add(
                new Recurring_Billing_Line__c(
                    Recurring_Billing__c = recurringBillings[0].Id,
                    Quantity__c = 2,
                    Rate__c = 3446,
                    Revenue_GL_Account__c = glAccounts[11].Id
                )
            );

            recurringBillingLines.add(
                new Recurring_Billing_Line__c(
                    Recurring_Billing__c = recurringBillings[0].Id,
                    Quantity__c = 3,
                    Rate__c = 2346,
                    Revenue_GL_Account__c = glAccounts[11].Id
                )
            );

            recurringBillingLines.add(
                new Recurring_Billing_Line__c(
                    Recurring_Billing__c = recurringBillings[1].Id,
                    Quantity__c = 2,
                    Rate__c = 3446,
                    Revenue_GL_Account__c = glAccounts[11].Id
                )
            );

            recurringBillingLines.add(
                new Recurring_Billing_Line__c(
                    Recurring_Billing__c = recurringBillings[1].Id,
                    Quantity__c = 3,
                    Rate__c = 2346,
                    Revenue_GL_Account__c = glAccounts[11].Id
                )
            );

            insert recurringBillingLines;
        }

        return this;
    }

    public TestDataSuite createRecurringJournalEntry() {
        System.runAs(users.get(1)) {
            recurringJournalEntries = new List<Recurring_Journal_Entry__c>();

            recurringJournalEntries.add(
                new Recurring_Journal_Entry__c(
                    Name = 'Test Journal Entry 1',
                    Next_Journal_Entry_Date__c = Date.newInstance(1991, 12, 31),
                    Journal_Entry_Frequency__c = 'Monthly',
                    Status__c = 'Active',
                    Reference__c = 'Test Reference 1'
                )
            );

            recurringJournalEntries.add(
                new Recurring_Journal_Entry__c(
                    Name = 'Test Journal Entry 2',
                    Next_Journal_Entry_Date__c = Date.newInstance(1992, 1, 31),
                    Journal_Entry_Frequency__c = 'Monthly',
                    Status__c = 'Active',
                    Reference__c = 'Test Reference 2'
                )
            );

            insert recurringJournalEntries;
        }

        return this;
    }

    public TestDataSuite createRecurringJournalEntryLines() {
        System.runAs(users.get(1)) {
            recurringJournalEntryLines = new List<Recurring_Journal_Entry_Line__c>();

            recurringJournalEntryLines.add(
                new Recurring_Journal_Entry_Line__c(
                    Recurring_Journal_Entry__c= recurringJournalEntries.get(0).Id,
                    Quantity__c = 2,
                    Debit__c= 300,
                    GL_Account__c = glAccounts.get(16).Id
                )
            );

            recurringJournalEntryLines.add(
                new Recurring_Journal_Entry_Line__c(
                    Recurring_Journal_Entry__c = recurringJournalEntries.get(0).Id,
                    Quantity__c = 3,
                    Credit__c = 300,
                    GL_Account__c = glAccounts.get(16).Id
                )
            );

            recurringJournalEntryLines.add(
                new Recurring_Journal_Entry_Line__c(
                    Recurring_Journal_Entry__c = recurringJournalEntries.get(1).Id,
                    Quantity__c = 2,
                    Debit__c = 100,
                    GL_Account__c = glAccounts.get(16).Id
                )
            );

            recurringJournalEntryLines.add(
                new Recurring_Journal_Entry_Line__c(
                    Recurring_Journal_Entry__c = recurringJournalEntries.get(1).Id,
                    Quantity__c = 3,
                    Credit__c = 100,
                    GL_Account__c = glAccounts.get(16).Id
                )
            );

            insert recurringJournalEntryLines;
        }

        return this;
    }

    public TestDataSuite createCashFlowCategories(Boolean setDefaults) {
        System.runAs(users.get(1)) {
            cashFlowCategories = new List<GL_Account__c>();
            //0
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Receipts from customers',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //1
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Payments to suppliers',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //2
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Payments to employees',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //3
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Interest received',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //4
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Interest Paid',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //5
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Taxes Paid',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //6
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Other Operating',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );
            //7
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Proceeds from sale of fixed assets',
                    Sub_Type_1__c = 'Investing',
                    Type__c = 'Cash Flow'
                )
            );
            //8
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Payment for fixed assets',
                    Sub_Type_1__c = 'Investing',
                    Type__c = 'Cash Flow'
                )
            );
            //9
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Other Investing',
                    Sub_Type_1__c = 'Investing',
                    Type__c = 'Cash Flow'
                )
            );
            //10
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Proceeds from issuance of debt',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );
            //11
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Repayment of debt',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );
            //12
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Proceeds from issuance of equity',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );
            //13
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Distributions of equity',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );
            //14
            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Other Financing',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );

            insert cashFlowCategories;

            if (setDefaults) {
                settings.Default_Cash_Receipt_Category__c = cashFlowCategories.get(0).Id;
                settings.Default_Cash_Disbursement_Category__c = cashFlowCategories.get(1).Id;
                settings.Default_Journal_Entry_Line_Category__c = cashFlowCategories.get(2).Id;
                settings.Enable_Cash_Flow_Statement__c = true;
                update settings;

                AccountingSettingsHandler.resetAccountingSettings();

                Set<Id> ledgeIds = new Set<Id>();
                ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()).keySet());
                ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getBudgetLedgers()).keySet());
                GLAccount.createGLAccountDefaultsByLedger(ledgeIds, true);
            }
        }

        return this;
    }

    public TestDataSuite createScheduledRevenueExpense() {
        System.runAs(users.get(1)) {

            scheduledRevenues = new List<Scheduled_Revenue_Expense__c>();

            scheduledRevenues.add(
                new Scheduled_Revenue_Expense__c(
                    Name = 'Test Rev 1',
                    Amount__c = 400,
                    Credit_GL_Account__c = glAccounts[6].Id,
                    Debit_GL_Account__c = glAccounts[16].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = 'Approved'
                )
            );

            scheduledRevenues.add(
                new Scheduled_Revenue_Expense__c(
                    Name = 'Test Rev 2',
                    Amount__c = 200,
                    Credit_GL_Account__c = glAccounts[6].Id,
                    Debit_GL_Account__c = glAccounts[16].Id,
                    Accounting_Period__c = acctPeriods[0].Id,
                    Status__c = 'Approved'
                )
            );

            insert scheduledRevenues;
        }

        return this;
    }

    public TestDataSuite createJournalEntries() {
        return createJournalEntries(false);
    }

    public TestDataSuite createJournalEntries(Boolean doPost) {
        System.runAs(users[1]) {
            journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Journal_Date__c = System.today(),
                    Status__c = 'Approved'
                )
            );

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 2',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Journal_Date__c = System.today(),
                    Status__c = 'Approved'
                )
            );

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 3',
                    Accounting_Period__c = acctPeriods[0].Id,
                    Journal_Date__c = System.today(),
                    Status__c = 'Approved'
                )
            );

            insert journalEntries;

            journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Credit__c = 100,
                    GL_Account__c = glAccounts[0].Id,
                    Units__c = 10,
                    Reference__c = 'the reference 1',
                    Description__c = 'the description 1'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Debit__c = 100,
                    GL_Account__c = glAccounts[0].Id,
                    Units__c = 10,
                    Reference__c = 'the reference 2',
                    Description__c = 'the description 2'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Credit__c = 200,
                    GL_Account__c = glAccounts[0].Id,
                    Units__c = 10,
                    Reference__c = 'the reference 3',
                    Description__c = 'the description 3'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Debit__c = 200,
                    GL_Account__c = glAccounts[0].Id,
                    Units__c = 10,
                    Reference__c = 'the reference 4',
                    Description__c = 'the description 4'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Debit__c = 0,
                    GL_Account__c = glAccounts[0].Id,
                    Units__c = 0,
                    Reference__c = 'the reference 5',
                    Description__c = 'the description 5'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Credit__c = 0,
                    GL_Account__c = glAccounts[0].Id,
                    Units__c = 0,
                    Reference__c = 'the reference 6',
                    Description__c = 'the description 6'
                )
            );
            insert journalEntryLines;

            if (doPost) {
                AbstractPostHandler postHandler = new JournalEntryPostHandler();
                List<PostResult> postResults = postHandler.post(this.journalEntries);
                System.assertEquals(true, postResults[0].isSuccess);
            }
        }

        return this;
    }

    public TestDataSuite createBankDeposits() {
        System.runAs(users.get(1)) {

            bankDeposits = new List<Bank_Deposit__c>();

            bankDeposits.add(
                new Bank_Deposit__c(
                    Deposit_Date__c = acctPeriods[1].Start_Date__c,
                    Bank_Account__c = glAccounts[0].Id,
                    Deposit_Reference__c = 'the reference 1'
                )
            );

            bankDeposits.add(
                new Bank_Deposit__c(
                    Deposit_Date__c = acctPeriods[1].Start_Date__c,
                    Bank_Account__c = glAccounts[0].Id,
                    Deposit_Reference__c = 'the reference 2'
                )
            );
            insert bankDeposits;
        }

        return this;
    }

    public TestDataSuite createBankDisbursements() {
        System.runAs(users.get(1)) {

            bankDisbursements = new List<Bank_Disbursement__c>();

            bankDisbursements.add(
                new Bank_Disbursement__c(
                    Disbursement_Date__c = acctPeriods[1].Start_Date__c,
                    Bank_GL_Account__c = glAccounts[0].Id,
                    Disbursement_Reference__c = 'the reference 1',
                    Ledger__c = ledgers[0].Id
                )
            );

            bankDisbursements.add(
                new Bank_Disbursement__c(
                    Disbursement_Date__c = acctPeriods[1].Start_Date__c,
                    Bank_GL_Account__c = glAccounts[0].Id,
                    Disbursement_Reference__c = 'the reference 2',
                    Ledger__c = ledgers[0].Id
                )
            );
            insert bankDisbursements;
        }

        return this;
    }

    public TestDataSuite createBankReconciliations() {
        System.runAs(users.get(1)) {

            bankReconciliations = new List<Bank_Reconciliation2__c>();

            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[0].Start_Date__c+30,
                    Bank_Account__c = glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[1].Start_Date__c+30,
                    Bank_Account__c = glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            //bank rec 2 is first in chain of bank recs for status testing
            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[1].Start_Date__c+30,
                    Bank_Account__c = glAccounts[29].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            //bank rec 3 is second in chain of bank recs for status testing
            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[2].Start_Date__c+30,
                    Bank_Account__c = glAccounts[29].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            //bank rec 4 is third in chain of bank recs for status testing
            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[3].Start_Date__c+30,
                    Bank_Account__c = glAccounts[29].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            //bank rec 5 is fourth in chain of bank recs for status testing
            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[4].Start_Date__c+30,
                    Bank_Account__c = glAccounts[29].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            //bank rec 6 is fifth in chain of bank recs for status testing
            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[5].Start_Date__c+30,
                    Bank_Account__c = glAccounts[29].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                )
            );

            //bank rec 7 is a 'legacy' bank rec
            bankReconciliations.add(
                new Bank_Reconciliation2__c(
                    End_Date__c = acctPeriods[0].Start_Date__c+30,
                    Bank_Account__c = glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 30000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE,
                    Modern_BR__c = false
                )
            );
            BankReconciliationActions.bypassDefaultStatusWorking = true;
            insert bankReconciliations;
            BankReconciliationActions.bypassDefaultStatusWorking = false;
        }

        return this;
    }

    public TestDataSuite createProducts() {
        System.runAs(users.get(1)) {

            products = new List<Product2>();
            // 0
            products.add(
                new Product2(
                    Name = 'Test Prod 1',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 100
                )
            );
            // 1
            products.add(
                new Product2(
                    Name = 'Test Prod 2',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 200
                )
            );
            // 2
            products.add(
                new Product2(
                    Name = 'Test Prod Kit',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Inventory_Type__c = 'Kit',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 50
                )
            );
            // 3
            products.add(
                new Product2(
                    Name = 'Taxable Product',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Accounting_Type__c = 'Taxable Product',
                    Tax_Rate__c = 7.25
                )
            );
            // 4
            products.add(
                new Product2(
                    Name = 'Tax Rate',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Accounting_Type__c = 'Tax Rate',
                    Tax_Rate__c = 5.5
                )
            );
            // 5
            products.add(
                new Product2(
                    Name = 'Avalara Sales Tax',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Accounting_Type__c = 'Taxable Product'
                )
            );

            insert products;
        }

        return this;
    }

    public TestDataSuite createProductParts() {
        System.runAs(users.get(1)) {
            productParts = new List<Product_Part__c>();

            productParts.add(
                new Product_Part__c(
                    Product__c = products[2].Id,
                    Product_Part__c = products[0].Id,
                    Quantity__c = 1
                )
            );

            productParts.add(
                new Product_Part__c(
                    Product__c = products[2].Id,
                    Product_Part__c = products[1].Id,
                    Quantity__c = 1
                )
            );

            insert productParts;
        }
        return this;
    }

    public TestDataSuite createOpportunities() {
        System.runAs(users.get(1)) {

            opportunities = new List<Opportunity>();

            opportunities.add(
                new Opportunity(
                    Name = 'Test Opp',
                    AccountId = accounts[0].Id,
                    StageName = 'Open',
                    CloseDate = System.today()
                )
            );
            insert opportunities;
        }

        return this;
    }

    public TestDataSuite createTimeCards() {
        return createTimeCards(false);
    }

    public TestDataSuite createTimeCards(Boolean doPost) {
        System.runAs(users.get(1)) {
            periods = new List<Time_Card_Period__c>();
            periods.add(
                new Time_Card_Period__c(
                    Name = '1991-10',
                    Start_Date__c = Date.newInstance(1991, 10, 1),
                    End_Date__c = Date.newInstance(1991, 10, 7),
                    Status__c = 'Open'
                )
            );

            periods.add(
                new Time_Card_Period__c(
                    Name='1991-11',
                    Start_Date__c = Date.newInstance(1991, 11, 1),
                    End_Date__c = Date.newInstance(1991, 11, 7),
                    Status__c = 'Open'
                )
            );

            insert periods;

            timeCards = new List<Time_Card__c>();
            timeCards.add(
                new Time_Card__c(
                    Time_Card_Period__c = periods[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Status__c = 'Approved'
                )
            );

            timeCards.add(
                new Time_Card__c(
                    Time_Card_Period__c = periods[1].Id,
                    Employee__c = UserInfo.getUserId(),
                    Status__c = 'Approved'
                )
            );

            insert timeCards;

            timeCardLines = new List<Time_Card_Line__c>();

            timeCardLines.add(
                new Time_Card_Line__c(
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Time_Card__c = timeCards[0].Id
                )
            );

            timeCardLines.add(
                new Time_Card_Line__c(
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[1].Id,
                    Time_Card__c = timeCards[1].Id
                )
            );

            timeCardLines.add(
                new Time_Card_Line__c(
                    Project__c = projects[1].Id,
                    Project_Task__c = projectTasks[2].Id,
                    Time_Card__c = timeCards[0].Id
                )
            );

            insert timeCardLines;

            timeCardDays = new List<Time_Card_Day__c>();

            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[0].Start_Date__c,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[0].Id
                )
            );
            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[0].Start_Date__c + 1,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[0].Id
                )
            );
            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[0].Start_Date__c + 2,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[0].Id
                )
            );
            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[0].Start_Date__c + 3,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[0].Id
                )
            );

            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[1].Start_Date__c,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[1].Id
                )
            );
            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[1].Start_Date__c + 1,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[1].Id
                )
            );
            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[1].Start_Date__c + 2,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[1].Id
                )
            );
            timeCardDays.add(
                new Time_Card_Day__c(
                    Date__c = periods[1].Start_Date__c + 3,
                    Hours__c = 8,
                    Time_Card_Line__c = timeCardLines[1].Id
                )
            );
            insert timeCardDays;

            if (doPost) {
                AbstractPostHandler postHandler = new TimeCardPostHandler();
                List<PostResult> postResults = postHandler.post(this.timeCards);
                System.assertEquals(true, postResults[0].isSuccess);
            }
        }
        return this;
    }

    public TestDataSuite createAccountTaxes() {
        System.runAs(users.get(1)) {
            accountTaxes = new List<Account_Tax__c>();
            accountTaxes.add(
                new Account_Tax__c(
                    Account__c = accounts[0].Id,
                    Tax_Type__c = 'Sales & Purchase',
                    Tax_Rate__c = products[4].Id
                )
            );

            insert accountTaxes;
        }

        return this;
    }

    public TestDataSuite enableAvaTaxCalculation() {
        System.runAs(users.get(1)) {
            if (addressObjects == null) {
                createAddressObjects();
            }
            if (products == null) {
                createProducts();
            }
            AvaTax_License__c newLicense = new AvaTax_License__c();
            newLicense.Active_AvaTax_Endpoint__c = GlobalVariables.AVALARA_REST_ENDPOINT;
            newLicense.AvaTax_Account_ID__c = 'AvataxAccountId';
            newLicense.AvaTax_License_Key__c = 'AvataxLicenseKey';
            insert newLicense;

            Tax_Settings__c taxSetting = new Tax_Settings__c();
            taxSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            taxSetting.Origin_Address__c = addressObjects[0].Id;
            taxSetting.Sales_Tax_GL_Account__c = glAccounts[28].Id;
            taxSetting.AvaTax_License__c = newLicense.Id;
            taxSetting.Sales_Tax_Product__c = products[5].Id;
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
            insert taxSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(ledgers[0].Id);
            selectedLedger.Tax_Settings__c = taxSetting.Id;
            selectedLedger.Sales_Tax_Company_Code__c = 'TEST_COMPANY';
            update selectedLedger;
        }
        return this;
    }

    public TestDataSuite createFixedAssets() {
        System.runAs(users.get(1)) {

            fixedAssets = new List<Fixed_Asset__c>();
            fixedAssets.add(new Fixed_Asset__c (Name = 'FA1', Value__c = 500));
            fixedAssets.add(new Fixed_Asset__c (Name = 'FA2', Value__c = 20));

            insert fixedAssets;
        }

        return this;
    }

    public TestDataSuite createBillingRates() {
        System.runAs(users.get(1)) {
            billingRates = new List<Billing_Rates__c>();

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 100
                )
            );

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[1].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 125
                )
            );

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[1].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 150
                )
            );

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 100
                )
            );

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 200
                )
            );

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[0].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 300
                )
            );

            billingRates.add(
                new Billing_Rates__c(
                    Project__c = projects[0].Id,
                    Project_Task__c = projectTasks[1].Id,
                    Employee__c = UserInfo.getUserId(),
                    Amount__c = 60,
                    Overtime_Labor_Billing_Rate__c = 100
                )
            );

            insert billingRates;
        }

        return this;
    }

    public TestDataSuite createLedgerHierarchies() {
        System.runAs(users.get(1)) {
            Ledger__c consolidationsTransactionalLedger;
            Ledger__c consolidationsBudgetLedger;
            for (Ledger__c ledger : ledgers) {
                if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                    consolidationsTransactionalLedger = ledger;
                }
                else if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET) {
                    consolidationsBudgetLedger = ledger;
                }
            }

            if (consolidationsTransactionalLedger != null && consolidationsBudgetLedger != null) {

                List<Ledger_Hierarchy__c> L1 = new List<Ledger_Hierarchy__c>();
                List<Ledger_Hierarchy__c> L2 = new List<Ledger_Hierarchy__c>();


                L1.add(
                    new Ledger_Hierarchy__c(
                        Name = 'Transactional Hierarchy',
                        Ledger__c = consolidationsTransactionalLedger.Id
                    )
                );
                L1.add(
                    new Ledger_Hierarchy__c(
                        Name = 'Budget Hierarchy',
                        Ledger__c = consolidationsBudgetLedger.Id
                    )
                );
                insert L1;

                L2.add(
                    new Ledger_Hierarchy__c(
                        Name = 'Transactional Ledger',
                        Ledger__c = ledgers.get(0).Id,
                        Parent_Ledger_Hierarchy__c = L1.get(0).Id
                    )
                );
                L2.add(
                    new Ledger_Hierarchy__c(
                        Name = 'Budget Ledger',
                        Ledger__c = ledgers.get(1).Id,
                        Parent_Ledger_Hierarchy__c = L1.get(1).Id
                    )
                );
                insert L2;
               
                ledgerHierarchies = new List<Ledger_Hierarchy__c>();
                ledgerHierarchies.addAll(L1);
                ledgerHierarchies.addAll(L2);
 
            }
        }
        return this;
    }

    public TestDataSuite createConsolidationLedgers() {
        System.runAs(users.get(1)) {
            List<Ledger__c> consolidationLedgers = new List<Ledger__c>{
                new Ledger__c(
                    Name = 'Consolidation ledger1',
                    Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                    Default_Bank_Account__c = glAccounts[0].Id,
                    Default_Billing_Format__c = billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = billingFormats[3].Id
                ),
                new Ledger__c(
                    Name = 'Consolidation ledger2',
                    Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET,
                    Default_Bank_Account__c = glAccounts[0].Id,
                    Default_Billing_Format__c = billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = billingFormats[3].Id
                ),
                new Ledger__c(
                    Name = 'Consolidation ledger3',
                    Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                    Default_Bank_Account__c = glAccounts[0].Id,
                    Default_Billing_Format__c = billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = billingFormats[3].Id
                )
            };
            insert consolidationLedgers;

            ledgers.addAll(consolidationLedgers);
        }
        return this;
    }

    public TestDataSuite createFinancialReportResults() {
        System.runAs(users.get(1)) {

            financialReportResults = new List<Financial_Report_Result__c>{
                new Financial_Report_Result__c(
                    Status__c = 'Completed'
                ),
                new Financial_Report_Result__c(
                    Status__c = 'Completed'
                ),
                new Financial_Report_Result__c(
                    Status__c = 'Completed'
                )
            };
            insert financialReportResults;
        }

        return this;
    }

    public TestDataSuite createGlReportingGroups() {
        System.runAs(users.get(1)) {
            glReportingGroups = new List<GL_Account_Reporting_Group__c>();

            glReportingGroups.add(
                new GL_Account_Reporting_Group__c(
                    Name = 'All Income Statement',
                    Type__c = 'Income Statement'
                )

            );

            glReportingGroups.add(
                new GL_Account_Reporting_Group__c(
                    Name = 'All Balance Sheet',
                    Type__c = 'Balance Sheet'
                )

            );
            insert glReportingGroups;
        }

        return this;
    }

    public TestDataSuite createGlReportingGroupLines() {
        System.runAs(users.get(1)) {
            glReportingGroupLines = new List<GL_Account_Reporting_Group_Line__c>();

            glReportingGroupLines.add(
                new GL_Account_Reporting_Group_Line__c(
                    GL_Account_Reporting_Group__c = glReportingGroups.get(0).Id,
                    GL_Account__c = glAccounts.get(0).Id
                )

            );

            glReportingGroupLines.add(
                new GL_Account_Reporting_Group_Line__c(
                    GL_Account_Reporting_Group__c = glReportingGroups.get(0).Id,
                    GL_Account__c = glAccounts.get(1).Id
                )

            );

            glReportingGroupLines.add(
                new GL_Account_Reporting_Group_Line__c(
                    GL_Account_Reporting_Group__c = glReportingGroups.get(0).Id,
                    GL_Account__c = glAccounts.get(2).Id
                )

            );

            glReportingGroupLines.add(
                new GL_Account_Reporting_Group_Line__c(
                    GL_Account_Reporting_Group__c = glReportingGroups.get(0).Id,
                    GL_Account__c = glAccounts.get(3).Id
                )

            );

            glReportingGroupLines.add(
                new GL_Account_Reporting_Group_Line__c(
                    GL_Account_Reporting_Group__c = glReportingGroups.get(1).Id,
                    GL_Account__c = glAccounts.get(4).Id
                )

            );
            insert glReportingGroupLines;
        }

        return this;
    }

    public TestDataSuite createReportDefinitions() {
        System.runAs(users.get(1)) {
            reportDefs = new List<Financial_Report_Definition__c>();

            reportDefs.add(
                new Financial_Report_Definition__c(
                    Name = 'Test Report 1'
                )
            );
            insert reportDefs;
        }

        return this;
    }

    public TestDataSuite createReportRows() {
        System.runAs(users.get(1)) {
            reportRows = new List<Financial_Report_Row__c>();

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = glAccounts.get(0).Name,
                    Type__c = 'GL Account',
                    GL_Account__c = glAccounts.get(0).Id,
                    Position__c = 1,
                    Normal_Balance__c = 'Credit'
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = glAccounts.get(1).Name,
                    Type__c = 'GL Account',
                    GL_Account__c = glAccounts.get(1).Id,
                    Position__c = 2,
                    Normal_Balance__c = 'Credit'
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = glAccounts.get(2).Name,
                    Type__c = 'GL Account',
                    GL_Account__c = glAccounts.get(2).Id,
                    Position__c = 3,
                    Normal_Balance__c = 'Credit'
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = glAccounts.get(3).Name,
                    Type__c = 'GL Account',
                    GL_Account__c = glAccounts.get(3).Id,
                    Position__c = 4,
                    Normal_Balance__c = 'Credit'
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = glReportingGroups.get(0).Name,
                    Type__c = 'Reporting Group',
                    GL_Account_Reporting_Group__c = glReportingGroups.get(0).Id,
                    Position__c = 5,
                    Normal_Balance__c = 'Credit'
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = 'Blah',
                    Type__c = 'Blank',
                    Position__c = 6
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = 'Testing',
                    Type__c = 'Description',
                    Position__c = 7
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = 'Total',
                    Type__c = 'Calculation Number',
                    Position__c = 8,
                    Calculation__c = '{r1} + {r2} + {r3} + {r4}'
                )
            );

            reportRows.add(
                new Financial_Report_Row__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Row_Label__c = 'Divide By Two',
                    Type__c = 'Calculation %',
                    Position__c = 9,
                    Calculation__c = '{r8} / {r2}'
                )
            );
            insert reportRows;
        }

        return this;
    }

    public TestDataSuite createReportColumns() {
        System.runAs(users.get(1)) {
            reportCols = new List<Financial_Report_Column__c>();

            reportCols.add(
                new Financial_Report_Column__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Ledger__c = ledgers.get(1).Id,
                    Type__c = 'Current Period',
                    Offset__c = 0,
                    Header_1_Value__c = 'Period Name',
                    Header_1__c = null,
                    Header_2_Value__c = 'Text',
                    Header_2__c = 'This is some text',
                    Position__c = 1
                )
            );

            reportCols.add(
                new Financial_Report_Column__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Ledger__c = ledgers.get(1).Id,
                    Type__c = 'Current Period',
                    Offset__c = 1,
                    Header_1_Value__c = 'Text',
                    Header_1__c = 'This is some text',
                    Header_2_Value__c = 'Period Name',
                    Header_2__c = null,
                    Position__c = 2
                )
            );

            reportCols.add(
                new Financial_Report_Column__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Ledger__c = ledgers.get(1).Id,
                    Type__c = 'Calculation Number',
                    Offset__c = 0,
                    Header_1_Value__c = 'Text',
                    Header_1__c = 'Variance',
                    Header_2_Value__c = 'Period Name',
                    Header_2__c = null,
                    Position__c = 3,
                    Calculation__c = '{c2} - {c1}',
                    Column_Overide_Row__c = true
                )
            );

            reportCols.add(
                new Financial_Report_Column__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Ledger__c = ledgers.get(1).Id,
                    Type__c = 'Calculation %',
                    Offset__c = 0,
                    Header_1_Value__c = 'Text',
                    Header_1__c = 'Variance %',
                    Header_2_Value__c = 'Period Name',
                    Header_2__c = null,
                    Position__c = 4,
                    Calculation__c = '{c2} - {c1}',
                    Column_Overide_Row__c = true
                )
            );

            reportCols.add(
                new Financial_Report_Column__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Ledger__c = ledgers.get(1).Id,
                    Type__c = 'Calculation %',
                    Offset__c = 0,
                    Header_1_Value__c = 'Text',
                    Header_1__c = 'Variance %',
                    Header_2_Value__c = 'Period Name',
                    Header_2__c = null,
                    Position__c = 5,
                    Calculation__c = '{c1:c2}',
                    Column_Overide_Row__c = true
                )
            );

            reportCols.add(
                new Financial_Report_Column__c(
                    Financial_Report_Definition__c = reportDefs.get(0).Id,
                    Ledger__c = ledgers.get(1).Id,
                    Type__c = 'Year To Date',
                    Offset__c = 0,
                    Header_1_Value__c = 'Period Name',
                    Header_1__c = null,
                    Header_2_Value__c = 'Text',
                    Header_2__c = 'This is some text',
                    Position__c = 6
                )
            );

            insert reportCols;
        }

        return this;
    }

    public TestDataSuite createTaxGroups() {
        if (!AccountingSettingsHandler.isHeaderLevelPost()) {
            setHeaderLevelPost();
        }

        System.runAs(users.get(1)) {
            taxGroups = new List<Tax_Group__c>();
            taxGroups.add(
                new Tax_Group__c(
                    Name = 'SalesTaxGroup',
                    Tax_Type__c = 'Sales'
                )
            );

            taxGroups.add(
                new Tax_Group__c(
                    Name = 'PurchaseTaxGroup',
                    Tax_Type__c = 'Purchase'
                )
            );

            taxGroups.add(
                new Tax_Group__c(
                    Name = 'SalesAndPurchaseTaxGroup',
                    Tax_Type__c = 'Sales and Purchase'
                )
            );

            insert taxGroups;

            taxRates = new List<Tax_Rate__c>();
            taxRates.add(
                new Tax_Rate__c(
                    Name = 'SalesTaxRate',
                    Tax_Group__c = taxGroups[0].Id,
                    Tax_Rate__c = 10,
                    Sales_Tax_Liability_GL_Account__c = glAccounts[6].Id
                )
            );

            taxRates.add(
                new Tax_Rate__c(
                    Name = 'PurchaseTaxRate',
                    Tax_Group__c = taxGroups[1].Id,
                    Tax_Rate__c = 5,
                    Purchase_Tax_Expense_GL_Account__c = glAccounts[23].Id
                )
            );

            taxRates.add(
                new Tax_Rate__c(
                    Name = 'SalesAndPurchase',
                    Tax_Group__c = taxGroups[2].Id,
                    Tax_Rate__c = 3,
                    Sales_Tax_Liability_GL_Account__c = glAccounts[6].Id,
                    Purchase_Tax_Expense_GL_Account__c = glAccounts[23].Id
                )
            );

            insert taxRates;

            if (products == null) {
                createProducts();
            }
            // 6
            products.add(
                new Product2(
                    Name = 'SalesTaxGroupProduct',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 50,
                    Tax_Group__c = taxGroups[0].Id
                )
            );
            // 7
            products.add(
                new Product2(
                    Name = 'PurchaseTaxGroupProduct',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 100,
                    Tax_Group__c = taxGroups[1].Id
                )
            );
            // 8
            products.add(
                new Product2(
                    Name = 'SalesAndPurchaseTaxGroupProduct',
                    Inventory_GL_Account__c = glAccounts[22].Id,
                    Expense_GL_Account__c = glAccounts[6].Id,
                    Revenue_GL_Account__c = glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 150,
                    Tax_Group__c = taxGroups[2].Id
                )
            );

            upsert products;
        }
        return this;
    }

    public TestDataSuite createGLAMs() {
        if (glams == null) {
            System.runAs(users.get(1)) {
                glams = new List<GL_Account_Mapping__c>();
                glams.add(new GL_Account_Mapping__c(
                    External_Id__c = 'yodleeAccount-1',
                    Financial_Institution__c = 'Test-Financial-Institution-1',
                    Financial_Institution_Id__c = 'Test-Financial-Institution-ID-1',
                    GL_Account__c = glAccounts.get(0).Id,
                    Ledger__c = ledgers.get(0).Id,
                    Inactive__c = false,
                    Initial_Start_Date__c = acctPeriods.get(0).Start_Date__c,
                    Source__c = 'Yodlee'
                ));
                glams.add(new GL_Account_Mapping__c(
                    External_Id__c = 'yodleeAccount-2',
                    Financial_Institution__c = 'Test-Financial-Institution-2',
                    Financial_Institution_Id__c = 'Test-Financial-Institution-ID-2',
                    GL_Account__c = glAccounts.get(0).Id,
                    Ledger__c = ledgers.get(0).Id,
                    Inactive__c = false,
                    Initial_Start_Date__c = acctPeriods.get(0).Start_Date__c,
                    Source__c = 'Yodlee'
                ));
                glams.add(new GL_Account_Mapping__c(
                    External_Id__c = 'AS_Bank_Identity_Acc_0',
                    Financial_Institution__c = 'AS_Bank',
                    Financial_Institution_Id__c = 'AS_Bank',
                    GL_Account__c = glAccounts.get(0).Id,
                    Ledger__c = ledgers.get(0).Id,
                    Inactive__c = false,
                    Initial_Start_Date__c = acctPeriods.get(0).Start_Date__c,
                    Source__c = 'Plaid'
                ));
                insert glams;
            }
        }
        return this;
    }

    public TestDataSuite createBankTransactions() {
        createGLAMs();
        
        System.runAs(users.get(1)) {
            bankTransactions = new List<Bank_Transaction__c>();
            //0
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-1',
                    Bank_Transaction_Id__c = '11111111',
                    Container__c = 'bank',
                    Key__c = 'bank' + '11111111',
                    Date__c = acctPeriods.get(0).Start_Date__c,
                    Base_Type__c = 'Credit',
                    Amount__c = 300,
                    Description__c = 'Description 1',
                    GL_Account_Mapping__c = glams[0].Id
                )
            );
            //1
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-1',
                    Bank_Transaction_Id__c = '22222222',
                    Container__c = 'creditCard',
                    Key__c = 'creditCard' + '22222222',
                    Date__c = acctPeriods.get(0).Start_Date__c,
                    Base_Type__c = 'Debit',
                    Amount__c = 100,
                    Description__c = 'Description 2',
                    GL_Account_Mapping__c = glams[0].Id
                )
            );
            //2
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-1',
                    Bank_Transaction_Id__c = '33333333',
                    Container__c = 'creditCard',
                    Key__c = 'creditCard' + '33333333',
                    Date__c = acctPeriods.get(1).Start_Date__c,
                    Base_Type__c = 'Debit',
                    Amount__c = 200,
                    Description__c = 'Description 3',
                    GL_Account_Mapping__c = glams[0].Id
                )
            );
            //3
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-2',
                    Bank_Transaction_Id__c = '44444444',
                    Container__c = 'bank',
                    Key__c = 'bank' + '44444444',
                    Date__c = acctPeriods.get(1).Start_Date__c,
                    Base_Type__c = 'Credit',
                    Amount__c = 300,
                    Description__c = 'Description 4',
                    GL_Account_Mapping__c = glams[1].Id
                )
            );
            //4
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-2',
                    Bank_Transaction_Id__c = '55555555',
                    Container__c = 'creditCard',
                    Key__c = 'creditCard' + '55555555',
                    Date__c = acctPeriods.get(2).Start_Date__c,
                    Base_Type__c = 'Debit',
                    Amount__c = 400,
                    Description__c = 'Description 5',
                    GL_Account_Mapping__c = glams[1].Id
                )
            );
            //5
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-2',
                    Bank_Transaction_Id__c = '66666666',
                    Container__c = 'bank',
                    Key__c = 'bank' + '66666666',
                    Date__c = acctPeriods.get(2).Start_Date__c,
                    Base_Type__c = 'Credit',
                    Amount__c = 500,
                    Description__c = 'Description 6',
                    GL_Account_Mapping__c = glams[1].Id
                )
            );
            //6
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'fileImport-1',
                    Bank_Transaction_Id__c = '77777777',
                    Container__c = 'bank',
                    Key__c = 'bank' + '77777777',
                    Date__c = acctPeriods.get(2).Start_Date__c,
                    Base_Type__c = 'Credit',
                    Amount__c = 500,
                    Description__c = 'Description 7',
                    GL_Account_Mapping__c = glams[1].Id,
                    Source__c = 'Financial File Import'
                )
            );
            insert bankTransactions;
        }
        return this;
    }

    public TestDataSuite createBankRules() {
        createGLAMs();
        final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

        System.runAs(users.get(1)) {
            bankRules = new List<Bank_Rule__c>();
            // 0
            bankRules.add(
                new Bank_Rule__c(
                    Name = 'Rule #1',
                    Active__c = true,
                    Priority__c = 100,
                    Type__c = 'Cash_In',
                    Evaluation_Type__c = 'And',
                    Source_Record_Type__c = PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                    Description__c = 'This is rule number 1.'
                )
            );
            // 1
            bankRules.add(
                new Bank_Rule__c(
                    Name = 'Rule #2',
                    Active__c = true,
                    Priority__c = 200,
                    Type__c = 'Cash_In',
                    Evaluation_Type__c = 'Or',
                    Source_Record_Type__c =  PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
                    Description__c = 'This is rule number 2.'
                )
            );
            // 2
            bankRules.add(
                new Bank_Rule__c(
                    Name = 'Rule #3',
                    Active__c = true,
                    Priority__c = 100,
                    Type__c = 'Cash_Out',
                    Evaluation_Type__c = 'And',
                    Source_Record_Type__c =  PACKAGE_QUALIFIER + 'Cash_Disbursement__c',
                    Description__c = 'This is rule number 3.'
                )
            );
            insert bankRules;

            bankRuleGLAMs = new List<Bank_Rule_GLAM__c>();
            // 0
            bankRuleGLAMs.add(
                new Bank_Rule_GLAM__c(
                    Bank_Rule__c = bankRules[0].Id,
                    GL_Account_Mapping__c = glams[0].Id
                )
            );
            // 1
            bankRuleGLAMs.add(
                new Bank_Rule_GLAM__c(
                    Bank_Rule__c = bankRules[1].Id,
                    GL_Account_Mapping__c = glams[0].Id
                )
            );
            // 2
            bankRuleGLAMs.add(
                new Bank_Rule_GLAM__c(
                    Bank_Rule__c = bankRules[2].Id,
                    GL_Account_Mapping__c = glams[1].Id
                )
            );
            insert bankRuleGLAMs;

            bankRuleConditions = new List<Bank_Rule_Condition__c>();
            // 0
            bankRuleConditions.add(
                new Bank_Rule_Condition__c(
                    Bank_Rule__c = bankRules[0].Id,
                    Target_Field__c =  PACKAGE_QUALIFIER + 'Amount__c',
                    Operator__c = 'Equals',
                    Amount__c = 100.00,
                    Description__c = null
                )
            );
            // 1
            bankRuleConditions.add(
                new Bank_Rule_Condition__c(
                    Bank_Rule__c = bankRules[1].Id,
                    Target_Field__c =  PACKAGE_QUALIFIER + 'Description__c',
                    Operator__c = 'Contains',
                    Amount__c = null,
                    Description__c = 'Electric Payment'
                )
            );
            // 2
            bankRuleConditions.add(
                new Bank_Rule_Condition__c(
                    Bank_Rule__c = bankRules[2].Id,
                    Target_Field__c =  PACKAGE_QUALIFIER + 'Amount__c',
                    Operator__c = 'Greater_Than',
                    Amount__c = 150.00,
                    Description__c = null
                )
            );
            insert bankRuleConditions;

            bankRuleActions = new List<Bank_Rule_Action__c>();
            // 0
            bankRuleActions.add(
                new Bank_Rule_Action__c(
                    Bank_Rule__c = bankRules[0].Id,
                    Target_Field__c =  PACKAGE_QUALIFIER + 'Description__c',
                    Value__c = '{"' +  PACKAGE_QUALIFIER + 'Description__c" : "test test test"}'
                )
            );
            // 1
            bankRuleActions.add(
                new Bank_Rule_Action__c(
                    Bank_Rule__c = bankRules[1].Id,
                    Target_Field__c = PACKAGE_QUALIFIER + 'Description__c',
                    Value__c = '{"' +  PACKAGE_QUALIFIER + 'Description__c" : "test test test"}'
                )
            );
            // 2
            bankRuleActions.add(
                new Bank_Rule_Action__c(
                    Bank_Rule__c = bankRules[2].Id,
                    Target_Field__c = PACKAGE_QUALIFIER + 'Description__c',
                    Value__c = '{"' +  PACKAGE_QUALIFIER + 'Description__c" : "test test test"}'
                )
            );
            insert bankRuleActions;
        }
        
        return this;
    }

    public TestDataSuite createPeriodTasks() {	
        System.runAs(users.get(1)) {	
            periodTasks = new List<Period_Task__c>();	
            // 0	
            periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Daily',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Daily',	
                    Assignee__c = users.get(1).id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Days',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Number_of_Occurrences__c = 1,	
                    Ends_On__c = 'Never',	
                    Sort_Order__c = 0,	
                    Priority__c = 'Normal'	
                    ) 	
            );	
             // 1	
             periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Weekly',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Weekly',	
                    Assignee__c = users.get(1).id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Weeks',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Number_of_Occurrences__c = 1,	
                    Ends_On__c = 'Never',	
                    Sort_Order__c = 1,	
                    Priority__c = 'Normal'	
                    ) 	
            );	
             //2	
             periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Monthly',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Monthly',	
                    Assignee__c = users.get(1).id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Months',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Number_of_Occurrences__c = 1,	
                    Ends_On__c = 'Never',	
                    Sort_Order__c = 2,	
                    Priority__c = 'Normal'	
                    ) 	
            );	
             // 3	
             periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Yearly',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Yearly',	
                    Assignee__c = users.get(1).id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Years',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Number_of_Occurrences__c = 1,	
                    Ends_On__c = 'Never',	
                    Sort_Order__c = 3,	
                    Priority__c = 'Normal'		
                    ) 	
            );	
             // 4	
             periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Inactive - Date',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Inactive - Date',	
                    Assignee__c = users.get(1).id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Days',	
                    Frequency_Num__c = 1,	
                    End_Date__c = Date.Today().addDays(-1),	
                    Number_of_Occurrences__c = 1,	
                    Next_Accounting_Period_Task_Date__c	= Date.Today(),	
                    Ends_On__c = 'End Date',	
                    Sort_Order__c = 4,	
                    Priority__c = 'Normal'	
                    ) 	
            );	
             // 5	
             periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Inactive - Occurrences',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Inactive - Occurrences',	
                    Assignee__c = users.get(1).id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Days',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Number_of_Occurrences__c = 1,	
                    Ends_On__c = 'Number of Occurrences',	
                    Occurrences__c = 2,	
                    Sort_Order__c = 5,	
                    Priority__c = 'Normal'	
                    ) 	
            );	

            // 6	
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User'];	
            User testPlatformUser = new User(	
                Alias = 'inactive',	
                Email = 'acctseed.inactiveuser@as.com',	
                EmailEncodingKey = 'UTF-8',	
                LastName = 'AcctSeedPlatform',	
                LanguageLocaleKey = UserInfo.getLanguage(),	
                LocaleSidKey = Userinfo.getLocale(),	
                ProfileId = p.Id,	
                TimeZoneSidKey = Userinfo.getTimeZone().getID(),	
                UserName = 'acctseed.standardPlatformInactiveUser@testorg.com' + DateTime.now().getTime(),
                IsActive = false	
            );	
            insert testPlatformUser;	

            periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Inactive - User',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Inactive - User',	
                    Assignee__c = testPlatformUser.Id,	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '0',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Days',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Ends_On__c = 'Never',	
                    Sort_Order__c = 6,	
                    Priority__c = 'Normal'		
                ) 	
            );	
            // 7	
            periodTasks.add(	
                new Period_Task__c(	
                    Name = 'Inactive - Period',	
                    Status__c = 'In Progress',	
                    Comments__c = 'Inactive - Period',	
                    Assignee__c = UserInfo.getUserId(),	
                    Create_Date__c = Date.Today(),	
                    Accounting_Period_Offset__c = '12',	
                    Due_Date__c = Date.Today(),	
                    Frequency_Type__c = 'Days',	
                    Frequency_Num__c = 1,	
                    End_Date__c = null,	
                    Ends_On__c = 'Never',	
                    Sort_Order__c = 7,	
                    Priority__c = 'Normal'		
                ) 	
            );	

            insert periodTasks;	
        }	
        return this;	
    }

    public TestDataSuite createExchangeRates() {
        System.runAs(users.get(1)) {
            String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
            Boolean isValidCurrency = String.isBlank(newCurrencyIsoCode) ? false : isValidCurrencyForExchangeRateTable(newCurrencyIsoCode);

            exchangeRateTables = new List<Exchange_Rate__c>();

            exchangeRateTables.add(
                new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = acctPeriods[0].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(ledgers[0].Id),
                    To_Currency_Code__c = isValidCurrency ? newCurrencyIsoCode : 'USD',
                    Exchange_Rate__c = 0.95
                )
            );

            exchangeRateTables.add(
                new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = acctPeriods[1].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(ledgers[0].Id),
                    To_Currency_Code__c = isValidCurrency ? newCurrencyIsoCode : 'USD',
                    Exchange_Rate__c = 0.92
                )
            );

            exchangeRateTables.add(
                new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = acctPeriods[1].Start_Date__c.addDays(15),
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(ledgers[0].Id),
                    To_Currency_Code__c = isValidCurrency ? newCurrencyIsoCode : 'USD',
                    Exchange_Rate__c = 0.98
                )
            );

            insert exchangeRateTables;
        }
        return this;
    }

    public TestDataSuite createPaymentProcessors() {
        System.runAs(users.get(1)) {
            GL_Account__c bankGL = glAccounts[0];
            GL_Account__c feesGL = new GL_Account__c(
                Name = '5001-Payment Processing Fees',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Cost of Goods Sold',
                Sub_Type_2__c = 'Overhead'
            );
            GL_Account__c merchantGL = new GL_Account__c(
                Name = '1001-Cash',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = true,
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Cash'
            );
            GL_Account__c convenienceFeesGL = new GL_Account__c(
                Name = '4001-Convenience Fees',
                Active__c = true,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Service Revenue',
                Sub_Type_2__c = 'Service Family 1'
            );

            insert new List<GL_Account__c>{ feesGL, merchantGL, convenienceFeesGL };
            glAccounts.add(feesGL);
            glAccounts.add(merchantGL);
            glAccounts.add(convenienceFeesGL);

            paymentProcessors = new List<Payment_Processor__c>{
                new Payment_Processor__c(
                    Type__c = PaymentProcessorActions.STRIPE_TYPE,
                    Active__c = true,
                    Connected_Account_Token__c = 'acct_vpaow8envp98wnweh'
                ),
                new Payment_Processor__c(
                    Type__c = PaymentProcessorActions.STRIPE_TYPE,
                    Active__c = true,
                    Connected_Account_Token__c = 'acct_8u92oinmlksnuogwvr'
                ),
                new Payment_Processor__c(
                    Type__c = PaymentProcessorActions.CARDKNOX_TYPE,
                    Bank_GL_Account__c = bankGL.Id,
                    Merchant_GL_Account__c = merchantGL.Id,
                    Merchant_Fees_GL_Account__c = feesGL.Id,
                    PaymentSite_URL__c = 'https://example.accountingseed.com',
                    Default_Ledger__c = ledgers[0].Id
                ),
                new Payment_Processor__c(
                    Type__c = PaymentProcessorActions.CARDKNOX_TYPE,
                    Bank_GL_Account__c = bankGL.Id,
                    Merchant_GL_Account__c = merchantGL.Id,
                    Merchant_Fees_GL_Account__c = feesGL.Id,
                    PaymentSite_URL__c = 'https://test.accountingseed.com',
                    Default_Ledger__c = ledgers[0].Id,
                    Enable_Convenience_Fees__c = true,
                    Convenience_Fees_GL_Account__c = convenienceFeesGL.Id,
                    Convenience_Fee_Mapping__c = 'xCustom10',
                    Original_Amount_Mapping__c = 'xCustom09'
                )
            };
            insert paymentProcessors;

            List<Payment_Processor__c> procs = [SELECT Id,External_Key__c,Active__c FROM Payment_Processor__c WHERE Type__c = :PaymentProcessorActions.CARDKNOX_TYPE];
            List<Keys__c> keys = new List<Keys__c>{
                new Keys__c(
                    Name = procs[0].External_Key__c,
                    KeyId__c = procs[0].External_Key__c,
                    Value_1__c = 'xKey',
                    Value_2__c = 'iFieldsKey'
                ),
                new Keys__c(
                    Name = procs[1].External_Key__c,
                    KeyId__c = procs[1].External_Key__c,
                    Value_1__c = 'xKey',
                    Value_2__c = 'iFieldsKey'
                )
            };

            insert keys;

            procs[0].Active__c = true;
            procs[1].Active__c = true;
            update new List<Payment_Processor__c>{ procs[0], procs[1] };
        }
        return this;
    }

    public Boolean isValidCurrencyForExchangeRateTable(String selectedCurrency) {
        Map<String, Schema.SObjectField> field_map = Exchange_Rate__c.getSObjectType().getDescribe().fields.getMap();
        List<Schema.PicklistEntry> ple = field_map.get(GlobalVariables.PACKAGE_QUALIFIER + 'to_currency_code__c').getDescribe().getPickListValues();

        for (Schema.PicklistEntry pickListVal : ple) {
            if (pickListVal.getValue() == selectedCurrency) {
                return true;
            }
        }

        return false;
    }

    public String getCreateAvaTaxTransactionResponseBody(Billing__c billing, List<Billing_Line__c> billLines, Decimal taxRate) {
        AvaTaxService.TransactionModel trModel = new AvaTaxService.TransactionModel();
        trModel.modelSourcedFrom = 'BILLING';
        trModel.avaTaxDate = billing.Date__c;
        trModel.lines = new List<AvaTaxService.TransactionLineModel>();
        Double totalTax = 0;
        for (Billing_Line__c bLine : billLines) {
            AvaTaxService.TransactionLineModel tempLineModel = new AvaTaxService.TransactionLineModel();
            tempLineModel.lineNumber = bLine.Name;
            tempLineModel.quantity = bLine.Hours_Units__c;
            tempLineModel.taxableAmount = bLine.Hours_Units__c * bLine.Rate__c / AvaTaxHelper.getCurrencyConversionRate(billing);
            tempLineModel.taxCalculated = tempLineModel.taxableAmount * taxRate / 100;
            totalTax += tempLineModel.taxCalculated;
            trModel.lines.add(tempLineModel);
        }
        trModel.totalTax = totalTax;

        return JSON.serialize(trModel);
    }

    public String getCreateAvaTaxTransactionResponseBody(BillingCreateService.BillingModel model , Decimal taxRate) {
        AvaTaxService.TransactionModel trModel = new AvaTaxService.TransactionModel();
        trModel.modelSourcedFrom = 'BILLING';
        trModel.avaTaxDate = model.billingDate;
        trModel.lines = new List<AvaTaxService.TransactionLineModel>();
        Double totalTax = 0;
        for (BillingCreateService.BillingLineModel bLine : model.billingLines) {
            AvaTaxService.TransactionLineModel tempLineModel = new AvaTaxService.TransactionLineModel();
            tempLineModel.lineNumber = FinancialSuiteUtils.getUUID();
            tempLineModel.quantity = bLine.quantity;
            tempLineModel.taxableAmount = bLine.unitPrice * bLine.quantity;
            tempLineModel.taxCalculated = tempLineModel.taxableAmount * taxRate / 100;
            totalTax += tempLineModel.taxCalculated;
            trModel.lines.add(tempLineModel);
        }
        trModel.totalTax = totalTax;

        return JSON.serialize(trModel);
    }

    public String getCreateAvaTaxTransactionResponseBody(Recurring_Billing__c recBilling, List<Recurring_Billing_Line__c> recBillLines, Decimal taxRate) {
        AvaTaxService.TransactionModel trModel = new AvaTaxService.TransactionModel();
        trModel.modelSourcedFrom = 'RECURRING_BILLING';
        trModel.avaTaxDate = Date.today();
        trModel.lines = new List<AvaTaxService.TransactionLineModel>();
        Double totalTax = 0;
        for (Recurring_Billing_Line__c recBillingLine : recBillLines) {
            AvaTaxService.TransactionLineModel tempLineModel = new AvaTaxService.TransactionLineModel();
            tempLineModel.lineNumber = recBillingLine.Id;
            tempLineModel.quantity = recBillingLine.Quantity__c;
            tempLineModel.taxableAmount = recBillingLine.Quantity__c * recBillingLine.Rate__c;
            tempLineModel.taxCalculated = tempLineModel.taxableAmount * taxRate / 100;
            totalTax += tempLineModel.taxCalculated;
            trModel.lines.add(tempLineModel);
        }
        trModel.totalTax = totalTax;

        return JSON.serialize(trModel);
    }

    public String getCreateAvaTaxTransactionResponseBody(Opportunity opportunity, List<OpportunityLineItem> oppLineItems, Decimal taxRate) {
        AvaTaxService.TransactionModel trModel = new AvaTaxService.TransactionModel();
        trModel.modelSourcedFrom = 'OPPORTUNITY';
        trModel.avaTaxDate = Date.today();
        trModel.lines = new List<AvaTaxService.TransactionLineModel>();
        Double totalTax = 0;
        for (OpportunityLineItem oppLineItem : oppLineItems) {
            AvaTaxService.TransactionLineModel tempLineModel = new AvaTaxService.TransactionLineModel();
            tempLineModel.lineNumber = oppLineItem.Id;
            tempLineModel.quantity = oppLineItem.Quantity;
            tempLineModel.taxableAmount = oppLineItem.Quantity * oppLineItem.UnitPrice;
            tempLineModel.taxCalculated = tempLineModel.taxableAmount * taxRate / 100;
            totalTax += tempLineModel.taxCalculated;
            trModel.lines.add(tempLineModel);
        }
        trModel.totalTax = totalTax;

        return JSON.serialize(trModel);
    }

    public void archiveOldAccountingPeriods() {
        AccountingPeriodActions.isFirstRun = false;
        for (Accounting_Period__c ap : this.acctPeriods) {
            ap.Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
        }
        update this.acctPeriods;
        AccountingPeriodActions.isFirstRun = true;

        System.assertEquals(7, [SELECT COUNT() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.ARCHIVED_STATUS]);
    }

    public void createAccountingPeriodSetBasedOnCurrentDate() {
        Date acctDate = Date.newInstance(System.today().year(), System.today().month() - 3, 1);
        List<Accounting_Period__c> newPeriods = new List<Accounting_Period__c>();

        for (Integer i = 0; i < 8; i++) {
            newPeriods.add(
                new Accounting_Period__c(
                    Name =
                        String.valueOf(acctDate.year()) +
                            '-' +
                            (acctDate.month() > 9
                                ? String.valueOf(acctDate.month())
                                : '0' + String.valueOf(acctDate.month())),
                    Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                    End_Date__c = Date.newInstance(
                        acctDate.year(),
                        acctDate.month(),
                        Date.daysInMonth(acctDate.year(), acctDate.month())
                    ),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            );

            if (acctDate.month() == 12) {
                acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
            }
            else {
                acctDate = acctDate.addMonths(1);
            }
        }
        insert newPeriods;

        System.assertEquals(8, [SELECT COUNT() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);
    }

    public void closePreviousAccountingPeriodsBasedOnCurrentDate() {
        Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
        //Close 3 previous accounting periods
        List<Accounting_Period__c> closedPeriods = new List<Accounting_Period__c>{
            AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3),
            AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2),
            AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1)
        };

        AccountingPeriodActions.isFirstRun = false;
        for (Accounting_Period__c ap : closedPeriods) {
            ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
        }
        update closedPeriods;
        AccountingPeriodActions.isFirstRun = true;

        System.assertEquals(3, [SELECT COUNT() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.CLOSED_STATUS LIMIT 100]);
        System.assertEquals(5, [SELECT COUNT() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);
    }

    private Address__c getAddressObject(String street, String city, String stateProvince, String postalCode, String countryCode) {
        Address__c aNewAddress = new Address__c (
        Street__c = street,
        City__c= city,
        State_Province__c= stateProvince,
        Postal_Code__c = postalCode,
        Country_Code__c = countryCode
        );
        return aNewAddress;
    }

    //function for quickly creating two address objects
    public TestDataSuite createAddressObjects() {
        addressObjects = new List<Address__c>();
        addressObjects.add(getAddressObject('645 firstAddress St', 'Odessa', 'TX', '79760', 'US'));
        addressObjects.add(getAddressObject('356 secondAddress Dr', 'Baltimore', 'MD', '21201', 'US'));
        insert addressObjects;
        return this;
    }

    public AvaTaxService.AddressInfo addressInfoFromAddressObject(Address__c anAddress) {
        AvaTaxService.AddressInfo addrInfo = new AvaTaxService.AddressInfo();
        addrInfo.line1 = anAddress.Street__c;
        addrInfo.city = anAddress.City__c;
        addrInfo.region = anAddress.State_Province__c;
        addrInfo.country = anAddress.Country_Code__c;
        addrInfo.postalCode = anAddress.Postal_Code__c;
        return addrInfo;
    }

    public TestDataSuite createBdcAccessToken(String institutionIdentityId, String institutionId) {
        BDC_Access_Tokens__c bdcAccessToken = new BDC_Access_Tokens__c();
        bdcAccessToken.Financial_Institution_Id__c = institutionIdentityId;
        bdcAccessToken.Financial_Institution_Identity_Id__c = institutionId;
        bdcAccessToken.Source__c = 'Plaid';
        bdcAccessToken.Token__c = '123xyz';
        bdcAccessToken.Name = 'Test Access Token 1';
        insert bdcAccessToken;
        if (this.bdcAccessTokens == null) {
            this.bdcAccessTokens = new List<BDC_Access_Tokens__c>();
        }
        this.bdcAccessTokens.add(bdcAccessToken);
        return this;
    }

    public TestDataSuite createBankAccountsWithPaymentEnabled() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        System.runAs(users.get(1)) {
            if (addressObjects == null) {
                createAddressObjects();
            }

            Address__c address = [SELECT Id,City__c FROM Address__c WHERE City__c = 'Odessa'][0];

            bankAccounts = new List<Bank_Account__c>();

            bankAccounts.add(
                new Bank_Account__c(
                    Name = 'Test Account4',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                    Address__c = address.Id,
                    Account_Number__c = '123456789',
                    Routing_Number__c = '123456789',
                    Enable_for_Payment_Services__c = true
                )
            );
            insert bankAccounts;
        }
        return this;
    }

    public TestDataSuite createBankAccounts() {
        System.runAs(users.get(1)) {

            bankAccounts = new List<Bank_Account__c>();

            // 0
            bankAccounts.add(
                new Bank_Account__c(
                    Name = 'Test Account1',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled'
                )
            );
            bankAccounts.add(
                new Bank_Account__c(
                    Name = 'Test Account2',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled'
                )
            );
            bankAccounts.add(
                new Bank_Account__c(
                    Name = 'Test Account3',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled'
                )
            );

            insert bankAccounts;
        }
        return this;
    }

    public TestDataSuite createPaymentProposals() {
        System.runAs(users.get(1)) {
            paymentProposals = new List<Payment_Proposal__c>();

            // 0
            paymentProposals.add(
                new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 0',
                    Account__c = accounts.get(1).Id,
                    Proprietary_Payable_Number__c = '1',
                    Payment_Date__c = acctPeriods[1].Start_Date__c,
                    Ledger__c = ledgers[0].Id,
                    Type__c = 'Check',
                    Bank_GL_Account__c = glAccounts[0].id,
                    Aggregate_By_Payee__c = true,
                    Status__c = 'Approved'
                )
            );
            paymentProposals.add(
                new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 1',
                    Account__c = accounts.get(1).Id,
                    Proprietary_Payable_Number__c = '2',
                    Payment_Date__c = acctPeriods[1].Start_Date__c,
                    Ledger__c = ledgers[0].Id,
                    Type__c = 'Check',
                    Bank_GL_Account__c = glAccounts[0].id,
                    Aggregate_By_Payee__c = false,
                    Status__c = 'Approved'
                )
            );
            paymentProposals.add(
                new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 2',
                    Account__c = accounts.get(1).Id,
                    Proprietary_Payable_Number__c = '2',
                    Payment_Date__c = acctPeriods[1].Start_Date__c,
                    Ledger__c = ledgers[0].Id,
                    Type__c = 'Check',
                    Bank_GL_Account__c = glAccounts[0].id,
                    Aggregate_By_Payee__c = true,
                    Status__c = 'Approved'
                )
            );

            insert paymentProposals;

            List<Payment_Proposal_Line__c> parentPPLs = new List<Payment_Proposal_Line__c>();
            paymentProposalLines = new List<Payment_Proposal_Line__c>();

            //parent Line
            Payment_Proposal_Line__c parentPPL = new Payment_Proposal_Line__c(Payment_Proposal__c = paymentProposals[0].Id,Vendor__c = accounts[0].Id);
            parentPPLs.add(parentPPL);

            Payment_Proposal_Line__c parentPPLwithCreditMemos = new Payment_Proposal_Line__c(Payment_Proposal__c = paymentProposals[2].Id,Vendor__c = accounts[0].Id);
            parentPPLs.add(parentPPLwithCreditMemos);

            insert parentPPLs;
            //1 PP[0]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[0].Id,
                                            Payment_Proposal__c = paymentProposals[0].Id,
                                            Vendor__c = payables[0].Vendor__c,
                                            Parent__c = parentPPL.Id)
            );



            //2 PP[0]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[5].Id,
                                            Payment_Proposal__c = paymentProposals[0].Id,
                                            Vendor__c = payables[5].Vendor__c,
                                            Parent__c = parentPPL.Id)
            );

            //3 PP[1]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[0].Id,
                                            Payment_Proposal__c = paymentProposals[1].Id,
                                            Vendor__c = payables[0].Vendor__c)
            );

            //4 PP[1]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[1].Id,
                                            Payment_Proposal__c = paymentProposals[1].Id,
                                            Vendor__c = payables[1].Vendor__c)
            );

            //5 PP[1]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[3].Id,
                                            Payment_Proposal__c = paymentProposals[1].Id,
                                            Vendor__c = payables[3].Vendor__c)
            );

            //6 PP[1]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[5].Id,
                                            Payment_Proposal__c = paymentProposals[1].Id,
                                            Vendor__c = payables[5].Vendor__c)
            );

            //7 PP[2]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c =  -1,
                                            Payable__c = payables[4].Id,
                                            Payment_Proposal__c = paymentProposals[2].Id,
                                            Vendor__c = payables[4].Vendor__c,
                                            Parent__c = parentPPLwithCreditMemos.Id)
            );

             //8 PP[2]
             paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[0].Id,
                                            Payment_Proposal__c = paymentProposals[2].Id,
                                            Vendor__c = payables[0].Vendor__c,
                                            Parent__c = parentPPLwithCreditMemos.Id)
            );


            //9 PP[2]
            paymentProposalLines.add(
                new Payment_Proposal_Line__c(Amount__c = 1,
                                            Payable__c = payables[5].Id,
                                            Payment_Proposal__c = paymentProposals[2].Id,
                                            Vendor__c = payables[5].Vendor__c,
                                            Parent__c = parentPPLwithCreditMemos.Id)
            );


            insert paymentProposalLines;
        }
        return this;
    }
}