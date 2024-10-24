@IsTest
private class FinancialSuiteServiceTest {
    
    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBypassValidationRules() {
        TestDataSuite testData = TestDataSuite.getInstance();

        DMLException dmlEx;
        try {
            testData.settings.Ledger_Limit__c = 10;
            update testData.settings;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        System.assertNotEquals(NULL, dmlEx);

        RestResult result;
        DMLException dmlEx2;
        try {
            testData.settings.Ledger_Limit__c = 10;
            //Avalara Settings enforced to be made via UI only
            //But we will try to do this via Apex service
            testData.settings.Enable_Avalara_Tax_Calculation__c = true;
            //Bypass key set to true will allow us to bypass any trigger level validations
            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
            Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
            result = (RestResult) extension.call('updateAccountingSettings', new Map<String, Object> {
                'authKey' => authKey,
                'data' => testData.settings,
                'bypass' => true
            });
        }
        catch (DMLException ex) {
            dmlEx2 = ex;
        }
        System.assertEquals(NULL, dmlEx2);
        System.assertEquals(true, result.isSuccess);
    }

    @IsTest
    public static void testBypassGLAccountDefaultsValidations() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String key = String.join(new List<String>{
                    'Prepaid_Expense_GL_Account',
                    testData.ledgers[0].Id
            }, ':');
            List<GL_Account_Default__c> glAccountDefaults = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Unique_Key__c =: key
            ];
            GL_Account__c bankGlAccount = GLAccountValidatorTest.createBankGlAccount();
            glAccountDefaults[0].GL_Account__c = bankGlAccount.Id; //WRONG VALUE

            DMLException dmlEx;
            try {
                update glAccountDefaults;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);

