@IsTest
private class CashDisbursementTest {

    @IsTest
    static void testApply() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[5].Amount__c = 100;
            update testData.cashDisbursements[5];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = testData.acctPeriods[1].Start_Date__c;                                    
            cashApplications.add(ca);
            
            CashApplication ca2 = new CashApplication();            
            ca2.appliedItemId = testData.payables[7].Id;
            ca2.amount = 20;
            ca2.appliedDate = testData.acctPeriods[1].Start_Date__c;                                    
            cashApplications.add(ca2);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, true);

            List<AP_Disbursement__c> apds = [SELECT Id, Account_Payable__c, Cash_Disbursement__c, Paid_Amount__c, Applied_Date__c, Accounting_Period__c FROM AP_Disbursement__c ORDER BY Account_Payable__c];
            System.assertEquals(apds[0].Account_Payable__c, testData.payables[0].Id);
            System.assertEquals(apds[0].Cash_Disbursement__c, testData.cashDisbursements[5].Id);
            System.assertEquals(apds[0].Paid_Amount__c, 10);
            System.assertEquals(apds[0].Applied_Date__c, testData.acctPeriods[1].Start_Date__c);
            System.assertEquals(apds[0].Accounting_Period__c, testData.acctPeriods[1].Id);

            System.assertEquals(apds[1].Account_Payable__c, testData.payables[7].Id);
            System.assertEquals(apds[1].Cash_Disbursement__c, testData.cashDisbursements[5].Id);
            System.assertEquals(apds[1].Paid_Amount__c, 20);
            System.assertEquals(apds[1].Applied_Date__c, testData.acctPeriods[1].Start_Date__c);
            System.assertEquals(apds[1].Accounting_Period__c, testData.acctPeriods[1].Id);            
        }
    }

    @IsTest
    static void testRetrieveAppliedDisbursements() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[0].Amount__c = 100;
            update testData.cashDisbursements[5];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = testData.acctPeriods[1].Start_Date__c;                                    
            cashApplications.add(ca);
            
            CashApplication ca2 = new CashApplication();            
            ca2.appliedItemId = testData.payables[7].Id;
            ca2.amount = 20;
            ca2.appliedDate = testData.acctPeriods[1].Start_Date__c;                                    
            cashApplications.add(ca2);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, true);

            CashDisbursementApplyModel cdam = CashDisbursement.retrieveAppliedDisbursements(testData.cashDisbursements[5].Id);
            System.assertEquals(cdam.cashDisbursement.Id, testData.cashDisbursements[5].Id);
            System.assertEquals(cdam.cashApplications.size(), 2);
            System.assertEquals(cdam.cashApplications[0].appliedItemId, testData.payables[0].Id);
            System.assertEquals(cdam.cashApplications[0].amount, 10);
            System.assertEquals(cdam.cashApplications[0].appliedDate, testData.acctPeriods[1].Start_Date__c);

            System.assertEquals(cdam.cashApplications[1].appliedItemId, testData.payables[7].Id);
            System.assertEquals(cdam.cashApplications[1].amount, 20);
            System.assertEquals(cdam.cashApplications[1].accountingPeriodId, testData.acctPeriods[1].Id);
        }
    }

    @IsTest
     static void testUnapply() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[5].Amount__c = 100;
            update testData.cashDisbursements[5];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = testData.acctPeriods[1].Start_Date__c;
            cashApplications.add(ca);
            
            CashApplication ca2 = new CashApplication();
            ca2.appliedItemId = testData.payables[7].Id;
            ca2.amount = 20;
            ca2.appliedDate = testData.acctPeriods[1].Start_Date__c;
            cashApplications.add(ca2);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, true);

            List<AP_Disbursement__c> apds = [
                SELECT
                    Id,
                    Account_Payable__c,
                    Cash_Disbursement__c,
                    Paid_Amount__c,
                    Applied_Date__c,
                    Accounting_Period__c
                FROM AP_Disbursement__c
                ORDER BY Account_Payable__c
            ];
            System.assertEquals(2, apds.size());

            ServiceResult srUnapply = CashDisbursement.unapply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srUnapply.isSuccess, true);

            List<AP_Disbursement__c> apdsUnapply = [
                SELECT
                    Id,
                    Account_Payable__c,
                    Cash_Disbursement__c,
                    Paid_Amount__c,
                    Applied_Date__c,
                    Accounting_Period__c
                FROM AP_Disbursement__c
                ORDER BY Account_Payable__c
            ];
            System.assertEquals(0, apdsUnapply.size());
        }
    }

    //-------------- Negative Testing -----------------------//

    @IsTest
     static void testApplyInvalidId() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();                        
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = testData.acctPeriods[0].Start_Date__c;                                    
            cashApplications.add(ca);
            
            CashApplication ca2 = new CashApplication();            
            ca2.appliedItemId = testData.payables[7].Id;
            ca2.amount = 20;
            ca2.appliedDate = testData.acctPeriods[0].Start_Date__c;                                    
            cashApplications.add(ca2);
            
            ServiceResult srApply = CashDisbursement.apply(testData.payables[0].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.INVALID_RECORD_OR_ID);
            
        }
    }

    @IsTest
     static void testApplyNoDataProvided() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();            
        System.runAs(testData.users[1]) {
            Test.startTest();
            
            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, NULL);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.NO_INPUT_DATA);
            
        }
    }

    @IsTest
     static void testApplyBadPayableId() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();            
        System.runAs(testData.users[1]) {
            Test.startTest();
            
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.cashDisbursements[6].Id;
            ca.amount = 10;
            ca.appliedDate = testData.acctPeriods[0].Start_Date__c;                                    
            cashApplications.add(ca);
            
            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.INVALID_RECORD_OR_ID);
            
        }
    }

    @IsTest
     static void testApplyCDLessThanZero() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[6].Amount__c = 1;
            update testData.cashDisbursements[6];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();

            CashApplication ca = new CashApplication();                        
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = testData.acctPeriods[0].Start_Date__c;                                    
            cashApplications.add(ca);
            
            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO);
        }
    }

    @IsTest
     static void testApplyAppliedAmountLessThanZero() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[6].Amount__c = 1;
            update testData.cashDisbursements[6];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = -10;
            ca.appliedDate = testData.acctPeriods[0].Start_Date__c;                                    
            cashApplications.add(ca);
            
            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.APPLIED_AMOUNT_LESS_THAN_ZERO);
        }
    }

    @IsTest
     static void testApplyPayableBalanceLessThanZero() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[6].Amount__c = 10000;
            update testData.cashDisbursements[6];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10000;
            ca.appliedDate = testData.acctPeriods[0].Start_Date__c;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.PAYABLE_BALANCE_LESS_THAN_ZERO);
        }
    }

    @IsTest
     static void testApplyAppliedDateAccountingPeriodBothBlank() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[6].Amount__c = 10000;
            update testData.cashDisbursements[6];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;            
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(2, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.MISSING_APPLIED_DATE);
        }
    }

    @IsTest
     static void testApplyBadAccountingPeriodId() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[6].Amount__c = 10000;
            update testData.cashDisbursements[6];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.payables[0].Id;
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.INVALID_RECORD_OR_ID);
        }
    }

    @IsTest
     static void testApplyBlankAccountingPeriodAndInvalidAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[6].Amount__c = 10000;
            update testData.cashDisbursements[6];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = date.today().addYears(5);                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.MISSING_ACCOUNTING_PERIOD);
        }
    }

    @IsTest
     static void testApplyAccountingPeriodAndAppliedDateDoNotMatch() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[5].Amount__c = 10000;
            update testData.cashDisbursements[5];
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.appliedDate = date.today().addYears(5);
            ca.accountingPeriodId = testData.acctPeriods[1].Id;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.APPLIED_DATE_DOES_NOT_MATCH_ACCOUNTING_PERIOD);
        }
    }

    @IsTest
     static void testApplyAccountingPeriodClosed() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.cashDisbursements[6].Amount__c = 10000;
            update testData.cashDisbursements[6];            
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            //force the acctPeriod to finish closing
            Test.stopTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[0].Id;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            String err = label.ERR_COMMON_INVALID_APPLIED_DATE;
            System.assertEquals(srApply.errors[0].detail.right(15), err.right(15));
        }
    }

    @IsTest
     static void testApplyAccountingPeriodBeforePayableAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.payables[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.payables[0];            
            
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[0].Id;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.ACCOUNTING_PERIOD_BEFORE_PAYABLE_ACCOUNTING_PERIOD);
        }
    }

    @IsTest
     static void testApplyAccountingPeriodBeforeCDAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            testData.cashDisbursements[5].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.cashDisbursements[5];            
            
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[0].Id;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.ACCOUNTING_PERIOD_BEFORE_CASH_DISBURSEMENT_ACCOUNTING_PERIOD);
        }
    }

    @IsTest
     static void testApplyTooManyRecords() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            for (integer i = 0; i< CashDisbursement.CASH_DISBURSEMENT_ITEM_LIMIT + 1; i++) {
                
                CashApplication ca = new CashApplication();            
                ca.appliedItemId = testData.payables[0].Id;
                ca.amount = 10;
                ca.accountingPeriodId = testData.acctPeriods[0].Id;                                    
                cashApplications.add(ca);

            }            

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(
                srApply.errors[0].detail, 
                String.format(CashDisbursement.OVER_CASH_DISBURSEMENT_ITEM_LIMIT, 
                            new String[]{
                                String.valueOf(CashDisbursement.CASH_DISBURSEMENT_ITEM_LIMIT)
                            }
                )
            );
        }
    }

    @IsTest
     static void testApplyPayeeMismatch() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[1].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[0].Id;
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.CASH_DISBURSEMENT_PAYEE_MISMATCH);
        }
    }

    @IsTest
     static void testApplyPayableVoidedCD() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementVoid voidController = new CashDisbursementVoid(stdController);
            voidController.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10);
            voidController.voidCashDisbursement();
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[1].Id;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[5].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.VOIDED_CD_ERROR);
        }
    }

    @IsTest
     static void testApplyPayableSourceNotManual() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false,true);
            testCD.Debit_GL_Account__c = testData.glAccounts[4].Id;
            testCD.Source__c = 'Payable';
            CashDisbursementActions.isSourcedFromPayables = true;
            insert testCD;
            CashDisbursementActions.isSourcedFromPayables = false;
            
            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = testData.payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[1].Id;                                    
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testCD.Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, APDisbursementPostHandler.DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT_ERROR_MESSAGE);
        }
    }

    @IsTest
     static void testApplyLedgerMismatch() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();
        System.runAs(testData.users[1]) {
            LedgerService.setLedgerLimit(
                10,
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                )
            );
            LedgerHandler.reset();
            List<Ledger__c> ledgers = new List<Ledger__c>();
            Ledger__c Ledger2 = new Ledger__c(
                Name = 'Actual',
                Type__c = 'Transactional',
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                Default_Purchase_Order_Format__c = testData.billingFormats[4].Id,
                Default_Packing_Slip_Format__c = testData.billingFormats[5].Id                
            );
            
            ledgers.add(Ledger2);
            insert ledgers;
            List<Account_Payable__c> payables = new List<Account_Payable__c>();
            payables.add(
                new Account_Payable__c(
                    Payee_Reference__c = 'new Payable ledger',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Vendor__c = testData.accounts[0].Id,
                    //Discount_Amount__c = 20,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = ledgers[0].Id
                )
            );

            insert payables;

            List<Account_Payable_Line__c> payableLines = new List<Account_Payable_Line__c>();
            payableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = payables[0].Id,
                    Amount__c = 45,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                )
            );

            insert payableLines;

            Test.startTest();
            List<CashApplication> cashApplications = new List<CashApplication>();
            
            CashApplication ca = new CashApplication();            
            ca.appliedItemId = payables[0].Id;
            ca.amount = 10;
            ca.accountingPeriodId = testData.acctPeriods[0].Id;
            cashApplications.add(ca);

            ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
            System.assertEquals(srApply.isSuccess, false);
            System.assertEquals(1, srApply.errors.size());
            System.assertEquals(srApply.errors[0].detail, CashDisbursement.CASH_DISBURSEMENT_LEDGER_MISMATCH);
        }
    }

    @IsTest
     static void testApplyCurrencyMismatch() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency() //will throw an exception in case of non-MC org    
                .createCashDisbursementBatches()
                .createCashDisbursements();
            System.runAs(testData.users[1]) {   
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();         
                List<Account_Payable__c> payables = new List<Account_Payable__c>();
                payables.add(
                    new Account_Payable__c(
                        Payee_Reference__c = 'new Payable ledger',
                        Status__c = 'Approved',
                        Payment_Status__c = 'Unpaid',
                        Date__c = testData.acctPeriods[0].Start_Date__c,
                        Due_Date__c = testData.acctPeriods[0].End_Date__c,
                        Vendor__c = testData.accounts[0].Id,
                        Discount_Amount__c = 0,
                        Accounting_Period__c = testData.acctPeriods[0].Id,
                        Ledger__c = testData.ledgers[0].Id                        
                    )
                );
                payables[0].put('CurrencyIsoCode', newCurrency);

                insert payables;

                List<Account_Payable_Line__c> payableLines = new List<Account_Payable_Line__c>();
                payableLines.add(
                    new Account_Payable_Line__c(
                        Account_Payable__c = payables[0].Id,
                        Amount__c = 45,
                        Date__c = testData.acctPeriods[0].Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts[16].Id
                    )
                );

                insert payableLines;

                payables[0].Discount_Amount__c = 20;
                update payables;

                Test.startTest();
                List<CashApplication> cashApplications = new List<CashApplication>();
                
                CashApplication ca = new CashApplication();            
                ca.appliedItemId = payables[0].Id;
                ca.amount = 10;
                ca.accountingPeriodId = testData.acctPeriods[0].Id;                                    
                cashApplications.add(ca);

                ServiceResult srApply = CashDisbursement.apply(testData.cashDisbursements[6].Id, cashApplications);
                System.assertEquals(srApply.isSuccess, false);
                System.assertEquals(1, srApply.errors.size());
                System.assertEquals(srApply.errors[0].detail, CashDisbursement.CASH_DISBURSEMENT_CURRENCY_MISMATCH);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }        
    }


}