public with sharing class IntegrationTestDataFactory {

    public TestDataSuite testData;
    public List<User> users;
    public List<Accounting_Period__c> acctPeriods;
    public Map<String, Accounting_Period__c> acctPeriodMap;
    public Account accountCustomerVendor;
    public List<Product2> products;

    public List<Ledger__c> ledgers;
    public List<Ledger_Hierarchy__c> ledgerHierarchies;
    public Map<String, Ledger__c> ledgersMap;
    public Ledger_Custom_Settings__c ledgerSettings;
    public List<GL_Account__c> glAccounts;
    public Map<String, GL_Account__c> glAccountsMap;
    public List<Billing__c> billings;
    public List<Billing_Line__c> billingLines;
    public List<Account_Payable__c> payables;
    public List<Account_Payable_Line__c> payableLines;
    public List<Cash_Receipt__c> cashReceipts;
    public List<Cash_Disbursement_Batch__c> cashDisbursementBatch;
    public List<Cash_Disbursement__c> cashDisbursements;
    public List<Journal_Entry__c> journalEntries;
    public List<Journal_Entry_Line__c> journalEntryLines;
    public List<Address__c> addressObjects;
    
    @TestVisible
    private static IntegrationTestDataFactory instance;

    private IntegrationTestDataFactory(Boolean isBaseInitNeeded) {
        initilizeTestData(isBaseInitNeeded);
    }

    public static IntegrationTestDataFactory getInstance() {
        return getInstance(false);
    }

    public static IntegrationTestDataFactory getInstance(Boolean isBaseInitNeeded) {
        if (instance == NULL) {
            instance = new IntegrationTestDataFactory(isBaseInitNeeded);
        }
        return instance;
    }

    private void initilizeTestData(Boolean isBaseInitNeeded){
        if (isBaseInitNeeded) {
            //create base data (ledgers, glaccounts, accoutning settings, accounting periods, etc...)
            testData = TestDataSuite.getInstance(true);
            createAccountingPeriods();
            createLedgers();
        }

        testData = TestDataSuite.getInstance();
        users = testData.users;
        accountCustomerVendor = testData.accounts[0];
        
        //add GL Accounts to Map/Collection
        glAccounts = testData.glAccounts;
        glAccountsMap = new Map<String, GL_Account__c>();
        for(GL_Account__c glA: testData.glAccounts){
            glAccountsMap.put(glA.Name, glA);
        }

        //add Accounting Periods to Map/Collection
        acctPeriods = AccountingPeriodHandler.getInstance().getAllAccountingPeriods();
        acctPeriodMap = new Map<String, Accounting_Period__c>();
        for(Accounting_Period__c aP : acctPeriods){
            acctPeriodMap.put(aP.Name, aP);
        }

        //add all Ledgers used for integration test to Map/Collection
        LedgerHandler LH = LedgerHandler.getInstanceWithoutSharing();
        ledgersMap = new Map<String, Ledger__c>();
        for(Ledger__c ledger : LH.getLedgerByName(new Set<String>{'Acme Nutrition','Acme Home', 'Acme Consolidation', 'Acme Consolidation - EL' })){
            ledgersMap.put(ledger.Name, ledger);
        }
       
    }
    
    private void createAccountingPeriods() {
        // delete existing periods created in the base data initilization
        delete testData.acctPeriods;

        acctPeriods = new List<Accounting_Period__c>();
         // 0
         acctPeriods.add(
            new Accounting_Period__c(
                Name = '2021-08',
                Start_Date__c = Date.newInstance(2021, 8, 1),
                End_Date__c = Date.newInstance(2021, 8, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        // 1
        acctPeriods.add(
            new Accounting_Period__c(
                Name = '2021-09',
                Start_Date__c = Date.newInstance(2021, 9, 1),
                End_Date__c = Date.newInstance(2021, 9, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );

        insert acctPeriods;

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

    public void createAddressObjects() {
        addressObjects = new List<Address__c>();
        addressObjects.add(getAddressObject('645 firstAddress St', 'Odessa', 'TX', '79760', 'US'));
        addressObjects.add(getAddressObject('356 secondAddress Dr', 'Baltimore', 'MD', '21201', 'US'));
        insert addressObjects;
    }

    public void createProducts() {
        System.runAs(testData.users[1]) {

            products = new List<Product2>();
            // 0
            products.add(
                new Product2(
                    Name = 'Test Prod 1',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 100
                )
            );
            // 1
            products.add(
                new Product2(
                    Name = 'Test Prod 2',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 200
                )
            );
            // 2
            products.add(
                new Product2(
                    Name = 'Test Prod Kit',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Inventory_Type__c = 'Kit',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 50
                )
            );
            // 3
            products.add(
                new Product2(
                    Name = 'Taxable Product',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Accounting_Type__c = 'Taxable Product',
                    Tax_Rate__c = 7.25
                )
            );
            // 4
            products.add(
                new Product2(
                    Name = 'Tax Rate',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Accounting_Type__c = 'Tax Rate',
                    Tax_Rate__c = 5.5
                )
            );
            // 5
            products.add(
                new Product2(
                    Name = 'Avalara Sales Tax',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Accounting_Type__c = 'Taxable Product'
                )
            );

            insert products;
        }
    }

    private void createLedgers() {
        
        if (addressObjects == null) {
            createAddressObjects();
        }
        if (products == null) {
            createProducts();
        }
        
        Tax_Settings__c taxSetting = new Tax_Settings__c();
        taxSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
        taxSetting.Origin_Address__c = addressObjects[0].Id;
        taxSetting.Sales_Tax_GL_Account__c = testData.glAccounts[28].Id;
        taxSetting.Sales_Tax_Product__c = products[5].Id;
        taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
        insert taxSetting;
        
        // delete existing periods created in the base data initilization
        ledgers = new List<Ledger__c>();

        ledgers.add(
            new Ledger__c(
                Name = 'Acme Nutrition',
                Type__c = 'Transactional',
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );

        ledgers.add(
            new Ledger__c(
                Name = 'Acme Home',
                Type__c = 'Transactional',
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            )
        );

        ledgers.add(
            new Ledger__c(
                Name = 'Acme Consolidation',
                Type__c = 'Consolidations-Transactional'
            )
        );
        insert ledgers;
    }

    public IntegrationTestDataFactory createLedgerHierarchies() {
        List<Ledger_Hierarchy__c> L1 = new List<Ledger_Hierarchy__c>();
        List<Ledger_Hierarchy__c> L2 = new List<Ledger_Hierarchy__c>();


        L1.add(
            new Ledger_Hierarchy__c(
                Name = 'Acme Consolidation',
                Ledger__c = ledgersMap.get('Acme Consolidation').Id
            )
        );
        
        insert L1;

        L2 = new List<Ledger_Hierarchy__c> {
            new Ledger_Hierarchy__c(
                Name = 'Acme Nutrition',
                Ledger__c = ledgersMap.get('Acme Nutrition').Id,
                Parent_Ledger_Hierarchy__c = L1[0].Id
            ),
            new Ledger_Hierarchy__c(
                Name = 'Acme Home',
                Ledger__c = ledgersMap.get('Acme Home').Id,
                Parent_Ledger_Hierarchy__c = L1[0].Id
            )
        };
        
        insert L2;
        
        ledgerHierarchies = new List<Ledger_Hierarchy__c>();
        ledgerHierarchies.addAll(L1);
        ledgerHierarchies.addAll(L2);

        return this;
    }

    public IntegrationTestDataFactory createBillings() {
        return createBillings(false);
    }

    public IntegrationTestDataFactory createBillings(Boolean doPost) {
        System.runAs(testData.users[1]) {
            // create billings
            billings = new List<Billing__c> {
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-08').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Nutrition').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-08').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Nutrition').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-08').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Nutrition').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-08').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Home').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-09').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Nutrition').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-09').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Nutrition').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-09').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Nutrition').Id
                    ),
                    new Billing__c(
                        Accounting_Period__c = acctPeriodMap.get('2021-09').id,
                        Customer__c = accountCustomerVendor.Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Billing_Format__c = testData.billingFormats[0].Id,
                        Ledger__c = ledgersMap.get('Acme Home').Id
                    )
                };
                insert billings;
    
                // create billing lines
                billingLines = new List<Billing_Line__c> {
                // 1
                    new Billing_Line__c(
                        Billing__c = billings[0].Id,
                        Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id, 
                        Hours_Units__c = 1,
                        Rate__c = 4161.56
                    ),
    
                // 2
                    new Billing_Line__c(
                        Billing__c = billings[1].Id,
                        Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 15000.45
                    ),
    
                //3    
                    new Billing_Line__c(
                        Billing__c = billings[2].Id,
                        Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4010-Services Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 7258.05
                    ),
    
                //4    
                    new Billing_Line__c(
                        Billing__c = billings[3].Id,
                        Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 10000
                    ),
    
                //5    
                    new Billing_Line__c(
                        Billing__c = billings[4].Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 668.56
                    ),
    
                //6    
                    new Billing_Line__c(
                        Billing__c = billings[5].Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 352.22
                    ),
    
                //7    
                    new Billing_Line__c(
                        Billing__c = billings[6].Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4010-Services Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 584.73
                    ),
    
                //8    
                    new Billing_Line__c(
                        Billing__c = billings[7].Id,
                        Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                        Revenue_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                        Hours_Units__c = 1,
                        Rate__c = 8058.69
                    )
    
                };
                insert billingLines;

            if (doPost) {
                AbstractPostHandler postHandler = new BillingPostHandler();
                List<PostResult> postResults = postHandler.post(this.billings);
                System.assertEquals(true, postResults[0].isSuccess);                
                
            }
        }

        return this;
    }

    public IntegrationTestDataFactory createPayables() {
        return createPayables(false);
    }

    public IntegrationTestDataFactory createPayables(Boolean doPost) {
        System.runAs(testData.users[1]) {
            payables = new List<Account_Payable__c>();

            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '1',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-08').End_Date__c,
                    Vendor__c = accountCustomerVendor.Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );

            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-08').End_Date__c,
                    Contact__c = testData.contacts[0].Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );

             payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '3',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-08').End_Date__c,
                    Contact__c = testData.contacts[0].Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );

             payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '4',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-08').End_Date__c,
                    Contact__c = testData.contacts[0].Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );

            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '5',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-09').End_Date__c,
                    Vendor__c = accountCustomerVendor.Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '6',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-09').End_Date__c,
                    Vendor__c = accountCustomerVendor.Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '7',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-09').End_Date__c,
                    Vendor__c = accountCustomerVendor.Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '8',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Due_Date__c = acctPeriodMap.get('2021-09').End_Date__c,
                    Vendor__c = accountCustomerVendor.Id,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
           

            insert payables;

            payableLines = new List<Account_Payable_Line__c>();

            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[0].Id,
                    Amount__c = 10000,
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('6000-Marketing Expense').Id
                )
            );

            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[1].Id,
                    Amount__c = 541,
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('7000-Facilities Expense').Id
                )
            );
            //2
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[2].Id,
                    Amount__c = 4161.56,
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('6000-Marketing Expense').Id
                )
            );
            //3
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[3].Id,
                    Amount__c = 8258.05,
                    Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('6000-Marketing Expense').Id
                )
            );
            //4
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[4].Id,
                    Amount__c = 8058.69,
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('6000-Marketing Expense').Id
                )
            );
            //5
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[5].Id,
                    Amount__c = 5259.17,
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('7000-Facilities Expense').Id
                )
            );
            //6
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[6].Id,
                    Amount__c = 1854.89,
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('6000-Marketing Expense').Id
                )
            );
            //7
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[7].Id,
                    Amount__c = 5754.09,
                    Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Expense_GL_Account__c = glAccountsMap.get('6000-Marketing Expense').Id
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

    public IntegrationTestDataFactory createCashReceipts() {
        System.runAs(testData.users.get(1)) {
            cashReceipts = new List<Cash_Receipt__c>();
            //1
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 4161.56,
                    Payment_Reference__c = '0000000001',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('1205-Unapplied A/R').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            //2
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 15000.45,
                    Payment_Reference__c = '0000000002',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('1205-Unapplied A/R').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            //3
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 7258.05,
                    Payment_Reference__c = '0000000003',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
             //4
             cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 10000,
                    Payment_Reference__c = '0000000004',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('3000-Owners Equity').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );

            //5
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 668.56,
                    Payment_Reference__c = '0000000005',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('1205-Unapplied A/R').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            //6
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 352.22,
                    Payment_Reference__c = '0000000006',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('1205-Unapplied A/R').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            //7
            cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 584.73,
                    Payment_Reference__c = '0000000007',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
             //8
             cashReceipts.add(
                new Cash_Receipt__c(
                    Account__c = accountCustomerVendor.Id,
                    Amount__c = 8058.69,
                    Payment_Reference__c = '0000000008',
                    Status__c = 'Approved',
                    Receipt_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Credit_GL_Account__c = glAccountsMap.get('3000-Owners Equity').Id,
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );


            insert cashReceipts;

           
        }

        return this;
    }
    
    public IntegrationTestDataFactory createCashDisbursementBatches() {
        System.runAs(testData.users[1]) {
            cashDisbursementBatch = new List<Cash_Disbursement_Batch__c>();
            cashDisbursementBatch.add(
                new Cash_Disbursement_Batch__c(
                    Starting_Check_Number__c = 1,
                    Name = 'Test Batch'
                )
            );

            insert cashDisbursementBatch;
        }
        return this;
    }

    public IntegrationTestDataFactory createCashDisbursements(Boolean doPost) {

        System.runAs(testData.users[1]) {

            System.assertNotEquals(NULL, cashDisbursementBatch, 'CDBs must be created first.');
            System.assertNotEquals(true, cashDisbursementBatch.isEmpty(), 'CDBs must be created first.');

            cashDisbursements = new List<Cash_Disbursement__c>();
            //1
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('2030-Accrued Payroll').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 10000,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 1',
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            //2
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('2020-Accrued Expenses').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 541,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 2',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
            //3
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('2020-Accrued Expenses').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 4161.56,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 3',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
            //4
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 8258.05,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 4',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
             //5
             cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('2030-Accrued Payroll').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 8058.69,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 5',
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );
            //6
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('2020-Accrued Expenses').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 5259.17,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 6',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
            //7
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('2020-Accrued Expenses').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 1854.89,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 7',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );
            //8
            cashDisbursements.add(
                new Cash_Disbursement__c(
                    Cash_Disbursement_Batch__c = cashDisbursementBatch[0].Id,
                    Disbursement_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Bank_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Debit_GL_Account__c = glAccountsMap.get('4000-Product Revenue').Id,
                    Vendor__c = accountCustomerVendor.Id,
                    Type__c = 'Check',
                    Amount__c = 5754.09,
                    Source__c = 'Manual',
                    Status__c = 'Approved',
                    Reference__c = 'the reference 8',
                    Ledger__c = ledgersMap.get('Acme Home').Id
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

    public IntegrationTestDataFactory createJournalEntries() {
        return createJournalEntries(false);
    }

    public IntegrationTestDataFactory createJournalEntries(Boolean doPost) {
        testData.createCashFlowCategories(true);
         System.runAs(testData.users[1]) {
            journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Journal_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 2',
                    Accounting_Period__c = acctPeriodMap.get('2021-08').Id,
                    Journal_Date__c = acctPeriodMap.get('2021-08').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 3',
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Journal_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = ledgersMap.get('Acme Nutrition').Id
                )
            );

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 4',
                    Accounting_Period__c = acctPeriodMap.get('2021-09').Id,
                    Journal_Date__c = acctPeriodMap.get('2021-09').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = ledgersMap.get('Acme Home').Id
                )
            );

            insert journalEntries;

            journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 1',
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 150700.4,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 2',
                    Cash_Flow_Category__c = testData.cashFlowCategories[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 900.4,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 3',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 100.4,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 4',
                    Cash_Flow_Category__c = testData.cashFlowCategories[8].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 546.66,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 5',
                    Cash_Flow_Category__c = testData.cashFlowCategories[10].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 154081.65,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 6',
                    Cash_Flow_Category__c = testData.cashFlowCategories[11].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 10000,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 7',
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 11234.45,
                    GL_Account__c = glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 8'
     
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Credit__c = 1484.64,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 9',
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Debit__c = 111.03,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 10',
                    Cash_Flow_Category__c = testData.cashFlowCategories[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 11',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Debit__c = 9073.22,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 12',
                    Cash_Flow_Category__c = testData.cashFlowCategories[8].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Debit__c = 8002.07,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 13',
                    Cash_Flow_Category__c = testData.cashFlowCategories[10].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Debit__c = 720.49,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 14',
                    Cash_Flow_Category__c = testData.cashFlowCategories[11].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Debit__c = 7571.28,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 15',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[1].Id,
                    Credit__c = 19831.89,
                    GL_Account__c = glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 16'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Debit__c = 552.61,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 17',
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Debit__c = 209.15,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 18',
                    Cash_Flow_Category__c = testData.cashFlowCategories[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Debit__c = 132.65,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 19',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Debit__c = 3.29,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 20',
                    Cash_Flow_Category__c = testData.cashFlowCategories[8].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Credit__c = 235.92,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 21',
                    Cash_Flow_Category__c = testData.cashFlowCategories[10].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Debit__c = 506.42,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 22',
                    Cash_Flow_Category__c = testData.cashFlowCategories[11].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Debit__c = 263.29,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 23',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[2].Id,
                    Credit__c = 1431.49,
                    GL_Account__c = glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 24'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Credit__c = 1598.98,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 25',
                    Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Debit__c = 907.95,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 26',
                    Cash_Flow_Category__c = testData.cashFlowCategories[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Debit__c = 653.29,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 27',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Debit__c = 463.26,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 28',
                    Cash_Flow_Category__c = testData.cashFlowCategories[8].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Debit__c = 22.66,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 29',
                    Cash_Flow_Category__c = testData.cashFlowCategories[10].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Credit__c = 209.15,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 30',
                    Cash_Flow_Category__c = testData.cashFlowCategories[11].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Debit__c = 38.37,
                    GL_Account__c = glAccountsMap.get('1000-Cash').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 31',
                    Cash_Flow_Category__c = testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[3].Id,
                    Credit__c = 277.4,
                    GL_Account__c = glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Units__c = 1,
                    Reference__c = 'the reference 32'
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

   
    
}