            RestResult result;
            DMLException dmlEx2;
            try {
                //Bypass key set to true will allow us to bypass any trigger level validations
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = (RestResult) extension.call('glAccountDefaults', new Map<String, Object> {
                        'authKey' => authKey,
                        'bypass' => true
                });
                update glAccountDefaults;
            }
            catch (DMLException ex) {
                dmlEx2 = ex;
            }
            System.assertEquals(NULL, dmlEx2);
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    public static void testGLAMUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        DMLException dmlEx;
        GL_Account_Mapping__c testGLAM = testData.glams.get(0);
        try {
            testGLAM.Inactive__c = true;
            update testGLAM;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }
        System.assertNotEquals(NULL, dmlEx);
        System.assertEquals(GLAccountMappingActions.GLAM_UPDATE_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));
        RestResult result;
        DMLException dmlEx2;
        try {
            GL_Account_Mapping__c testGLAM2 = testData.glams.get(0);
            testGLAM2.Inactive__c = true;
            //Bypass key set to true will allow us to bypass any trigger level validations
            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
            Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
            result = (RestResult) extension.call('updateGLAM', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => testGLAM2,
                    'bypass' => true});
        }
        catch (DMLException ex) {
            dmlEx2 = ex;
        }
        System.assertEquals(NULL, dmlEx2);
        System.assertEquals(true, result.isSuccess);
    }

    @IsTest
    public static void testQuerySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Set<Id> cdBatchId = new Map<Id, Cash_Disbursement_Batch__c> (testData.cashDisbursementBatch).keySet();

        List<Cash_Disbursement_Batch__c> expectedList = DomainUtils.getCashDisbursementBatchById(cdBatchId, false);
        List<Cash_Disbursement_Batch__c> resultList;
        Exception customEx;
        try {
            Map<String, Object> data = new Map<String, Object> {
                'sobjectType' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c',
                'queryIsAccessible' => false,
                'querySetEnforceFLS' => false,
                'queryFields' => new List<String> {'Id'},
                'queryCondition' => 'Id IN :cdBatchId',
                'subQueryObjName' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r',
                'subQueryIsAccessible' => false,
                'subQuerySetEnforceFLS' => false,
                'subQueryFields' => new List<String> {'Id'},
                'subQueryLimit' => 1
            };
            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

            Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
            resultList = (List<Cash_Disbursement_Batch__c>) Database.query((String) extension.call('query', new Map<String, Object> {
                'authKey' => authKey,
                'data' => data
            }));
        }
        catch (Exception ex) {
            customEx = ex;
        }
        System.assertEquals(NULL, customEx);
        System.assertEquals(expectedList, resultList);
    }

    @IsTest
    public static void testDmlAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        Exception customEx;
        try {
            Map<String, Object> data = new Map<String, Object> {
                'method' => 'deleteCheckCRUDAndFLS',
                'objects' => testData.cashDisbursementBatch
            };
            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

            Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
            extension.call('dmlAction', new Map<String, Object> {
                'authKey' => authKey,
                'data' => data
            });
        }
        catch (Exception ex) {
            customEx = ex;
        }
        List<Cash_Disbursement_Batch__c> resultList = [SELECT Id FROM Cash_Disbursement_Batch__c];
        System.assertEquals(NULL, customEx);
        System.assertEquals(0, resultList.size());
    }

    @IsTest
    public static void testDmlActionWithUnlockedFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[5];
            System.assertEquals(testData.glAccounts[23].Id, testCD.Debit_GL_Account__c);

            //Post CD
            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, cdResults[0].isSuccess);

            Account_Payable__c testAcctPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert testAcctPayable;

            Account_Payable_Line__c testAPLine = new Account_Payable_Line__c(
                Account_Payable__c = testAcctPayable.Id,
                Amount__c = 45,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert testAPLine;

            //Post AP
            AbstractPostHandler apPostHandler = new AccountPayablePostHandler();
            List<PostResult> apResults = apPostHandler.post(new List<Account_Payable__c>{testAcctPayable});
            for (PostResult result : apResults) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementApplyAccountPayable controller = new CashDisbursementApplyAccountPayable(stdController);
            System.assertNotEquals(true, controller.wrappedRecords.isEmpty());
            controller.wrappedRecords[0].apDisbursement.Paid_Amount__c = 10;
            controller.save();
            System.assertEquals(
                1,
                [SELECT count() FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id]
            );
            
            List<AP_Disbursement__c> apdsForCheck =
                [SELECT Id FROM AP_Disbursement__c WHERE Account_Payable__c = :testAcctPayable.Id];

            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE AP_Disbursement__c IN :apdsForCheck]);

            testCD = [SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id];
            testCD.Debit_GL_Account__c = testData.glAccounts[6].Id;
            System.assertEquals(testData.glAccounts[6].Id, testCD.Debit_GL_Account__c);

            Exception customEx;
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'updateProxy',
                    'objects' => new List<Cash_Disbursement__c>{testCD},
                    'unlockedFields' => new Set<SObjectField>{Cash_Disbursement__c.Debit_GL_Account__c}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assertEquals(NULL, customEx);
            testCD = [SELECT Id, Debit_GL_Account__c, Debit_GL_Account__r.Name FROM Cash_Disbursement__c WHERE Id = :testCD.Id];
            System.assertEquals(testData.glAccounts[6].Id, testCD.Debit_GL_Account__c, 'GL Account is ' + testCD.Debit_GL_Account__r.Name);
        }

    }

    @IsTest
    public static void testQueryWithoutCRUDAndFLSSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Set<Id> cdBatchId = new Map<Id, Cash_Disbursement_Batch__c> (testData.cashDisbursementBatch).keySet();

        List<Cash_Disbursement_Batch__c> expectedList = DomainUtils.getCashDisbursementBatchById(cdBatchId, false);
        List<Cash_Disbursement_Batch__c> resultList;
        Exception customEx;
        
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'sobjectType' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c',
                    'queryIsAccessible' => false,
                    'querySetEnforceFLS' => false,
                    'queryFields' => new List<String> {'Id'},
                    'queryCondition' => 'Id IN :cdBatchId',
                    'subQueryObjName' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r',
                    'subQueryIsAccessible' => false,
                    'subQuerySetEnforceFLS' => false,
                    'subQueryFields' => new List<String> {'Id'},
                    'subQueryLimit' => 1
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                resultList = (List<Cash_Disbursement_Batch__c>) Database.query((String) extension.call('query', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                }));
            }
            catch (Exception ex) {
                customEx = ex;
            }
        }
        System.assertEquals(NULL, customEx);
        System.assertEquals(expectedList, resultList);
    }

    @IsTest
    public static void testQueryCRUDException() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Set<Id> cdBatchId = new Map<Id, Cash_Disbursement_Batch__c> (testData.cashDisbursementBatch).keySet();

        List<Cash_Disbursement_Batch__c> expectedList = DomainUtils.getCashDisbursementBatchById(cdBatchId, false);
        List<Cash_Disbursement_Batch__c> resultList;
        User testUser = TestDataSuite.createTestUser();
        testUser.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        update testUser;

        System.runAs(testUser) {
            System.assertEquals(FALSE,Schema.sObjectType.Cash_Disbursement_Batch__c.isAccessible());
            Exception customEx;
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'sobjectType' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c',
                    'queryIsAccessible' => true,
                    'querySetEnforceFLS' => false,
                    'queryFields' => new List<String> {'Id'},
                    'queryCondition' => 'Id IN :cdBatchId',
                    'subQueryObjName' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r',
                    'subQueryIsAccessible' => false,
                    'subQuerySetEnforceFLS' => false,
                    'subQueryFields' => new List<String> {'Id'},
                    'subQueryLimit' => 1
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                resultList = (List<Cash_Disbursement_Batch__c>) Database.query((String) extension.call('query', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                }));
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assert(customEx.getTypeName().contains('CrudException'));
            System.assert(customEx.getMessage().contains('Read'));
            System.assert(customEx.getMessage().contains('Cash Disbursement Batch'));
        }
    }

    @IsTest
    public static void testSubQueryCRUDExceptions() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Set<Id> cdBatchId = new Map<Id, Cash_Disbursement_Batch__c> (testData.cashDisbursementBatch).keySet();

        List<Cash_Disbursement_Batch__c> expectedList = DomainUtils.getCashDisbursementBatchById(cdBatchId, false);
        List<Cash_Disbursement_Batch__c> resultList;
        Exception customEx;

        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'sobjectType' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c',
                    'queryIsAccessible' => false,
                    'querySetEnforceFLS' => false,
                    'queryFields' => new List<String> {'Id'},
                    'queryCondition' => 'Id IN :cdBatchId',
                    'subQueryObjName' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r',
                    'subQueryIsAccessible' => true,
                    'subQuerySetEnforceFLS' => false,
                    'subQueryFields' => new List<String> {'Id'},
                    'subQueryLimit' => 1
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                resultList = (List<Cash_Disbursement_Batch__c>) Database.query((String) extension.call('query', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                }));
            }
            catch (Exception ex) {
                customEx = ex;
            }
        }
        System.assert(customEx.getTypeName().contains('CrudException'));
        System.assert(customEx.getMessage().contains('Read'));
        System.assert(customEx.getMessage().contains('Cash Disbursement'));
    }

    @IsTest
    public static void testQueryFLSException() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Set<Id> cdBatchId = new Map<Id, Cash_Disbursement_Batch__c> (testData.cashDisbursementBatch).keySet();

        List<Cash_Disbursement_Batch__c> expectedList = DomainUtils.getCashDisbursementBatchById(cdBatchId, false);
        List<Cash_Disbursement_Batch__c> resultList;
        User testUser = TestDataSuite.createTestUser();
        testUser.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        update testUser;

        System.runAs(testUser) {
            System.assertEquals(FALSE,Schema.sObjectType.Cash_Disbursement_Batch__c.isAccessible());

            Exception customEx;
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'sobjectType' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c',
                    'queryIsAccessible' => false,
                    'querySetEnforceFLS' => true,
                    'queryFields' => new List<String> {'Id', GlobalVariables.PACKAGE_QUALIFIER + 'Batch_Amount__c'},
                    'queryCondition' => 'Id IN :cdBatchId',
                    'subQueryObjName' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r',
                    'subQueryIsAccessible' => false,
                    'subQuerySetEnforceFLS' => false,
                    'subQueryFields' => new List<String> {'Id'},
                    'subQueryLimit' => 1
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                resultList = (List<Cash_Disbursement_Batch__c>) Database.query((String) extension.call('query', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                }));
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assert(customEx.getTypeName().contains('FlsException'));
            System.assert(customEx.getMessage().contains('Read Access'));
            System.assert(customEx.getMessage().contains('Cash Disbursement Batch'));
            System.assert(customEx.getMessage().contains('Batch Amount'));
        }
    }

    @IsTest
    public static void testSubQueryFLSExceptions() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Set<Id> cdBatchId = new Map<Id, Cash_Disbursement_Batch__c> (testData.cashDisbursementBatch).keySet();

        List<Cash_Disbursement_Batch__c> expectedList = DomainUtils.getCashDisbursementBatchById(cdBatchId, false);
        List<Cash_Disbursement_Batch__c> resultList;
        Exception customEx;

        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'sobjectType' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement_Batch__c',
                    'queryIsAccessible' => false,
                    'querySetEnforceFLS' => false,
                    'queryFields' => new List<String> {'Id'},
                    'queryCondition' => 'Id IN :cdBatchId',
                    'subQueryObjName' => GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursements__r',
                    'subQueryIsAccessible' => false,
                    'subQuerySetEnforceFLS' => true,
                    'subQueryFields' => new List<String> {'Id'},
                    'subQueryLimit' => 1
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                resultList = (List<Cash_Disbursement_Batch__c>) Database.query((String) extension.call('query', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                }));
            }
            catch (Exception ex) {
                customEx = ex;
            }
        }
        System.assert(customEx.getTypeName().contains('FlsException'));
        System.assert(customEx.getMessage().contains('Read Access'));
        System.assert(customEx.getMessage().contains('Cash Disbursement'));
        System.assert(customEx.getMessage().contains('Record ID'));
    }

    @IsTest
    public static void testDMLActionInsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        TestDataSuite.assignAdminPermissionSet(testData.platformTestUser.Id);
        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'insertCheckCRUDAndFLS',
                    'fieldsList' => New List<String> {'Starting_Check_Number__c'},
                    'objects' => New List<Cash_Disbursement_Batch__c> {testBatch}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            List<Cash_Disbursement_Batch__c> resultList = [SELECT Id FROM Cash_Disbursement_Batch__c WHERE Id = :testBatch.Id];
            System.assertEquals(NULL, customEx);
            System.assertEquals(1, resultList.size());
        }
    }

    @IsTest
    public static void testDMLActionProxyInsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'insertProxy',
                    'objects' => New List<Cash_Disbursement_Batch__c> {testBatch}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            List<Cash_Disbursement_Batch__c> resultList = [SELECT Id FROM Cash_Disbursement_Batch__c WHERE Id = :testBatch.Id];
            System.assertEquals(NULL, customEx);
            System.assertEquals(1, resultList.size());
        }
    }

    @IsTest
    public static void testDMLActionInsertCRUDAndFLSException() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'insertCheckCRUDAndFLS',
                    'fieldsList' => New List<String> {'Starting_Check_Number__c'},
                    'objects' => New List<Cash_Disbursement_Batch__c> {testBatch}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assert(customEx.getTypeName().contains('CrudException'));
            System.assert(customEx.getMessage().contains('Create'));
            System.assert(customEx.getMessage().contains('Cash Disbursement Batch'));
        }
    }

    @IsTest
    public static void testDMLActionUpdateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        TestDataSuite.assignAdminPermissionSet(testData.platformTestUser.Id);
        testData.cashDisbursementBatch[0].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'updateCheckCRUDAndFLS',
                    'fieldsList' => New List<String> {'Starting_Check_Number__c'},
                    'objects' => New List<Cash_Disbursement_Batch__c> {testData.cashDisbursementBatch[0]}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            Cash_Disbursement_Batch__c resultCDB = [
                SELECT Id, Starting_Check_Number__c
                FROM Cash_Disbursement_Batch__c
                WHERE Id = :testData.cashDisbursementBatch[0].Id
            ];
            System.assertEquals(NULL, customEx);
            System.assertEquals(10, resultCDB.Starting_Check_Number__c);
        }
    }

    @IsTest
    public static void testDMLActionProxyUpdateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        testData.cashDisbursementBatch[0].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'updateProxy',
                    'objects' => New List<Cash_Disbursement_Batch__c> {testData.cashDisbursementBatch[0]}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            Cash_Disbursement_Batch__c resultCDB = [
                SELECT Id, Starting_Check_Number__c
                FROM Cash_Disbursement_Batch__c
                WHERE Id = :testData.cashDisbursementBatch[0].Id
            ];
            System.assertEquals(NULL, customEx);
            System.assertEquals(10, resultCDB.Starting_Check_Number__c);
        }
    }

    @IsTest
    public static void testDMLActionUpdateCRUDAndFLSException() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        testData.cashDisbursementBatch[0].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'updateCheckCRUDAndFLS',
                    'fieldsList' => New List<String> {'Starting_Check_Number__c'},
                    'objects' => New List<Cash_Disbursement_Batch__c> {testData.cashDisbursementBatch[0]}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }

            System.assert(customEx.getTypeName().contains('CrudException'));
            System.assert(customEx.getMessage().contains('Edit'));
            System.assert(customEx.getMessage().contains('Cash Disbursement Batch'));
        }
    }

    @IsTest
    public static void testDMLActionUpsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        TestDataSuite.assignAdminPermissionSet(testData.platformTestUser.Id);
        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        testBatch.Starting_Check_Number__c = 10;
        testData.cashDisbursementBatch[1].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'upsertCheckCRUDAndFLS',
                    'fieldsList' => New List<String> {'Starting_Check_Number__c'},
                    'objects' => New List<Cash_Disbursement_Batch__c> {testData.cashDisbursementBatch[1], testBatch}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            List<Cash_Disbursement_Batch__c> resultList = [
                SELECT Id, Starting_Check_Number__c
                FROM Cash_Disbursement_Batch__c
                WHERE Id = :testData.cashDisbursementBatch[1].Id OR Id = :testBatch.Id
            ];
            System.assertEquals(NULL, customEx);
            System.assertEquals(2, resultList.size());
            System.assertEquals(10, resultList[0].Starting_Check_Number__c);
            System.assertEquals(10, resultList[1].Starting_Check_Number__c);
        }
    }

    @IsTest
    public static void testDMLActionProxyUpsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        testBatch.Starting_Check_Number__c = 10;
        testData.cashDisbursementBatch[1].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'upsertProxy',
                    'objects' => New List<Cash_Disbursement_Batch__c> {testData.cashDisbursementBatch[1], testBatch}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            List<Cash_Disbursement_Batch__c> resultList = [
                SELECT Id, Starting_Check_Number__c
                FROM Cash_Disbursement_Batch__c
                WHERE Id = :testData.cashDisbursementBatch[1].Id OR Id = :testBatch.Id
            ];
            System.assertEquals(NULL, customEx);
            System.assertEquals(2, resultList.size());
            System.assertEquals(10, resultList[0].Starting_Check_Number__c);
            System.assertEquals(10, resultList[1].Starting_Check_Number__c);
        }
    }

    @IsTest
    public static void testDMLActionUpsertCRUDAndFLSException() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        testData.cashDisbursementBatch[0].Starting_Check_Number__c = 10;
        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        testBatch.Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'upsertCheckCRUDAndFLS',
                    'fieldsList' => New List<String> {'Starting_Check_Number__c'},
                    'objects' => New List<Cash_Disbursement_Batch__c> {testBatch}
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }

            System.assert(customEx.getTypeName().contains('CrudException'));
            System.assert(customEx.getMessage().contains('Create'));
            System.assert(customEx.getMessage().contains('Cash Disbursement Batch'));
        }
    }

    @IsTest
    public static void testDMLActionDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        TestDataSuite.assignAdminPermissionSet(testData.platformTestUser.Id);
        testData.cashDisbursementBatch[0].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'deleteCheckCRUDAndFLS',
                    'objects' => testData.cashDisbursementBatch
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            List<Cash_Disbursement_Batch__c> resultList = [SELECT Id FROM Cash_Disbursement_Batch__c];
            System.assertEquals(NULL, customEx);
            System.assertEquals(0, resultList.size());
        }
    }

    @IsTest
    public static void testDMLActionProxyDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        testBatch.Starting_Check_Number__c = 10;
        testData.cashDisbursementBatch[1].Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'deleteProxy',
                    'objects' => testData.cashDisbursementBatch
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            List<Cash_Disbursement_Batch__c> resultList = [SELECT Id FROM Cash_Disbursement_Batch__c];
            System.assertEquals(NULL, customEx);
            System.assertEquals(0, resultList.size());
        }
    }

    @IsTest
    public static void testDMLActionDeleteCRUDAndFLSException() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        Exception customEx;

        testData.cashDisbursementBatch[0].Starting_Check_Number__c = 10;
        Cash_Disbursement_Batch__c testBatch = testData.cashDisbursementBatch[0].clone();
        testBatch.Starting_Check_Number__c = 10;
        System.runAs(testData.platformTestUser) {
            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'deleteCheckCRUDAndFLS',
                    'objects' => testData.cashDisbursementBatch
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                extension.call('dmlAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }

            System.assert(customEx.getTypeName().contains('CrudException'));
            System.assert(customEx.getMessage().contains('Delete'));
            System.assert(customEx.getMessage().contains('Cash Disbursement Batch'));
        }
    }

    @IsTest
    public static void testCreateBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {

            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            Exception customEx;
            List<RestResult> result;

            try {
                Map<String, Object> data = new Map<String, Object> {
                    'billingModel' => JSON.serialize(model)
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = (List<RestResult>) extension.call('createBilling', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assertEquals(NULL, customEx);

            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Customer__c = :testData.accounts[1].Id];
            List<Billing_Line__c> resLine = [SELECT Id FROM Billing_Line__c WHERE Billing__c = :res[0].Id];
            
            System.assertEquals(true, result[0].isSuccess);
            System.assertEquals(1, res.size());
            System.assertEquals(1, resLine.size());
            System.assertEquals('Approved', res[0].Status__c);
        }
    }

    @IsTest
    public static void testCreateBillingAndPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            BillingCreateService.BillingModel model = TestDataSuite.getBillingModel();
            model.customerId = testData.accounts[1].Id;
            Exception customEx;
            List<RestResult> result;

            try {
                Map<String, Object> data = new Map<String, Object> {
                    'billingModel' => JSON.serialize(model)
                };
                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = (List<RestResult>) extension.call('createBillingAndPost', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assertEquals(NULL, customEx);
            Test.stopTest();

            List<Billing__c> res = [SELECT Id, Status__c FROM Billing__c WHERE Customer__c = :testData.accounts[1].Id];
            List<Billing_Line__c> resLine = [SELECT Id FROM Billing_Line__c WHERE Billing__c = :res[0].Id];

            System.assertEquals(true, result[0].isSuccess);
            System.assertEquals(1, res.size());
            System.assertEquals(1, resLine.size());
            System.assertEquals('Posted', res[0].Status__c);
        }
    }

    @IsTest
    public static void testInventoryCostActionUpsertInventoryCost() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        System.runAs(testData.users[1]) {
            System.assertEquals(0, [SELECT COUNT() FROM Inventory_Cost__c]);

            List<InventoryCostHandler.InventoryMovement> testDataInventoryMovement = new List<InventoryCostHandler.InventoryMovement>();
            InventoryCostHandler.InventoryMovement testInventoryMovementObject = new InventoryCostHandler.InventoryMovement();
            testInventoryMovementObject.productId = testData.products[0].Id;
            testInventoryMovementObject.ledgerId = testData.ledgers[0].Id;
            testInventoryMovementObject.invBalQuantity = 10.0;
            testInventoryMovementObject.invMovQuantity = 20.0;
            testInventoryMovementObject.invMovUnitCost = 30.0;

            testDataInventoryMovement.add(testInventoryMovementObject);

            Exception customEx;
            RestResult result;

            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'upsertInventoryCost',
                    'objects' => JSON.serialize(testDataInventoryMovement)
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result =  (RestResult) extension.call('inventoryCostAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assertEquals(NULL, customEx);
            System.assertEquals(1,[SELECT COUNT() FROM Inventory_Cost__c]);

        }
    }


    @IsTest
    public static void testInventoryCostActionCreateInvCostTransactionsExcludeKitChildProducts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createAccountingVariables()
            .createBillings();

        System.runAs(testData.users[1]) {

            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();

            its.ledgerId = testData.ledgers[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.quantity = 40.0;
            its.unitCost = 100.0;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            its.glVariable1 = testData.accountingVariables1[0].Id;
            itsList.add(its);

            Exception customEx;
            RestResult result;

            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'createInvCostTransactionsExcludeKitChildProducts',
                    'objects' => JSON.serialize(itsList)
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = (RestResult) extension.call('inventoryCostAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }
            System.assertEquals(NULL, customEx);
            System.assertEquals(2, [SELECT COUNT() FROM Transaction__c]);

        }
    }

    @IsTest
    public static void testInventoryCostActionGetProductUnitCost() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();

        InventoryCostActions.isPreventInsertUpdateOverride = true;
        Inventory_Cost__c testInventoryCost = new Inventory_Cost__c();
        testInventoryCost.Ledger__c = testData.ledgers[0].Id;
        testInventoryCost.Product__c = testData.products[0].Id;
        testInventoryCost.Unit_Cost__c = 20;
        insert testInventoryCost;
        InventoryCostActions.isPreventInsertUpdateOverride = false;

        System.runAs(testData.users[1]) {
            Map<Id, Product2> productsByIds = new Map<Id, Product2>(testData.products);
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object> {
                    'method' => 'getProductUnitCost',
                    'objects' => productsByIds.keySet()
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('inventoryCostAction', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => data
                });
            }
            catch (Exception ex) {
                customEx = ex;
            }

            Map<Id, List<InventoryCostHandler.InventoryCost>> resultMap = (Map<Id, List<InventoryCostHandler.InventoryCost>>) JSON.deserialize((String) result, Map<Id, List<InventoryCostHandler.InventoryCost>>.class);

            System.assertEquals(20, resultMap.get(testData.products[0].Id)[0].unitCost);
        }
    }

    @IsTest
    public static void testSetCurrencyConversionRateBySourceDocumentAndLedger() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().createBillings().enableMultiCurrency();

            System.runAs(testData.users[1]) {
              Exception customEx;
                Object result;
                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'setCurrencyConversionRateBySourceDocumentAndLedger',
                        'objects' => testData.billings,
                        'objectsMap' => NULL,
                        'objectDateField' => 'Date__c'
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('multiCurrencyAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);
                System.assertEquals(true, ((RestResult) result).isSuccess);
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testValidateGLAccountLookups() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().createJournalEntries();

            System.runAs(testData.users[1]) {
              Exception customEx;
                Object result;
                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'validateGLAccountLookups',
                        'objects' => testData.journalEntryLines,
                        'objectsMap' => NULL
                        
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('glAccountValidator', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);                
                
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testIsMultiCurrencyEnabled() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {

                Exception customEx;
                Object result;

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'isMultiCurrencyEnabled'
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('multiCurrencyAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);
                System.assertEquals(true, ((Boolean) result));
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testGetCorporateCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                Exception customEx;
                Object result;

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'getCorporateCurrency'
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('multiCurrencyAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }
                System.assertEquals(MultiCurrencyHandler.CORPORATE_CURRENCY, result);
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testValidateCurrencyConversionRate() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().createBillings().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                Exception customEx;
                Object result;

                testData.billings[0].Currency_Conversion_Rate__c = NULL;

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'validateCurrencyConversionRate',
                        'objects' => testData.billings
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('multiCurrencyAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }
                System.assertEquals(NULL, customEx);
                System.assertEquals(true, ((RestResult) result).isSuccess);

            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testSetISOCodeFromParent() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().createBillings().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                Exception customEx;
                Object result;

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'setISOCodeFromParent',
                        'objects' => testData.billingLines
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('multiCurrencyAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);
                System.assertEquals(true, ((RestResult) result).isSuccess);

            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testRevertCurrencyIsoCodeIfNull() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().createBillings().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                Exception customEx;
                Object result;

                Map<Id,SObject> oldRecordsMap = new Map<Id,SObject>(testData.billings);
                List<SObject> newRecords = new List<SObject>((SObject[])testData.billings);

                for (SObject obj : newRecords) {
                    obj.put('CurrencyIsoCode', NULL);
                }

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'revertCurrencyIsoCodeIfNull',
                        'oldRecordsMap' => oldRecordsMap,
                        'newRecords' => newRecords
                    };

                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('multiCurrencyAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);
                System.assertEquals(true, ((RestResult) result).isSuccess);

            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testGetAccountingSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getAccountingSettings'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('accountingSettingHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(AccountingSettingsHandler.getAccountingSettings(), (Accounting_Settings__c) result);

        }
    }

    @IsTest
    public static void testGLAccountDefaultsByLedgerId() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                        'method' => 'glAccountDefaultsByLedgerId',
                        'ledgerIds' => new Set<Id>{ testData.ledgers[0].Id }
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('glAccountDefaultsAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assert(((Map<Id, Map<String, AcctSeed__GL_Account_Default__c>>) result).get(testData.ledgers[0].Id) != null);

        }
    }

    @IsTest
    public static void testIsAutoPostAmortizationEntriesEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                        'method' => 'isAutoPostAmortizationEntriesEnabled'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('accountingSettingHandlerAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(true, AccountingSettingsHandler.getAccountingSettings().Auto_Post_Amortization_Entries__c);

        }
    }

    @IsTest
    public static void testIsERPEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'isERPEnabled'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('accountingSettingHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(true, (Boolean) result);

        }
    }

    @IsTest
    public static void testIsWOEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'isWOEnabled'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('accountingSettingHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            Boolean woResult = Schema.getGlobalDescribe().get('WorkOrder') != NULL;
            System.assertEquals(NULL, customEx);
            System.assertEquals(woResult, (Boolean) result);

        }
    }

    @IsTest
    public static void testIsInventoryValuationStandardCost() {
        TestDataSuite testData = TestDataSuite.getInstance().setInventoryValuationStandardCost();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'isInventoryValuationStandardCost'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('accountingSettingHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(true, (Boolean) result);

        }
    }

    @IsTest
    public static void testIsInventoryValuationAverageCost() {
        TestDataSuite testData = TestDataSuite.getInstance().setInventoryValuationAverageCost();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'isInventoryValuationAverageCost'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('accountingSettingHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(true, (Boolean) result);

        }
    }

    @IsTest
    public static void testGetAllLedgersMap() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getAllLedgersMap',
                    'sharingContext' => false
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap(), (Map<Id, Ledger__c>) result);

        }
    }

    @IsTest
    public static void testGetTransactionalLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getTransactionalLedgers',
                    'sharingContext' => false
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers(), (List<Ledger__c>) result);

        }
    }

    @IsTest
    public static void testGetBudgetLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getBudgetLedgers',
                    'sharingContext' => false
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(LedgerHandler.getInstanceWithoutSharing().getBudgetLedgers(), (List<Ledger__c>) result);

        }
    }

    @IsTest
    public static void testGetLedgerById() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getLedgerById',
                    'ledgerIds' => new Set<Id> {testData.ledgers[0].Id},
                    'sharingContext' => false
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(LedgerHandler.getInstanceWithoutSharing().getLedgerById(new Set<Id> {testData.ledgers[0].Id}), (List<Ledger__c>) result);

        }
    }

    @IsTest
    public static void testGetTransactionalLedgerSelectOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getTransactionalLedgerSelectOptions',
                    'includeNone' => false,
                    'sharingContext' => false
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgerSelectOptions(false), (List<SelectOption>) result);

        }
    }

    @IsTest
    public static void testGetBudgetLedgerSelectOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'getBudgetLedgerSelectOptions',
                    'sharingContext' => false
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(LedgerHandler.getInstanceWithoutSharing().getBudgetLedgerSelectOptions(), (List<SelectOption>) result);

        }
    }

    @IsTest
    public static void testGetLedgerCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                Exception customEx;
                Object result;

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'getLedgerCurrency',
                        'ledgerId' => testData.ledgers[0].Id
                    };
                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('ledgerHandlerAction', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);
                System.assertEquals(LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id), (String) result);

            }
        } catch (Exception ex) {

        }
    }

    @IsTest
    private static void validateAvaVATLedgerSettings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true)
            .setAvaVATReportingEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.validateAvaVATLedgerSettings(testData.ledgers);
            Test.stopTest();
        }

        System.assertEquals(1, AvaVATServiceMock.timesCalled('validateAvaVATLedgerSettings'));
    }

    @IsTest
    private static void validateVATCountryReportable() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true)
            .setAvaVATReportingEnabled();

        //List<Billing_Line__c> invLines = new List<Billing_Line__c>(testData.billingLines;

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.validateVATCountryReportable(testData.billingLines);
            Test.stopTest();
        }

        System.assertEquals(1, AvaVATServiceMock.timesCalled('validateVATCountryReportable'));
    }

    @IsTest
    private static void testSubmitPostBillingsToAvaVAT() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true)
            .setAvaVATReportingEnabled();

        List<Id> submissions = new List<Id>{testData.billings[0].Id, testData.billings[1].Id};

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.submitBillingsToAvaVAT(submissions, PostResultDispatcher.ExecutionContext.POST);
            Test.stopTest();
        }

        System.assertEquals(1, AvaVATServiceMock.timesCalled('submitBillingsToAvaVAT'));
    }

    @IsTest
    private static void testSubmitUnpostBillingsToAvaVAT() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setAvaVATReportingEnabled();

        List<Id> submissions = new List<Id>{testData.billings[0].Id, testData.billings[1].Id};

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.submitBillingsToAvaVAT(submissions, PostResultDispatcher.ExecutionContext.UNPOST);
            Test.stopTest();
        }

        System.assertEquals(1, AvaVATServiceMock.timesCalled('submitBillingsToAvaVAT'));
    }

    @IsTest
    private static void testSubmitPostPayablesToAvaVAT() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .setAvaVATReportingEnabled();

        List<Id> submissions = new List<Id>{testData.payables[0].Id, testData.payables[1].Id};

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.submitPayablesToAvaVAT(submissions, PostResultDispatcher.ExecutionContext.POST);
            Test.stopTest();
        }

        System.assertEquals(1, AvaVATServiceMock.timesCalled('submitPayablesToAvaVAT'));
    }

    @IsTest
    private static void testSubmitUnpostPayablesToAvaVAT() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .setAvaVATReportingEnabled();

        List<Id> submissions = new List<Id>{testData.payables[0].Id, testData.payables[1].Id};

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.submitPayablesToAvaVAT(submissions, PostResultDispatcher.ExecutionContext.UNPOST);
            Test.stopTest();
        }

        System.assertEquals(1, AvaVATServiceMock.timesCalled('submitPayablesToAvaVAT'));
    }

    @IsTest
    private static void testTestServiceEnableAvalaraVATReporting() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'enableAvalaraVATReporting'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('testDataSuiteAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(true, AccountingSettingsHandler.isAvaVATReportingEnabled());
        }
    }

    @IsTest
    private static void testTestServiceIsAvalaraVATReportingEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Exception customEx;
            Object result;

            try {
                Map<String, Object> data = new Map<String, Object>{
                    'method' => 'isAvalaraVATReportingEnabled'
                };

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = extension.call('testDataSuiteAction', new Map<String, Object>{
                    'authKey' => authKey,
                    'data' => data
                });
            } catch (Exception ex) {
                customEx = ex;
            }

            System.assertEquals(NULL, customEx);
            System.assertEquals(false, (Boolean) result);
        }
    }

    @IsTest
    private static void testSubmitBillingsToAvaVATDoesNothingWhenAvaVATDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        List<Id> submissions = new List<Id>{testData.billings[0].Id, testData.billings[1].Id};

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.submitBillingsToAvaVAT(submissions, PostResultDispatcher.ExecutionContext.POST);
            Test.stopTest();
        }

        System.assertEquals(0, AvaVATServiceMock.timesCalled('submitBillingsToAvaVAT'));
    }

    @IsTest
    private static void testSubmitPayablesToAvaVATDoesNothingWhenAvaVATDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        List<Id> submissions = new List<Id>{testData.payables[0].Id, testData.payables[1].Id};

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialSuiteService.AVAVAT_SERVICE_CLASS = 'AvaVATServiceMock';
            FinancialSuiteService.submitPayablesToAvaVAT(submissions, PostResultDispatcher.ExecutionContext.POST);
            Test.stopTest();
        }

        System.assertEquals(0, AvaVATServiceMock.timesCalled('submitPayablesToAvaVAT'));
    }

    @IsTest
    private static void testMultiCurrencyActionSetCurrencyIsoCodeToUserCurrency_MC() {
        TestDataSuite testData = TestDataSuite.getInstance();
        try {
            testData.enableMultiCurrency(); //will throw an exception in case of non-MC org
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
            return;
        }
        testData.createBillings();

        Billing__c obj = testData.billings[0].clone(false,true);
        obj.put('CurrencyIsoCode', NULL);
        List<SObject> objs = new List<Billing__c> { obj };
        String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
        Map<String,Object> args = new Map<String,Object> {
            'authKey' => authKey,
            'data' => new Map<String,Object> {
                'method' => 'setCurrencyIsoCodeToUserCurrency',
                'objects' => objs
            }
        };

        System.runAs(testData.users[1]) {
            Callable svc = new FinancialSuiteService();
            svc.call('multiCurrencyAction', args);
            System.assertEquals(UserInfo.getDefaultCurrency(), obj.get('CurrencyIsoCode'));
        }
    }

    @IsTest
    private static void testAutomatedJobResultsHandlerAction() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Object result;
            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
            Map<String,Object> args = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'setJobType',
                    'jobName' => 'Recurring Billing Job'
                }
            };
            Callable svc = new FinancialSuiteService();
            svc.call('automatedJobResultsHandler', args);

            Map<String,Object> args1 = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'addProcessed',
                    'count' => 10
                }
            };
            Callable svc1 = new FinancialSuiteService();
            svc1.call('automatedJobResultsHandler', args1);

            Map<String,Object> args2 = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'addSucceeded',
                    'count' => 8
                }
            };
            Callable svc2 = new FinancialSuiteService();
            svc2.call('automatedJobResultsHandler', args2);

            Map<String,Object> args3 = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'addFailed',
                    'count' => 2
                }
            };
            Callable svc3 = new FinancialSuiteService();
            svc3.call('automatedJobResultsHandler', args3);

            Map<String,Object> args4 = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'getReportLink',
                    'jobName' => 'test report job'
                }
            };
            Callable svc4 = new FinancialSuiteService();
            result = svc4.call('automatedJobResultsHandler', args4);

            Map<String,Object> args5 = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'setError',
                    'errorValue' => (String) result
                }
            };
            Callable svc5 = new FinancialSuiteService();
            svc5.call('automatedJobResultsHandler', args5);

            Map<String,Object> args6 = new Map<String,Object> {
                'authKey' => authKey,
                'data' => new Map<String,Object> {
                    'method' => 'saveAutomatedJobResults'
                }
            };
            Callable svc6 = new FinancialSuiteService();
            svc6.call('automatedJobResultsHandler', args6);

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c, Notes__c FROM Automated_Job_Results__c];
            String testLink = URL.getOrgDomainUrl().toExternalForm() + '/00000000000xxxxAAA';

            System.assertEquals('Recurring Billing', ajr.Schedule_Job_Type__c);
            System.assertEquals(10, ajr.Processed__c);
            System.assertEquals(8, ajr.Succeeded__c);
            System.assertEquals(2, ajr.Failed__c);
            System.assertEquals(testLink, ajr.Notes__c);
        }
    }

    @IsTest
    public static void testformatFileName() {
 
           TestDataSuite testData = TestDataSuite.getInstance();
            System.runAs(testData.users[1]) {
                Exception customEx;
                Object result;

                String customerName = 'Test Customer Name';
                String typePrefix = '_TypePrefix_';
                String recordName = 'Test Record Name';

                try {
                    Map<String, Object> data = new Map<String, Object>{
                        'method' => 'formatFileName',
                        'customerName' => customerName,
                        'typePrefix' => typePrefix,
                        'recordName' => recordName
                    };
                    String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));

                    Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                    result = extension.call('statementManager', new Map<String, Object>{
                        'authKey' => authKey,
                        'data' => data
                    });
                } catch (Exception ex) {
                    customEx = ex;
                }

                System.assertEquals(NULL, customEx);
                //assert the strings match
                System.assertEquals(AbstractStatementManager.formatFileName(customerName,typePrefix,recordName ), (String) result);
                //assert the result matches the defined format
                System.assertEquals(customerName + typePrefix + recordName + AbstractStatementManager.getLocaleDateTimeFormatted() + AbstractStatementManager.PDF_EXTENSION, (String) result);

            }

    }

    @IsTest
    public static void testQueryFormationAndSorting() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            
            Account_Payable__c accountPayable = [
                SELECT Id, Vendor__c
                FROM Account_Payable__c
                WHERE Payee_Reference__c = '234534563453453453454353453453453453trewtre'
            ][0];

            accountPayable.Vendor__c = testData.accounts[1].Id;
            update accountPayable;

            String packageQualifier = GlobalVariables.PACKAGE_QUALIFIER;

            String sObjectType = 'Account_Payable__c';
            Boolean queryIsAccessible = true;
                Boolean querySetEnforceFLS = true;
            List<String> queryFields = new List<String>{'Id', 'Name', 'Vendor__c', 'Vendor__r.Name'};
            List<String> queryOrdering = new List<String>{'Account_Payable__c', 'Vendor__r.Name'};

            Map<String, Object> data = new Map<String, Object> {
                'sobjectType' => sObjectType,
                'queryIsAccessible' => queryIsAccessible,
                'querySetEnforceFLS' => querySetEnforceFLS,
                'queryFields' => queryFields,
                'queryCondition' => (packageQualifier + 'Vendor__c != null'),
                'queryOrdering' => queryOrdering,
                'queryLimit' => null
            };

            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
            Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
            Object result = extension.call('query', new Map<String, Object>{'authKey' => authKey, 'data' => data});

            Assert.isTrue(result.toString().containsIgnoreCase('SELECT'));
            Assert.isTrue(result.toString().containsIgnoreCase('Id'));
            Assert.isTrue(result.toString().containsIgnoreCase('Name'));
            Assert.isTrue(result.toString().containsIgnoreCase(packageQualifier + 'Vendor__c'));
            Assert.isTrue(result.toString().containsIgnoreCase(packageQualifier + 'Vendor__r.Name'));
            Assert.isTrue(result.toString().containsIgnoreCase('FROM'));
            Assert.isTrue(result.toString().containsIgnoreCase('WHERE'));
            Assert.isTrue(result.toString().containsIgnoreCase('ORDER BY'));

            List<Account_Payable__c> accountPayableList = (List<Account_Payable__c>) Database.query((String) result);
            Test.stopTest();
            Assert.areEqual(5, accountPayableList.size());
            Assert.areEqual('Acme Account', accountPayableList[0].Vendor__r.Name);
        }
    }
}