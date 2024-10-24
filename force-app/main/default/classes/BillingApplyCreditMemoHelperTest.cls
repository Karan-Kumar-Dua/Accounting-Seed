@IsTest
public with sharing class BillingApplyCreditMemoHelperTest {
    
    private static void post(List<Billing__c> billings) {
        for (PostResult result : BillingPostService.postBillings(billings)) {
            System.assertEquals(true, result.isSuccess);
        }
    }

    private static Billing__c getBilling(Id billingId) {
        return getBillings(new List<Id> { billingId }).get(0);
    }

    private static List<Billing__c> getBillings(List<Id> billingIds) {
        return [
            SELECT Id, Name, Type__c, Balance__c, Total__c, Date__c, Accounting_Period__c, LastModifiedDate 
            FROM Billing__c 
            WHERE Id IN :billingIds
        ];
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void saveAppliedAccountingPeriodMissing() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = null;
            saveItem.variableCredit = 1;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String> { JSON.serialize(saveItem) };
            AuraHandledException expectedEx;

            Test.startTest();
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex; 
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedExMsg = String.format(BillingApplyCreditMemoHelper.APPLIED_DATE_INVALID, new String[] { saveItem.derivedName });
            System.assertEquals(
                expectedExMsg,
                ((BillingApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), BillingApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void saveNoCorrespondingAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = Date.today().addYears(50);
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            AuraHandledException expectedEx;
            Test.startTest();
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            String expectedExMsg = String.format(BillingApplyCreditMemoHelper.APPLIED_DATE_INVALID, new String[] { saveItem.derivedName });
            System.assertEquals(
                expectedExMsg,
                ((BillingApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), BillingApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void saveAppliedAccountingPeriodLessThanInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            testData.billings[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.billings[0];

            post(new List<Billing__c>{testData.billings[0], testData.billings[2]});

            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 1;

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch(AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveAppliedAccountingPeriodLessThanCredit() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            testData.billings[2].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.billings[2];

            post(new List<Billing__c>{testData.billings[0], testData.billings[2]});

            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 1;

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch(AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveOverappliedCredit() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = (credit.Balance__c - 1) * -1;

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            Test.startTest();
            AuraHandledException expectedEx;
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveOverappliedInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // credit amount larger than invoice amount
            testData.billingLines[4].Rate__c = 10000;
            update testData.billingLines[4];

            post(new List<Billing__c>{testData.billings[0], testData.billings[2]});

            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            // apply credit balance which should exceed invoice balance
            saveItem.variableCredit = credit.Balance__c * -1;

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            AuraHandledException expectedEx;

            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch(AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveOverappliedCreditonMultipleInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Billing__c> invoices = getBillings(new List<Id> {
                testData.billings[0].Id,
                testData.billings[1].Id });
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem1 = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem1.billingId = invoices.get(0).Id;
            saveItem1.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem1.variableCredit = 150;

            BillingApplyCreditMemoHelper.SaveItem saveItem2 = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem2.billingId = invoices.get(1).Id;
            saveItem2.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem2.variableCredit = 150;

            List<String> updates = new List<String> { JSON.serialize(saveItem1), JSON.serialize(saveItem2) };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch(AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveWriteConflict() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            Datetime lastWrite = Datetime.now().addHours(1);

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, lastWrite, null);
            } catch(AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                BillingApplyCreditMemoHelper.CREDIT_MEMO_MODIFIED_ERROR,
                ((BillingApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), BillingApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void save() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            Test.startTest();
            BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();

            Billing_Credit_Memo__c bcm = [
                SELECT Billing_Invoice__c, Amount__c, Applied_Date__c
                FROM Billing_Credit_Memo__c
                WHERE Billing_Credit_Memo__c = :credit.Id
                LIMIT 1
            ];
            System.assert(bcm.Billing_Invoice__c == saveItem.billingId);
            System.assertEquals(saveItem.appliedDate, bcm.Applied_Date__c);
            System.assertEquals(saveItem.variableCredit, bcm.Amount__c * -1);
        }
    }

    @IsTest
    public static void saveChildAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            // create account hierarchy
            Account childAccount = testData.accounts[1];
            childAccount.parentId = testData.accounts[0].Id;
            update childAccount;

            // associate billing with child account
            testData.billings[1].Customer__c = childAccount.Id;
            update testData.billings[1];

            post(new List<Billing__c>{ testData.billings[2], testData.billings[1], testData.billings[0] });

            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Billing__c> invoices = getBillings(new List<Id> {
                testData.billings[0].Id,
                testData.billings[1].Id });
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            BillingApplyCreditMemoHelper.SaveItem saveItem1 = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem1.billingId = invoices.get(0).Id;
            saveItem1.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem1.variableCredit = 5;
            saveItem1.derivedName = 'item 1';

            BillingApplyCreditMemoHelper.SaveItem saveItem2 = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem2.billingId = invoices.get(1).Id;
            saveItem2.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem2.variableCredit = 5;
            saveItem2.derivedName = 'item 2';

            List<String> updates = new List<String> { JSON.serialize(saveItem1), JSON.serialize(saveItem2) };

            Test.startTest();
            BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();

            for (Billing_Credit_Memo__c bcm : [
                SELECT Billing_Invoice__c, Amount__c, Applied_Date__c
                FROM Billing_Credit_Memo__c
                WHERE Billing_Credit_Memo__c = :credit.Id
            ]) {
                System.assert(bcm.Billing_Invoice__c == saveItem1.billingId || bcm.Billing_Invoice__c == saveItem2.billingId );
                System.assertEquals(saveItem1.appliedDate, bcm.Applied_Date__c);
                System.assertEquals(saveItem1.variableCredit, bcm.Amount__c * -1);
            }
        }
    }

    @IsTest
    public static void saveUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);
            Billing_Credit_Memo__c junction = new Billing_Credit_Memo__c(
                Billing_Credit_Memo__c = credit.Id,
                Billing_Invoice__c = invoice.Id,
                Accounting_Period__c = credit.Accounting_Period__c,
                Amount__c = -5
            );
            insert junction;

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            credit = getBilling(credit.Id);
            BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();

            List<Billing_Credit_Memo__c> bcms = [
                SELECT Billing_Invoice__c, Amount__c, Applied_Date__c
                FROM Billing_Credit_Memo__c
                WHERE Billing_Credit_Memo__c = :credit.Id
            ];

            System.assertEquals(1, bcms.size());
            System.assertEquals(saveItem.appliedDate, bcms.get(0).Applied_Date__c);
            System.assertEquals(saveItem.billingId, bcms.get(0).Billing_Invoice__c);
            System.assertEquals(saveItem.appliedDate, bcms.get(0).Applied_Date__c);
            System.assertEquals(saveItem.variableCredit, bcms.get(0).Amount__c * -1);
        }
    }

     @IsTest
    public static void saveDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);
            Billing_Credit_Memo__c junction = new Billing_Credit_Memo__c(
                Billing_Credit_Memo__c = credit.Id,
                Billing_Invoice__c = invoice.Id,
                Accounting_Period__c = credit.Accounting_Period__c,
                Amount__c = -5
            );
            insert junction;

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 0;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            credit = getBilling(credit.Id);
            BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();

            List<Billing_Credit_Memo__c> bcms = new List<Billing_Credit_Memo__c>();
            bcms = [
                SELECT Billing_Invoice__c, Amount__c, Applied_Date__c
                FROM Billing_Credit_Memo__c
                WHERE Billing_Credit_Memo__c = :credit.Id
            ];
            System.assertEquals(0, bcms.size());
        }
    }

    @IsTest
    public static void getApplicableInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Id> invoiceIds = new List<Id> {
                testData.billings[0].Id,
                testData.billings[1].Id };
            List<Billing__c> invoices = getBillings(invoiceIds);
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(2, response.size());
            System.assert(invoiceIds.contains(response.get(0).billingId));
            System.assert(invoiceIds.contains(response.get(1).billingId));
        }
    }

    @IsTest
    public static void getApplicableInvoicesLimitResults() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Id> invoiceIds = new List<Id> {
                testData.billings[0].Id,
                testData.billings[1].Id };
            List<Billing__c> invoices = getBillings(invoiceIds);
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);

            Integer maxResults = 1;

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.getApplicableInvoices(credit.Id, maxResults, filterJson);
            Test.stopTest();

            System.assertEquals(maxResults, response.size());
        }
    }

    @IsTest
    public static void getApplicableInvoicesFilteredBillingNumber() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Billing__c> invoices = getBillings(new List<String> {
                testData.billings[0].Id,
                testData.billings[1].Id
            });

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            filter.billingNumber = invoices.get(0).Name;
            String filterJson = JSON.serialize(filter);

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(invoices.get(0).Id, response.get(0).billingId);
        }
    }

    @IsTest
    public static void getApplicableInvoicesFilteredBillingDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users[1]) {
            Date newInvoiceDate = Date.today().addDays(-5);
            testData.billings[0].Date__c = newInvoiceDate;
            update testData.billings[0];

            BillingPostService.postBillings(new List<Billing__c> {
                testData.billings[0],
                testData.billings[1],
                testData.billings[2]
            });

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            filter.billingDateStart = newInvoiceDate.addDays(-5);
            filter.billingDateEnd = newInvoiceDate.addDays(5);
            String filterJson = JSON.serialize(filter);

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.getApplicableInvoices(testData.billings[2].Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(testData.billings[0].Id, response.get(0).billingId);
        }
    }

    @IsTest
    public static void getApplicableInvoicesFilteredDueDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users[1]) {
            Date newInvoiceDueDate = Date.today().addDays(-5);
            testData.billings[0].Due_Date2__c = newInvoiceDueDate;
            update testData.billings[0];

            BillingPostService.postBillings(new List<Billing__c> {
                testData.billings[0],
                testData.billings[1],
                testData.billings[2]
            });

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            filter.dueDateStart = newInvoiceDueDate.addDays(-5);
            filter.dueDateEnd = newInvoiceDueDate.addDays(5);
            String filterJson = JSON.serialize(filter);

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.getApplicableInvoices(testData.billings[2].Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(testData.billings[0].Id, response.get(0).billingId);
        }
    }

    @IsTest
    public static void getApplicableInvoicesFilteredAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Hours_Units__c = 25;
            update testData.billingLines[0];

            BillingPostService.postBillings(new List<Billing__c> {
                testData.billings[0],
                testData.billings[1],
                testData.billings[2]
            });

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            filter.billingAmountStart = 490;
            filter.billingAmountEnd = 510;
            String filterJson = JSON.serialize(filter);

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            response = BillingApplyCreditMemoHelper.getApplicableInvoices(testData.billings[2].Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(testData.billings[0].Id, response.get(0).billingId);
        }
    }

    @IsTest
    public static void getApplicableInvoicesChildAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            // create account hierarchy
            Account childAccount = testData.accounts[1];
            childAccount.parentId = testData.accounts[0].Id;
            update childAccount;

            // associate billing with child account
            testData.billings[1].Customer__c = childAccount.Id;
            update testData.billings[1];

            post(new List<Billing__c>{ testData.billings[2], testData.billings[1], testData.billings[0] });

            Billing__c credit = getBilling(testData.billings[2].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Id> invoiceIds = new List<Id> {
                testData.billings[0].Id,
                testData.billings[1].Id };
            List<Billing__c> invoices = getBillings(invoiceIds);
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(2, response.size());
            System.assert(invoiceIds.contains(response.get(0).billingId));
            System.assert(invoiceIds.contains(response.get(1).billingId));
        }
    }

    @IsTest
    public static void getApplicableInvoices_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Billing__c credit = testData.billings[2];
                Billing__c invoice1 = testData.billings[1];
                Billing__c invoice2 = testData.billings[0];

                credit.Currency_Conversion_Rate__c = 1.2;
                invoice1.Currency_Conversion_Rate__c = 1.5;
                invoice2.Currency_Conversion_Rate__c = 1.2;

                TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Billing__c.Currency_Conversion_Rate__c});
                update new List<Billing__c>{ credit, invoice1, invoice2 };
                TriggerObserver.reset();

                post(new List<Billing__c>{ credit, invoice1, invoice2 });

                credit = getBilling(credit.Id);
                System.assertEquals('Credit Memo', credit.Type__c);
                List<Billing__c> invoices = getBillings(new List<Id> { invoice1.Id, invoice2.Id });
                System.assertEquals('Invoice', invoices.get(0).Type__c);
                System.assertEquals('Invoice', invoices.get(1).Type__c);

                List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

                BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
                String filterJson = JSON.serialize(filter);

                Test.startTest();
                response = BillingApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
                Test.stopTest();

                System.assertEquals(1, response.size());
                System.assertEquals(invoice2.Id, response.get(0).billingId);
            }

        } catch (TestDataSuite.TestDataSuiteException ex) {}
    }

    @IsTest
    public static void getApplicableInvoicesMultiCurrencyWithLegacyRecords_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Billing__c credit = testData.billings[2];
                Billing__c invoice1 = testData.billings[1];
                Billing__c invoice2 = testData.billings[0];

                credit.Currency_Conversion_Rate__c = null;
                invoice1.Currency_Conversion_Rate__c = 1;
                invoice2.Currency_Conversion_Rate__c = null;

                TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Billing__c.Currency_Conversion_Rate__c});
                update new List<Billing__c>{ credit, invoice1, invoice2 };
                TriggerObserver.reset();

                post(new List<Billing__c>{ credit, invoice1, invoice2 });

                credit = getBilling(credit.Id);
                System.assertEquals('Credit Memo', credit.Type__c);
                List<Id> invoiceIds = new List<Id> { invoice1.Id, invoice2.Id };
                List<Billing__c> invoices = getBillings(invoiceIds);
                System.assertEquals('Invoice', invoices.get(0).Type__c);
                System.assertEquals('Invoice', invoices.get(1).Type__c);

                List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

                BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
                String filterJson = JSON.serialize(filter);

                Test.startTest();
                response = BillingApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
                Test.stopTest();

                System.assertEquals(2, response.size());
                System.assert(invoiceIds.contains(response.get(0).billingId));
                System.assert(invoiceIds.contains(response.get(1).billingId));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {}
    }

    @IsTest
    public static void getApplicableInvoicesFakeBillingId() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                response = BillingApplyCreditMemoHelper.getApplicableInvoices('123abc', 10, filterJson);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void getCombinedInfo() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        BillingApplyCreditMemoHelper.CombinedInfoWrapper response;

        System.runAs(testData.users[1]) {
            Test.startTest();
            response = BillingApplyCreditMemoHelper.getCombinedInfo(testData.billings[2].Id, 10, null);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.isMultiCurrencyEnabled);
            System.assertNotEquals(null, response.creditMemo);
            System.assertNotEquals(0, response.invoices.size());
            System.assertEquals(testData.billings[2].Id, response.creditMemo.Id);
        }
    }

    @IsTest
    public static void getCombinedInfoFakeId() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            BillingApplyCreditMemoHelper.CombinedInfoWrapper response;

            AuraHandledException expectedEx;
            Test.startTest();
            try {
                response = BillingApplyCreditMemoHelper.getCombinedInfo('abc123', 10, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void getCombinedInfoExistingBCM() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true);

        System.runAs(testData.users[1]) {
            Billing_Credit_Memo__c junction = new Billing_Credit_Memo__c(
                Billing_Credit_Memo__c = testData.billings[2].Id,
                Billing_Invoice__c = testData.billings[0].Id,
                Accounting_Period__c = testData.billings[2].Accounting_Period__c,
                Amount__c = -5
            );
            insert junction;

            BillingApplyCreditMemoHelper.CombinedInfoWrapper response;

            response = BillingApplyCreditMemoHelper.getCombinedInfo(testData.billings[2].Id, 10, null);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.isMultiCurrencyEnabled);
            System.assertNotEquals(null, response.creditMemo);
            System.assertNotEquals(0, response.invoices.size());
            System.assertEquals(testData.billings[2].Id, response.creditMemo.Id);
            BillingApplyCreditMemoHelper.InvoiceWrapper invoiceWithAppliedCredit;
            for (BillingApplyCreditMemoHelper.InvoiceWrapper wrapper : response.invoices) {
                if (wrapper.billingId == testData.billings[0].Id) {
                    invoiceWithAppliedCredit = wrapper;
                }
            }
            System.assertEquals(5, invoiceWithAppliedCredit.applied);
        }
    }

    @IsTest
    public static void getCombinedInfoFiltered() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        BillingApplyCreditMemoHelper.CombinedInfoWrapper response;

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c targetBilling = [SELECT Name FROM Billing__c WHERE Id = :testData.billings[0].Id];
            BillingApplyCreditMemoHelper.InvoiceFilter filter = new BillingApplyCreditMemoHelper.InvoiceFilter();
            filter.billingNumber = targetBilling.Name;
            String filterJson = JSON.serialize(filter);
            response = BillingApplyCreditMemoHelper.getCombinedInfo(testData.billings[2].Id, 10, filterJson);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.isMultiCurrencyEnabled);
            System.assertNotEquals(null, response.creditMemo);
            System.assertEquals(testData.billings[2].Id, response.creditMemo.Id);
            System.assertEquals(1, response.invoices.size());
            System.assertEquals(testData.billings[0].Id, response.invoices[0].billingId);
        }
    }

    @IsTest
    public static void createInvoiceWrappersDefaultsToToday() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Accounting_Period__c todaysPeriod = new Accounting_Period__c(
                Name = '2100-01',
                Start_Date__c = Date.today().addDays(-1),
                End_Date__c = Date.today().addDays(1),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert todaysPeriod;

            Billing__c creditMemo = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    Accounting_Period__r.Start_Date__c,
                    Due_Date2__c,
                    Date__c,
                    Proprietary_Billing_Number__c,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Total__c,
                    Balance__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Received_Amount__c
                FROM Billing__c
                WHERE Id = :testData.billings[2].Id];
            List<Billing__c> invoices = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    Accounting_Period__r.Start_Date__c,
                    Due_Date2__c,
                    Date__c,
                    Proprietary_Billing_Number__c,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Total__c,
                    Balance__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Received_Amount__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id];

            Map<Id, Billing_Credit_Memo__c> relatedCreditMemos = new Map<Id, Billing_Credit_Memo__c>();
            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.createInvoiceWrappers(creditMemo, invoices, relatedCreditMemos);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(0, response.size());
            BillingApplyCreditMemoHelper.InvoiceWrapper wrapper = response[0];
            System.assertEquals(testData.acctPeriods[0].Start_Date__c, wrapper.earliestAppliedDate);
            System.assertEquals(Date.today(), wrapper.appliedDate);
        }
    }

    @IsTest
    public static void createInvoiceWrappersEarliestDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users[1]) {
            Billing__c creditMemo = testData.billings[2];
            Billing__c invoice = testData.billings[0];
            Map<Id, Billing_Credit_Memo__c> relatedCreditMemos = new Map<Id, Billing_Credit_Memo__c>();

            Accounting_Period__c jan = new Accounting_Period__c(
                Name = '2100-01',
                Start_Date__c = Date.newInstance(2100, 01, 01),
                End_Date__c = Date.newInstance(2100, 01, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            Accounting_Period__c feb = new Accounting_Period__c(
                Name = '2100-02',
                Start_Date__c = Date.newInstance(2100, 02, 01),
                End_Date__c = Date.newInstance(2100, 02, 28),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c> { jan, feb };
            insert acctPeriods;

            creditMemo.Accounting_Period__c = feb.Id;
            invoice.Accounting_Period__c = jan.Id;
            update new List<Billing__c> { creditMemo, invoice };

            Billing__c inputCM = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    Accounting_Period__r.Start_Date__c,
                    Due_Date2__c,
                    Date__c,
                    Proprietary_Billing_Number__c,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Total__c,
                    Balance__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Received_Amount__c
                FROM Billing__c
                WHERE Id = :creditMemo.Id];
            List<Billing__c> inputInvoices = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    Accounting_Period__r.Start_Date__c,
                    Due_Date2__c,
                    Date__c,
                    Proprietary_Billing_Number__c,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Total__c,
                    Balance__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Received_Amount__c
                FROM Billing__c
                WHERE Id = :invoice.Id];

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = BillingApplyCreditMemoHelper.createInvoiceWrappers(inputCM, inputInvoices, relatedCreditMemos);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(0, response.size());
            BillingApplyCreditMemoHelper.InvoiceWrapper wrapper = response[0];
            System.assertEquals(feb.Start_Date__c, wrapper.earliestAppliedDate);
        }
    }

    @IsTest
    public static void saveSoftClosePeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c credit = getBilling(testData.billings[2].Id);
            Assert.areEqual('Credit Memo', credit.Type__c);
            Billing__c invoice = getBilling(testData.billings[0].Id);
            Assert.areEqual('Invoice', invoice.Type__c);

            Accounting_Period__c period = [Select Id, Close_AR__c, Close_AP__c, Status__c From Accounting_Period__c
                                                WHERE Start_Date__c =:  Date.newInstance(1991, 10, 1)];
            Period.Close_AR__c = True;
            UPDATE period; 

            BillingApplyCreditMemoHelper.SaveItem saveItem = new BillingApplyCreditMemoHelper.SaveItem();
            saveItem.billingId = invoice.Id;
            saveItem.appliedDate = Date.newInstance(1991, 10, 1);
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String> { JSON.serialize(saveItem) };

            AuraHandledException expectedEx;
            try {
                BillingApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            Assert.IsNotNull(expectedEx);
            String expectedExMsg = String.format(BillingApplyCreditMemoHelper.APPLIED_DATE_INVALID, new String[] { saveItem.derivedName });
            Assert.areEqual(
                expectedExMsg,
                ((BillingApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), BillingApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void createSoftCloseInvoiceWrappersEarliestDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c creditMemo = testData.billings[2];
            Billing__c invoice = testData.billings[0];
            Map<Id, Billing_Credit_Memo__c> relatedCreditMemos = new Map<Id, Billing_Credit_Memo__c>();

            Accounting_Period__c feb = new Accounting_Period__c(
                Name = '2100-02',
                Start_Date__c = Date.newInstance(2100, 02, 02),
                End_Date__c = Date.newInstance(2100, 02, 28),
                Status__c = AccountingPeriodActions.OPEN_STATUS,
                Close_AR__c = false
            );
            Accounting_Period__c jan = new Accounting_Period__c(
                Name = '2100-01',
                Start_Date__c = Date.newInstance(2100, 01, 01),
                End_Date__c = Date.newInstance(2100, 01, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS,
                Close_AR__c = false
            );
            Accounting_Period__c mar = new Accounting_Period__c(
                Name = '2100-03',
                Start_Date__c = Date.newInstance(2100, 03, 03),
                End_Date__c = Date.newInstance(2100, 03, 28),
                Status__c = AccountingPeriodActions.OPEN_STATUS,
                Close_AR__c = false
            );
            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c> { jan, feb, mar };
            insert acctPeriods;

            creditMemo.Accounting_Period__c = feb.Id;
            invoice.Accounting_Period__c = jan.Id;
            update new List<Billing__c> { creditMemo, invoice };
            
            Billing_Credit_Memo__c junction = new Billing_Credit_Memo__c(
                Billing_Credit_Memo__c = creditMemo.Id,
                Billing_Invoice__c = invoice.Id,
                Accounting_Period__c = feb.Id,
                Amount__c = -5
            );
            insert junction;

            relatedCreditMemos.put(invoice.Id, junction);

            Billing__c inputCM = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    Accounting_Period__r.Start_Date__c,
                    Due_Date2__c,
                    Date__c,
                    Proprietary_Billing_Number__c,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Total__c,
                    Balance__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Received_Amount__c
                FROM Billing__c
                WHERE Id = :creditMemo.Id];
            List<Billing__c> inputInvoices = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    Accounting_Period__r.Start_Date__c,
                    Due_Date2__c,
                    Date__c,
                    Proprietary_Billing_Number__c,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Total__c,
                    Balance__c,
                    Cash_Application_Adjustment_Amount__c,
                    Credit_Memo_Applied_Amount__c,
                    Received_Amount__c
                FROM Billing__c
                WHERE Id = :invoice.Id];

            List<BillingApplyCreditMemoHelper.InvoiceWrapper> response;

            //soft close the Feb AP
            feb.Close_AR__c = true;
            update feb;

            response = BillingApplyCreditMemoHelper.createInvoiceWrappers(inputCM, inputInvoices, relatedCreditMemos);
            Test.stopTest();
            
            BillingApplyCreditMemoHelper.InvoiceWrapper wrapper = response[0];

            Assert.isNotNull(response);
            //Assert that the earliest AP is March since Feb is soft closed
            Assert.areEqual(mar.Start_Date__c, wrapper.earliestAppliedDate);
            Assert.areEqual(inputInvoices[0].Customer__c, wrapper.customerId);
        }
    }

}