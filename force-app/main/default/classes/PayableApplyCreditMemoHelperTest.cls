@IsTest
public with sharing class PayableApplyCreditMemoHelperTest {

    private static void post(List<Account_Payable__c> payables) {
        for (PostResult result : AccountPayablePostService.postAccountPayables(payables)) {
            System.assertEquals(true, result.isSuccess);
        }
    }

    private static Account_Payable__c getPayables(Id payableId) {
        return getPayables(new List<Id>{
                payableId
        }).get(0);
    }

    private static List<Account_Payable__c> getPayables(List<Id> payableIds) {
        return [
                SELECT Id, Name, Type__c, Balance__c, Total__c, Date__c, Accounting_Period__c, LastModifiedDate
                FROM Account_Payable__c
                WHERE Id IN :payableIds
        ];
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void saveAppliedAccountingPeriodSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            
            testData.acctPeriods[0].Close_AP__c = TRUE;
            UPDATE testData.acctPeriods;
            
            Test.startTest();
                Account_Payable__c credit = getPayables(testData.payables[4].Id);
                Assert.areEqual('Credit Memo', credit.Type__c);
                Account_Payable__c invoice = getPayables(testData.payables[0].Id);
                Assert.areEqual('Invoice', invoice.Type__c);

                PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
                saveItem.payableId = invoice.Id;
                saveItem.derivedName = 'item';
                saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
                saveItem.variableCredit = 1;

                List<String> updates = new List<String>{
                        JSON.serialize(saveItem)
                };
                AuraHandledException expectedEx;

            
                try {
                    PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
                } catch (AuraHandledException ex) {
                    expectedEx = ex;
                }
            Test.stopTest();

            Assert.isNotNull(expectedEx);
            String expectedExMsg = String.format(PayableApplyCreditMemoHelper.APPLIED_DATE_INVALID, new String[]{
                    saveItem.derivedName
            });
            Assert.areEqual(
                    expectedExMsg,
                    ((PayableApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), PayableApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    /*@IsTest
    public static void saveAppliedAccountingPeriodMissing() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.derivedName = 'item';
            saveItem.appliedDate = null;
            saveItem.variableCredit = 1;

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };
            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();


            System.assertNotEquals(null, expectedEx);
            String expectedExMsg = String.format(PayableApplyCreditMemoHelper.APPLIED_DATE_INVALID, new String[]{
                    saveItem.derivedName
            });
            System.assertEquals(
                    expectedExMsg,
                    ((PayableApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), PayableApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void saveNoCorrespondingAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = Date.today().addYears(50);
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();


            System.assertNotEquals(null, expectedEx);
            String expectedExMsg = String.format(PayableApplyCreditMemoHelper.APPLIED_DATE_INVALID, new String[]{
                    saveItem.derivedName
            });
            System.assertEquals(
                    expectedExMsg,
                    ((PayableApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), PayableApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void saveAppliedAccountingPeriodLessThanInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            testData.payables[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.payables[0];

            post(new List<Account_Payable__c>{
                    testData.payables[0], testData.payables[4]
            });

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 1;

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();


            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveAppliedAccountingPeriodLessThanCredit() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {

            testData.payables[2].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.payables[2];

            post(new List<Account_Payable__c>{
                    testData.payables[0], testData.payables[4]
            });

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 1;

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveOverappliedCredit() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = credit.Balance__c + 1;

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveOverappliedInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {

            // credit amount larger than invoice amount
            testData.payableLines[4].Quantity__c = 10000;
            update testData.payableLines[4];

            post(new List<Account_Payable__c>{
                    testData.payables[0], testData.payables[4]
            });

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            // apply credit balance which should exceed incoive balance
            saveItem.variableCredit = credit.Balance__c;

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveOverappliedCreditonMultipleInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Account_Payable__c> invoices = getPayables(new List<Id>{
                    testData.payables[0].Id,
                    testData.payables[1].Id
            });
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem1 = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem1.payableId = invoices.get(0).Id;
            saveItem1.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem1.variableCredit = 150;

            PayableApplyCreditMemoHelper.SaveItem saveItem2 = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem2.payableId = invoices.get(1).Id;
            saveItem2.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem2.variableCredit = 150;

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem1), JSON.serialize(saveItem2)
            };

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void saveWriteConflict() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            Datetime lastWrite = Datetime.now().addHours(1);

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                PayableApplyCreditMemoHelper.save(credit.Id, lastWrite, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();


            System.assertNotEquals(null, expectedEx);
            System.assertEquals(
                    PayableApplyCreditMemoHelper.CREDIT_MEMO_MODIFIED_ERROR,
                    ((PayableApplyCreditMemoHelper.ExceptionData) JSON.deserialize(expectedEx.getMessage(), PayableApplyCreditMemoHelper.ExceptionData.class)).message
            );
        }
    }

    @IsTest
    public static void save() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c + 60;
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            Test.startTest();
            PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();


            AP_Credit_Memo__c pcm = [
                    SELECT Account_Payable_Invoice__c, Amount__c, Applied_Date__c
                    FROM AP_Credit_Memo__c
                    WHERE Account_Payable_Credit_Memo__c = :credit.Id
                    LIMIT 1
            ];
            System.assert(pcm.Account_Payable_Invoice__c == saveItem.payableId);
            System.assertEquals(saveItem.appliedDate, pcm.Applied_Date__c);
            System.assertEquals(saveItem.variableCredit, pcm.Amount__c * -1);
        }
    }

    @IsTest
    public static void saveUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);
            AP_Credit_Memo__c junction = new AP_Credit_Memo__c(
                    Account_Payable_Credit_Memo__c = credit.Id,
                    Account_Payable_Invoice__c = invoice.Id,
                    Accounting_Period__c = credit.Accounting_Period__c,
                    Amount__c = -5
            );
            insert junction;

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c + 60;
            saveItem.variableCredit = 25;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            Test.startTest();
            credit = getPayables(credit.Id);
            PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();


            List<AP_Credit_Memo__c> pcms = [
                    SELECT Account_Payable_Invoice__c, Amount__c, Applied_Date__c
                    FROM AP_Credit_Memo__c
                    WHERE Account_Payable_Credit_Memo__c = :credit.Id
            ];

            System.assertEquals(1, pcms.size());
            System.assertEquals(saveItem.appliedDate, pcms.get(0).Applied_Date__c);
            System.assertEquals(saveItem.payableId, pcms.get(0).Account_Payable_Invoice__c);
            System.assertEquals(saveItem.appliedDate, pcms.get(0).Applied_Date__c);
            System.assertEquals(saveItem.variableCredit, pcms.get(0).Amount__c * -1);
        }
    }

    @IsTest
    public static void saveDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            Account_Payable__c invoice = getPayables(testData.payables[0].Id);
            System.assertEquals('Invoice', invoice.Type__c);
            AP_Credit_Memo__c junction = new AP_Credit_Memo__c(
                    Account_Payable_Credit_Memo__c = credit.Id,
                    Account_Payable_Invoice__c = invoice.Id,
                    Accounting_Period__c = credit.Accounting_Period__c,
                    Amount__c = -5
            );
            insert junction;

            PayableApplyCreditMemoHelper.SaveItem saveItem = new PayableApplyCreditMemoHelper.SaveItem();
            saveItem.payableId = invoice.Id;
            saveItem.appliedDate = testData.acctPeriods[0].Start_Date__c;
            saveItem.variableCredit = 0;
            saveItem.derivedName = 'item';

            List<String> updates = new List<String>{
                    JSON.serialize(saveItem)
            };

            Test.startTest();
            credit = getPayables(credit.Id);
            PayableApplyCreditMemoHelper.save(credit.Id, credit.LastModifiedDate, updates);
            Test.stopTest();


            List<AP_Credit_Memo__c> pcms = new List<AP_Credit_Memo__c>();
            pcms = [
                    SELECT Account_Payable_Invoice__c, Amount__c, Applied_Date__c
                    FROM AP_Credit_Memo__c
                    WHERE Account_Payable_Credit_Memo__c = :credit.Id
            ];
            System.assertEquals(0, pcms.size());
        }
    }

    @IsTest
    public static void getApplicableInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Id> invoiceIds = new List<Id>{
                testData.payables[0].Id,
                testData.payables[1].Id
            };
            List<Account_Payable__c> invoices = getPayables(invoiceIds);
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(3, response.size());
            System.assert(invoiceIds.contains(response.get(0).payableId));
        }
    }

    @IsTest
    public static void getApplicableInvoicesLimitResults() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Id> invoiceIds = new List<Id>{
                    testData.payables[0].Id,
                    testData.payables[1].Id
            };
            List<Account_Payable__c> invoices = getPayables(invoiceIds);
            System.assertEquals('Invoice', invoices.get(0).Type__c);
            System.assertEquals('Invoice', invoices.get(1).Type__c);

            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);

            Integer maxResults = 1;

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getApplicableInvoices(credit.Id, maxResults, filterJson);
            Test.stopTest();
            System.assertEquals(maxResults, response.size());
        }

    }

    @IsTest
    public static void getApplicableInvoicesFilteredBillingNumber() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Account_Payable__c credit = getPayables(testData.payables[4].Id);
            System.assertEquals('Credit Memo', credit.Type__c);
            List<Account_Payable__c> invoices = getPayables(new List<String>{
                    testData.payables[0].Id,
                    testData.payables[1].Id
            });

            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            filter.payableNumber = invoices.get(0).Name;
            String filterJson = JSON.serialize(filter);

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(invoices.get(0).Id, response.get(0).payableId);
        }
    }

    @IsTest
    public static void getApplicableInvoicesFilteredDueDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users[1]) {

            Date newInvoiceDueDate = Date.today().addDays(-5);
            testData.payables[0].Due_Date__c = newInvoiceDueDate;
            update testData.payables[0];

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{
                    testData.payables[0],
                    testData.payables[1],
                    testData.payables[4]
            });

            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            filter.dueDateStart = newInvoiceDueDate.addDays(-5);
            filter.dueDateEnd = newInvoiceDueDate.addDays(5);
            String filterJson = JSON.serialize(filter);

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getApplicableInvoices(testData.payables[4].Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(testData.payables[0].Id, response.get(0).payableId);
        }
    }

    @IsTest
    public static void getApplicableInvoicesFilteredAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users[1]) {

            testData.payableLines[0].Quantity__c = 25;
            update testData.payableLines[0];

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{
                    testData.payables[0], // amount is 1245
                    testData.payables[1], // amount is 160
                    testData.payables[4] // amount is -55
            });

            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            filter.payableAmountStart = 1200;
            filter.payableAmountEnd = 1250;
            String filterJson = JSON.serialize(filter);

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getApplicableInvoices(testData.payables[4].Id, 10, filterJson);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals(testData.payables[0].Id, response.get(0).payableId);
        }
    }

    @IsTest
    public static void getApplicableInvoices_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                    .enableMultiCurrency()
                    .createPayables();
            System.runAs(testData.users[1]) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c credit = testData.payables[4];
                Account_Payable__c invoice1 = testData.payables[1];
                Account_Payable__c invoice2 = testData.payables[0];

                credit.Currency_Conversion_Rate__c = 1.2;
                invoice1.Currency_Conversion_Rate__c = 1.5;
                invoice2.Currency_Conversion_Rate__c = 1.2;

                TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{
                        Account_Payable__c.Currency_Conversion_Rate__c
                });
                update new List<Account_Payable__c>{
                        credit, invoice1, invoice2
                };
                TriggerObserver.reset();

                post(new List<Account_Payable__c>{
                        credit, invoice1, invoice2
                });

                credit = getPayables(credit.Id);
                System.assertEquals('Credit Memo', credit.Type__c);
                List<Account_Payable__c> invoices = getPayables(new List<Id>{
                        invoice1.Id, invoice2.Id
                });
                System.assertEquals('Invoice', invoices.get(0).Type__c);
                System.assertEquals('Invoice', invoices.get(1).Type__c);

                List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

                PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
                String filterJson = JSON.serialize(filter);

                Test.startTest();
                response = PayableApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
                Test.stopTest();

                System.assertEquals(1, response.size());
                System.assertEquals(invoice2.Id, response.get(0).payableId);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
        }
    }

    @IsTest
    public static void getApplicableInvoicesMultiCurrencyWithLegacyRecords_MC() {

        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                    .enableMultiCurrency()
                    .createPayables();

            System.runAs(testData.users[1]) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c credit = testData.payables[4];
                Account_Payable__c invoice1 = testData.payables[1];
                Account_Payable__c invoice2 = testData.payables[0];

                credit.Currency_Conversion_Rate__c = null;
                invoice1.Currency_Conversion_Rate__c = 1;
                invoice2.Currency_Conversion_Rate__c = null;

                TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{
                        Account_Payable__c.Currency_Conversion_Rate__c
                });
                update new List<Account_Payable__c>{
                        credit, invoice1, invoice2
                };
                TriggerObserver.reset();

                post(new List<Account_Payable__c>{
                        credit, invoice1, invoice2
                });

                credit = getPayables(credit.Id);
                System.assertEquals('Credit Memo', credit.Type__c);
                List<Id> invoiceIds = new List<Id>{
                        invoice1.Id, invoice2.Id
                };
                List<Account_Payable__c> invoices = getPayables(invoiceIds);
                System.assertEquals('Invoice', invoices.get(0).Type__c);
                System.assertEquals('Invoice', invoices.get(1).Type__c);

                List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

                PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
                String filterJson = JSON.serialize(filter);

                Test.startTest();
                response = PayableApplyCreditMemoHelper.getApplicableInvoices(credit.Id, 10, filterJson);
                Test.stopTest();

                System.assertEquals(3, response.size());
                System.assert(invoiceIds.contains(response.get(0).payableId));
                System.assert(invoiceIds.contains(response.get(1).payableId));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {

        }

    }

    @IsTest
    public static void getApplicableInvoicesFakeBillingId() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;
            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            String filterJson = JSON.serialize(filter);
            AuraHandledException expectedEx;

            Test.startTest();
            try {
                response = PayableApplyCreditMemoHelper.getApplicableInvoices('123abc', 10, filterJson);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void getCombinedInfo() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users[1]) {
            PayableApplyCreditMemoHelper.CombinedInfoWrapper response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getCombinedInfo(testData.payables[4].Id, 10, null);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.isMultiCurrencyEnabled);
            System.assertNotEquals(null, response.creditMemo);
            System.assertNotEquals(0, response.invoices.size());
            System.assertEquals(testData.payables[4].Id, response.creditMemo.Id);
        }

    }

    @IsTest
    public static void getCombinedInfoFakeId() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users[1]) {

            PayableApplyCreditMemoHelper.CombinedInfoWrapper response;

            AuraHandledException expectedEx;

            Test.startTest();
            try {
                response = PayableApplyCreditMemoHelper.getCombinedInfo('abc123', 10, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    public static void getCombinedInfoExistingBCM() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users[1]) {

            AP_Credit_Memo__c junction = new AP_Credit_Memo__c(
                    Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                    Account_Payable_Invoice__c = testData.payables[0].Id,
                    Accounting_Period__c = testData.payables[4].Accounting_Period__c,
                    Amount__c = -5
            );
            insert junction;

            PayableApplyCreditMemoHelper.CombinedInfoWrapper response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.getCombinedInfo(testData.payables[4].Id, 10, null);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.isMultiCurrencyEnabled);
            System.assertNotEquals(null, response.creditMemo);
            System.assertNotEquals(0, response.invoices.size());
            System.assertEquals(testData.payables[4].Id, response.creditMemo.Id);
            PayableApplyCreditMemoHelper.InvoiceWrapper invoiceWithAppliedCredit;
            for (PayableApplyCreditMemoHelper.InvoiceWrapper wrapper : response.invoices) {
                if (wrapper.payableId == testData.payables[0].Id) {
                    invoiceWithAppliedCredit = wrapper;
                }
            }
            System.assertEquals(5, invoiceWithAppliedCredit.applied);
        }
    }

    @IsTest
    public static void getCombinedInfoFiltered() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users[1]) {

            PayableApplyCreditMemoHelper.CombinedInfoWrapper response;

            Test.startTest();
            Account_Payable__c targetPayable = [SELECT Name FROM Account_Payable__c WHERE Id = :testData.payables[0].Id];
            PayableApplyCreditMemoHelper.InvoiceFilter filter = new PayableApplyCreditMemoHelper.InvoiceFilter();
            filter.payableNumber = targetPayable.Name;
            String filterJson = JSON.serialize(filter);
            response = PayableApplyCreditMemoHelper.getCombinedInfo(testData.payables[4].Id, 10, filterJson);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.isMultiCurrencyEnabled);
            System.assertNotEquals(null, response.creditMemo);
            System.assertEquals(testData.payables[4].Id, response.creditMemo.Id);
            System.assertEquals(1, response.invoices.size());
            System.assertEquals(testData.payables[0].Id, response.invoices[0].payableId);
        }
    }

    @IsTest
    public static void createInvoiceWrappersDefaultsToToday() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {

            Accounting_Period__c todaysPeriod = new Accounting_Period__c(
                    Name = '2100-01',
                    Start_Date__c = Date.today().addDays(-1),
                    End_Date__c = Date.today().addDays(1),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert todaysPeriod;

            Account_Payable__c creditMemo = [
                    SELECT
                            Id,
                            Accounting_Period__c,
                            Accounting_Period__r.Start_Date__c,
                            Due_Date__c,
                            Date__c,
                            Proprietary_Payable_Number__c,
                            Name,
                            Vendor__c,
                            Vendor__r.Name,
                            Total__c,
                            Balance__c,
                            Credit_Memo_Applied_Amount__c,
                            Paid_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[4].Id
            ];
            List<Account_Payable__c> invoices = [
                    SELECT
                            Id,
                            Accounting_Period__c,
                            Accounting_Period__r.Start_Date__c,
                            Due_Date__c,
                            Date__c,
                            Proprietary_Payable_Number__c,
                            Name,
                            Vendor__c,
                            Vendor__r.Name,
                            Total__c,
                            Balance__c,
                            Credit_Memo_Applied_Amount__c,
                            Payee_Reference__c,
                            Paid_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[0].Id
            ];

            Map<Id, AP_Credit_Memo__c> relatedCreditMemos = new Map<Id, AP_Credit_Memo__c>();
            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.createInvoiceWrappers(creditMemo, invoices, relatedCreditMemos);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(0, response.size());
            PayableApplyCreditMemoHelper.InvoiceWrapper wrapper = response[0];
            System.assertEquals(Date.today(), wrapper.appliedDate);
        }

    }

    @IsTest
    public static void createInvoiceWrappersEarliestDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users[1]) {

            Account_Payable__c creditMemo = testData.payables[4];
            Account_Payable__c invoice = testData.payables[0];
            Map<Id, AP_Credit_Memo__c> relatedCreditMemos = new Map<Id, AP_Credit_Memo__c>();

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
            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>{
                    jan, feb
            };
            insert acctPeriods;

            creditMemo.Accounting_Period__c = feb.Id;
            invoice.Accounting_Period__c = jan.Id;
            update new List<Account_Payable__c>{
                    creditMemo, invoice
            };

            Account_Payable__c inputCM = [
                    SELECT
                            Id,
                            Accounting_Period__c,
                            Accounting_Period__r.Start_Date__c,
                            Due_Date__c,
                            Date__c,
                            Proprietary_Payable_Number__c,
                            Name,
                            Vendor__c,
                            Vendor__r.Name,
                            Total__c,
                            Balance__c,
                            Credit_Memo_Applied_Amount__c,
                            Paid_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :creditMemo.Id
            ];
            List<Account_Payable__c> inputInvoices = [
                    SELECT
                            Id,
                            Accounting_Period__c,
                            Accounting_Period__r.Start_Date__c,
                            Due_Date__c,
                            Date__c,
                            Proprietary_Payable_Number__c,
                            Name,
                            Vendor__c,
                            Vendor__r.Name,
                            Total__c,
                            Balance__c,
                            Credit_Memo_Applied_Amount__c,
                            Payee_Reference__c,
                            Paid_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :invoice.Id
            ];

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.createInvoiceWrappers(inputCM, inputInvoices, relatedCreditMemos);
            Test.stopTest();

            System.assertNotEquals(null, response);
            System.assertNotEquals(0, response.size());
            PayableApplyCreditMemoHelper.InvoiceWrapper wrapper = response[0];
            System.assertEquals(feb.Start_Date__c, wrapper.earliestAppliedDate);
        }
    }*/

    @IsTest
    public static void createSoftCloseInvoiceWrappersEarliestDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users[1]) {

            Account_Payable__c creditMemo = testData.payables[4];
            Account_Payable__c invoice = testData.payables[0];
            Map<Id, AP_Credit_Memo__c> relatedCreditMemos = new Map<Id, AP_Credit_Memo__c>();

            Accounting_Period__c jan = new Accounting_Period__c(
                    Name = '2100-01',
                    Start_Date__c = Date.newInstance(2100, 01, 01),
                    End_Date__c = Date.newInstance(2100, 01, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS,
                    Close_AP__c = TRUE
            );
            Accounting_Period__c feb = new Accounting_Period__c(
                    Name = '2100-02',
                    Start_Date__c = Date.newInstance(2100, 02, 01),
                    End_Date__c = Date.newInstance(2100, 02, 28),
                    Status__c = AccountingPeriodActions.OPEN_STATUS,
                    Close_AP__c = TRUE
            );
            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>{
                    jan, feb
            };
            insert acctPeriods;

            creditMemo.Accounting_Period__c = feb.Id;
            invoice.Accounting_Period__c = jan.Id;
            update new List<Account_Payable__c>{
                    creditMemo, invoice
            };

            Account_Payable__c inputCM = [
                    SELECT
                            Id,
                            Accounting_Period__c,
                            Accounting_Period__r.Start_Date__c,
                            Due_Date__c,
                            Date__c,
                            Proprietary_Payable_Number__c,
                            Name,
                            Vendor__c,
                            Vendor__r.Name,
                            Total__c,
                            Balance__c,
                            Credit_Memo_Applied_Amount__c,
                            Paid_Amount__c,
                			On_Hold__c
                    FROM Account_Payable__c
                    WHERE Id = :creditMemo.Id
            ];
            List<Account_Payable__c> inputInvoices = [
                    SELECT
                            Id,
                            Accounting_Period__c,
                            Accounting_Period__r.Start_Date__c,
                            Due_Date__c,
                            Date__c,
                            Proprietary_Payable_Number__c,
                            Name,
                            Vendor__c,
                            Vendor__r.Name,
                            Total__c,
                            Balance__c,
                            Credit_Memo_Applied_Amount__c,
                            Payee_Reference__c,
                            Paid_Amount__c,
                			On_Hold__c
                    FROM Account_Payable__c
                    WHERE Id = :invoice.Id
            ];

            List<PayableApplyCreditMemoHelper.InvoiceWrapper> response;

            Test.startTest();
            response = PayableApplyCreditMemoHelper.createInvoiceWrappers(inputCM, inputInvoices, relatedCreditMemos);
            Test.stopTest();

            Assert.areEqual(1, response.size());
        }
    }


}